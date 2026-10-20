#!/usr/bin/env bash
#
# Temporary Entra bootstrap + Identity SSO deployment.
#
# Runs the product's published two-step deployment for Identity — SSO
# (identity-sso 5.0.0) and, before that, provisions the SSO target Entra app
# registration with the existing provisioning app (ENTRA_APP_ID).
#
# Nothing here is permanent: it is removed once the bootstrap is verified (see
# docs/pdac/handoff.md, docs/pdac/lessons-learned.md). The permanent,
# declarative workflow (.github/workflows/varde-flyt-deploy.yml) deploys the
# committed manifest on every push and never touches Entra.
#
# Required environment (from the GitHub Actions repo variables / secrets):
#   VFAC_ENDPOINT, VFAC_CREDENTIAL_ID, VFAC_CREDENTIAL_SECRET, VFAC_PROJECT_ID
#   ENTRA_TENANT_ID, ENTRA_APP_ID, ENTRA_APP_SECRET   (provisioning app)
#   INITIAL_EMAIL_ADDRESS                             (first administrator)
#   INITIAL_EMAIL_SECRET                              (their one-time password)
# Optional:
#   MODE=bootstrap|recover|rotate   (default: bootstrap)
#   TARGET_APP_NAME                 (default: box-shared-sso-prod)
#
set -euo pipefail

RESOURCE_KEY="box-shared-sso-prod"
MODE="${MODE:-bootstrap}"
TARGET_APP_NAME="${TARGET_APP_NAME:-box-shared-sso-prod}"
GRAPH="https://graph.microsoft.com/v1.0"
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"
MANIFEST_TEMPLATE="resources/identity-sso.yaml"
GRAPH_TOKEN=""

for v in VFAC_ENDPOINT VFAC_CREDENTIAL_ID VFAC_CREDENTIAL_SECRET VFAC_PROJECT_ID \
         ENTRA_TENANT_ID ENTRA_APP_ID ENTRA_APP_SECRET \
         INITIAL_EMAIL_ADDRESS INITIAL_EMAIL_SECRET; do
  if [ -z "${!v:-}" ]; then echo "ERROR: required environment variable ${v} is not set" >&2; exit 1; fi
done

fail() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "::notice::$*"; }
mask() { echo "::add-mask::$1"; }

# --- vfac ---------------------------------------------------------------

vfac_login() {
  vfac doctor
  vfac context set --project "$VFAC_PROJECT_ID"
}

# Render the committed template, optionally dropping the `entra:` group.
render_manifest() { # $1=outfile $2=with_entra(true|false)
  local out="$1" with="$2"
  python3 - "$MANIFEST_TEMPLATE" "$out" "$with" <<'PY'
import os, sys
tpl, out, with_entra = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
lines = open(tpl, encoding="utf-8").read().splitlines(keepends=True)
docs, skip = [], False
for ln in lines:
    if "# vfac-bootstrap:entra:begin" in ln: skip = True; continue
    if "# vfac-bootstrap:entra:end" in ln: skip = False; continue
    if skip and not with_entra: continue
    docs.append(ln)
text = "".join(docs)
for key in ("ADMIN_EMAIL", "ENTRA_TENANT_ID", "ENTRA_CLIENT_ID"):
    text = text.replace("${%s}" % key, os.environ.get(key, ""))
open(out, "w", encoding="utf-8").write(text)
PY
}

plan_json() { local f="$1"; shift; vfac plan -f "$f" "$@" --output json; }
apply_wait() { local f="$1"; shift; vfac apply -f "$f" "$@" --wait --output json; }

require_action() { # $1=plan json
  local action; action=$(jq -r '.action // empty' <<<"$1")
  case "$action" in
    CREATE|UPDATE|NO_CHANGE|ADOPT) echo "$action" ;;
    GONE|UPGRADE_REQUIRED|RECREATE_REQUIRED) fail "plan is terminal (${action}); not applying" ;;
    "") fail "plan returned no action" ;;
    *) fail "unexpected plan action '${action}'; refusing to apply" ;;
  esac
}

find_instance_id() {
  vfac get product-instances --output json \
    | jq -r --arg k "$RESOURCE_KEY" '
        (.productInstances // [])[]
        | select((.metadata.key // .key // .name) == $k)
        | (.productInstanceId // .id // .resourceId) ' 2>/dev/null | head -1
}

get_output() {
  vfac get product-instance "$INSTANCE_ID" --output json \
    | jq -r --arg k "$1" '(.resource.outputs // .outputs // {})[$k] // empty'
}

get_condition() {
  vfac get product-instance "$INSTANCE_ID" --output json \
    | jq -r --arg k "$1" '(.resource.conditions // [])[] | select(.key==$k) | "\(.state)/\(.freshness)"' 2>/dev/null | head -1
}

# --- Microsoft Graph ----------------------------------------------------

graph_token() {
  local resp; resp=$(curl -sS -X POST "https://login.microsoftonline.com/${ENTRA_TENANT_ID}/oauth2/v2.0/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=${ENTRA_APP_ID}" \
    --data-urlencode "client_secret=${ENTRA_APP_SECRET}" \
    --data-urlencode "scope=https://graph.microsoft.com/.default" \
    --data-urlencode "grant_type=client_credentials")
  if [ "$(jq -r 'has("error")' <<<"$resp" 2>/dev/null)" = "true" ]; then
    fail "Graph token request failed: $(jq -r '.error' <<<"$resp") — $(jq -r '.error_description // ""' <<<"$resp" | head -1)"
  fi
  jq -r '.access_token // empty' <<<"$resp"
}

# GET with query args; fails loudly on a Graph error.
gget() { # $1=path, rest: --data-urlencode pairs
  local p="$1"; shift
  local r; r=$(curl -sS -G -H "Authorization: Bearer ${GRAPH_TOKEN}" -H 'Accept: application/json' "$@" "${GRAPH}${p}")
  if [ "$(jq -r 'has("error")' <<<"$r" 2>/dev/null)" = "true" ]; then
    fail "Graph GET ${p} failed: $(jq -r '.error.code' <<<"$r") — $(jq -r '.error.message' <<<"$r" | head -1)"
  fi
  printf '%s' "$r"
}

# POST/PATCH/DELETE; fails loudly unless the caller explicitly allows the error.
gwrite() { # $1=method $2=path $3=body
  local m="$1" p="$2" b="$3"
  local r; r=$(curl -sS -X "$m" -H "Authorization: Bearer ${GRAPH_TOKEN}" -H 'Content-Type: application/json' -d "$b" "${GRAPH}${p}")
  if [ "$(jq -r 'has("error")' <<<"$r" 2>/dev/null)" = "true" ]; then
    fail "Graph ${m} ${p} failed: $(jq -r '.error.code' <<<"$r") — $(jq -r '.error.message' <<<"$r" | head -1)"
  fi
  printf '%s' "$r"
}

graph_role_id()  { jq -r --arg v "$1" '.value[]|select(.value==$v)|.id' <<<"$ROLES_JSON"  | head -1; }
graph_scope_id() { jq -r --arg v "$1" '.value[]|select(.value==$v)|.id' <<<"$SCOPES_JSON" | head -1; }

# --- 1. vfac sign-in ----------------------------------------------------

vfac_login
note "vfac signed in as: $(vfac whoami 2>/dev/null | head -1)"

# --- 2. Graph preflight -------------------------------------------------

GRAPH_TOKEN="$(graph_token)"
[ -n "$GRAPH_TOKEN" ] || fail "Microsoft Graph token is empty"
mask "$GRAPH_TOKEN"

GRAPH_SP_ID=$(jq -r '.value[0].id // empty' <<<"$(gget "/servicePrincipals" \
  --data-urlencode "\$filter=appId eq '${GRAPH_APP_ID}'" --data-urlencode "\$select=id")")
[ -n "$GRAPH_SP_ID" ] || fail "Microsoft Graph service principal not found in this tenant"
ROLES_JSON=$(gget "/servicePrincipals/${GRAPH_SP_ID}/appRoles")
SCOPES_JSON=$(gget "/servicePrincipals/${GRAPH_SP_ID}/oauth2PermissionScopes")

PROV_SP_ID=$(jq -r '.value[0].id // empty' <<<"$(gget "/servicePrincipals" \
  --data-urlencode "\$filter=appId eq '${ENTRA_APP_ID}'" --data-urlencode "\$select=id")")
[ -n "$PROV_SP_ID" ] || fail "provisioning app has no service principal in this tenant"
PROV_ROLES=$(jq -r '.value[].appRoleId' <<<"$(gget "/servicePrincipals/${PROV_SP_ID}/appRoleAssignments" --data-urlencode "\$select=appRoleId")")

missing=()
for perm in Application.ReadWrite.All AppRoleAssignment.ReadWrite.All DelegatedPermissionGrant.ReadWrite.All Application.Read.All; do
  id=$(graph_role_id "$perm")
  [ -n "$id" ] || fail "Graph application permission '${perm}' not found on the Microsoft Graph service principal"
  grep -qx "$id" <<<"$PROV_ROLES" || missing+=("$perm")
done
[ ${#missing[@]} -eq 0 ] || fail "provisioning app lacks consented Microsoft Graph application permissions: ${missing[*]}"
note "Graph preflight OK: provisioning app holds the required application permissions"

# --- 3. Find or create the SSO target app -------------------------------

APPS=$(gget "/applications" --data-urlencode "\$filter=displayName eq '${TARGET_APP_NAME}'" --data-urlencode "\$select=id,appId,displayName")
COUNT=$(jq -r '.value|length' <<<"$APPS")
[ "$COUNT" -le 1 ] || fail "multiple_app_registrations: ${COUNT} app registrations named '${TARGET_APP_NAME}'"

if [ "$COUNT" -eq 1 ]; then
  TARGET_OBJECT_ID=$(jq -r '.value[0].id' <<<"$APPS")
  TARGET_CLIENT_ID=$(jq -r '.value[0].appId' <<<"$APPS")
  APP_CREATED=false
  note "target app '${TARGET_APP_NAME}' already exists; reusing it"
else
  CREATED=$(gwrite POST "/applications" "$(jq -nc --arg n "$TARGET_APP_NAME" '{displayName:$n,signInAudience:"AzureADMyOrg"}')")
  TARGET_OBJECT_ID=$(jq -r '.id' <<<"$CREATED")
  TARGET_CLIENT_ID=$(jq -r '.appId' <<<"$CREATED")
  APP_CREATED=true
  note "created target app '${TARGET_APP_NAME}'"
fi
[ -n "$TARGET_OBJECT_ID" ] && [ "$TARGET_OBJECT_ID" != "null" ] || fail "could not obtain the target application object id"

TARGET_SP_ID=$(jq -r '.value[0].id // empty' <<<"$(gget "/servicePrincipals" \
  --data-urlencode "\$filter=appId eq '${TARGET_CLIENT_ID}'" --data-urlencode "\$select=id")")
if [ -z "$TARGET_SP_ID" ]; then
  SP=$(gwrite POST "/servicePrincipals" "$(jq -nc --arg a "$TARGET_CLIENT_ID" '{appId:$a}')")
  TARGET_SP_ID=$(jq -r '.id' <<<"$SP")
fi
[ -n "$TARGET_SP_ID" ] || fail "could not obtain the target service principal"

# --- 4. Existing Identity resource? ------------------------------------

INSTANCE_ID="$(find_instance_id || true)"
EXISTING=false
[ -n "$INSTANCE_ID" ] && EXISTING=true

configured() { [ "$(get_condition directoryAccess)" = "READY/FRESH" ]; }

MINT=true
if [ "$MODE" != "rotate" ] && [ "$EXISTING" = true ] && configured; then MINT=false; fi

if [ "$EXISTING" = true ] && [ "$MODE" = "bootstrap" ] && configured; then
  note "Identity '${RESOURCE_KEY}' is already configured (directory access READY/FRESH) — nothing to bootstrap"
  {
    echo "## Identity SSO bootstrap — ${RESOURCE_KEY}"
    echo
    echo "| field | value |"
    echo "| --- | --- |"
    echo "| result | already bootstrapped (no change) |"
    echo "| resource id | \`${INSTANCE_ID}\` |"
    echo "| target app client id | \`${TARGET_CLIENT_ID}\` |"
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

# --- 5. Mint the target client secret (memory only) --------------------

export __SSO_CLIENT_SECRET=""
if [ "$MINT" = true ]; then
  END=$(date -u -d '+180 days' +%Y-%m-%dT%H:%M:%SZ)
  PW=$(gwrite POST "/applications/${TARGET_OBJECT_ID}/addPassword" \
        "$(jq -nc --arg d "$END" '{passwordCredential:{displayName:"vfac-bootstrap-180d",endDateTime:$d}}')")
  __SSO_CLIENT_SECRET=$(jq -r '.secretText // empty' <<<"$PW")
  [ -n "$__SSO_CLIENT_SECRET" ] || fail "Graph did not return a client secret"
  mask "$__SSO_CLIENT_SECRET"
  note "minted a 180-day client secret on '${TARGET_APP_NAME}'"
else
  note "reusing the stored client secret (no rotation)"
fi

# --- 6. Identity step 1 — bootstrap (no /entra) ------------------------

if [ "$EXISTING" = false ]; then
  export ADMIN_EMAIL="$INITIAL_EMAIL_ADDRESS"
  render_manifest /tmp/bootstrap.yaml false
  vfac validate -f /tmp/bootstrap.yaml
  PLAN1=$(plan_json /tmp/bootstrap.yaml --secret /administrator/oneTimePassword=env:INITIAL_EMAIL_SECRET)
  note "step 1 plan action: $(require_action "$PLAN1")"
  APPLY1=$(apply_wait /tmp/bootstrap.yaml --secret /administrator/oneTimePassword=env:INITIAL_EMAIL_SECRET)
  INSTANCE_ID=$(jq -r '.resourceId // .productInstanceId // empty' <<<"$APPLY1" 2>/dev/null || true)
  [ -n "$INSTANCE_ID" ] || INSTANCE_ID="$(find_instance_id || true)"
  [ -n "$INSTANCE_ID" ] || fail "step 1 apply did not yield a resource id"
  note "Identity resource created: ${INSTANCE_ID}"
else
  note "Identity resource '${RESOURCE_KEY}' already exists (${INSTANCE_ID}); skipping the bootstrap apply"
fi

# --- 7. Read the published entraRedirectUri output ---------------------

REDIRECT_URI=$(get_output entraRedirectUri)
[ -n "$REDIRECT_URI" ] || fail "resource output 'entraRedirectUri' is not published yet"
note "entraRedirectUri: ${REDIRECT_URI}"

# --- 8. Configure the target app ---------------------------------------

USER_READ=$(graph_role_id "User.Read.All")
GROUP_MEMBER=$(graph_role_id "GroupMember.Read.All")
[ -n "$USER_READ" ] && [ -n "$GROUP_MEMBER" ] || fail "could not resolve User.Read.All / GroupMember.Read.All app role ids"

ACCESS=$(jq -nc \
  --arg ur "$USER_READ" --arg gm "$GROUP_MEMBER" \
  --arg openid "$(graph_scope_id openid)" --arg profile "$(graph_scope_id profile)" --arg email "$(graph_scope_id email)" '
  [{id:$ur,type:"Role"},{id:$gm,type:"Role"}]
  + ([{v:$openid},{v:$profile},{v:$email}] | map(select(.v != "") | {id:.v,type:"Scope"}))')

PATCH_BODY=$(jq -nc \
  --arg uri "$REDIRECT_URI" --arg graph "$GRAPH_APP_ID" --argjson access "$ACCESS" \
  '{web:{redirectUris:[$uri]}, requiredResourceAccess:[{resourceAppId:$graph, resourceAccess:$access}]}')
gwrite PATCH "/applications/${TARGET_OBJECT_ID}" "$PATCH_BODY" >/dev/null

gwrite PATCH "/servicePrincipals/${TARGET_SP_ID}" '{"appRoleAssignmentRequired":false}' >/dev/null

for rid in "$USER_READ" "$GROUP_MEMBER"; do
  RESP=$(curl -sS -X POST -H "Authorization: Bearer ${GRAPH_TOKEN}" -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg p "$TARGET_SP_ID" --arg r "$GRAPH_SP_ID" --arg a "$rid" '{principalId:$p,resourceId:$r,appRoleId:$a}')" \
    "${GRAPH}/servicePrincipals/${TARGET_SP_ID}/appRoleAssignments")
  if [ "$(jq -r 'has("error")' <<<"$RESP")" = "true" ] && \
     ! jq -e '(.error.code == "Request_BadRequest") and (.error.message|test("already";"i"))' >/dev/null <<<"$RESP"; then
    fail "Graph consent app role ${rid} failed: $(jq -r '.error.code' <<<"$RESP") — $(jq -r '.error.message' <<<"$RESP" | head -1)"
  fi
done

SCOPE_STR="openid profile email"
EXISTING_GRANT=$(jq -r '.value[0].id // empty' <<<"$(gget "/oauth2PermissionGrants" \
  --data-urlencode "\$filter=clientId eq '${TARGET_SP_ID}' and resourceId eq '${GRAPH_SP_ID}'" --data-urlencode "\$select=id")")
if [ -n "$EXISTING_GRANT" ]; then
  gwrite PATCH "/oauth2PermissionGrants/${EXISTING_GRANT}" "$(jq -nc --arg s "$SCOPE_STR" '{scope:$s}')" >/dev/null
else
  gwrite POST "/oauth2PermissionGrants" "$(jq -nc --arg c "$TARGET_SP_ID" --arg r "$GRAPH_SP_ID" --arg s "$SCOPE_STR" '{clientId:$c,consentType:"AllPrincipals",resourceId:$r,scope:$s}')" >/dev/null
fi
note "target app configured: redirect URI, Graph permissions and consent"

# --- 9. Identity step 2 — Entra integration ----------------------------

export ADMIN_EMAIL="$INITIAL_EMAIL_ADDRESS"
export ENTRA_CLIENT_ID="$TARGET_CLIENT_ID"
render_manifest /tmp/entra.yaml true
vfac validate -f /tmp/entra.yaml

SECRET_ARGS=()
if [ -n "$__SSO_CLIENT_SECRET" ]; then
  SECRET_ARGS=(--secret /entra/clientSecret=env:__SSO_CLIENT_SECRET)
fi

PLAN2=$(plan_json /tmp/entra.yaml "${SECRET_ARGS[@]}")
note "step 2 plan action: $(require_action "$PLAN2"); secretsToWrite: $(jq -c '.secretsToWrite // []' <<<"$PLAN2")"
APPLY2=$(apply_wait /tmp/entra.yaml "${SECRET_ARGS[@]}")
INSTANCE_ID=$(jq -r '.resourceId // .productInstanceId // empty' <<<"$APPLY2" 2>/dev/null || true)
[ -n "$INSTANCE_ID" ] || INSTANCE_ID="$(find_instance_id || true)"

# --- 10. Verify resource status and conditions -------------------------

DIR=$(get_condition directoryAccess)
SIGNIN=$(get_condition signIn)
STATUS=$(vfac get product-instance "$INSTANCE_ID" --output json | jq -r '.resource.status // empty')
note "status=${STATUS} directoryAccess=${DIR:-unknown} signIn=${SIGNIN:-unknown}"

# --- 11. Summary (non-secret only) -------------------------------------

{
  echo "## Identity SSO bootstrap — ${RESOURCE_KEY}"
  echo
  echo "| field | value |"
  echo "| --- | --- |"
  echo "| mode | \`${MODE}\` |"
  echo "| target app | \`${TARGET_APP_NAME}\` (created: \`${APP_CREATED}\`) |"
  echo "| target app client id | \`${TARGET_CLIENT_ID}\` |"
  echo "| identity resource id | \`${INSTANCE_ID}\` |"
  echo "| resource status | \`${STATUS:-unknown}\` |"
  echo "| \`directoryAccess\` | \`${DIR:-unknown}\` |"
  echo "| \`signIn\` | \`${SIGNIN:-unknown}\` |"
  echo
  echo "> \`signIn\` becomes \`READY/FRESH\` only after a human completes a real interactive Entra sign-in."
} >> "$GITHUB_STEP_SUMMARY"

__SSO_CLIENT_SECRET=""
unset __SSO_CLIENT_SECRET

echo "Bootstrap step complete."
