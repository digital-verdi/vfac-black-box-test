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
jqv() { jq -r "$1"; }

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

plan_json() { # $1=file, rest=extra args
  local f="$1"; shift
  vfac plan -f "$f" "$@" --output json
}

# Assert the plan action is one we can apply, and refuse the terminal ones.
require_action() { # $1=plan json
  local action; action=$(jq -r '.action // empty' <<<"$1")
  case "$action" in
    CREATE|UPDATE|NO_CHANGE|ADOPT) echo "$action" ;;
    GONE|UPGRADE_REQUIRED|RECREATE_REQUIRED) fail "plan is terminal (${action}); not applying" ;;
    "") fail "plan returned no action" ;;
    *) fail "unexpected plan action '${action}'; refusing to apply" ;;
  esac
}

apply_wait() { # $1=file, rest=extra args
  local f="$1"; shift
  vfac apply -f "$f" "$@" --wait --output json
}

find_instance_id() {
  vfac get product-instances --output json \
    | jq -r --arg k "$RESOURCE_KEY" '
        (.productInstances // [])[]
        | select((.metadata.key // .key // .name) == $k)
        | (.productInstanceId // .id // .resourceId) ' 2>/dev/null | head -1
}

get_output() { # $1=output key
  vfac get product-instance "$INSTANCE_ID" --output json \
    | jq -r --arg k "$1" '(.resource.outputs // .outputs // {})[$k] // empty'
}

get_condition() { # $1=condition key -> "STATE/FRESHNESS"
  vfac get product-instance "$INSTANCE_ID" --output json \
    | jq -r --arg k "$1" '(.resource.conditions // [])[] | select(.key==$k) | "\(.state)/\(.freshness)"' 2>/dev/null | head -1
}

# --- Microsoft Graph ----------------------------------------------------

graph_token() {
  curl -sS -X POST "https://login.microsoftonline.com/${ENTRA_TENANT_ID}/oauth2/v2.0/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=${ENTRA_APP_ID}" \
    --data-urlencode "client_secret=${ENTRA_APP_SECRET}" \
    --data-urlencode "scope=https://graph.microsoft.com/.default" \
    --data-urlencode "grant_type=client_credentials" \
    | jq -r '.access_token // empty'
}

greq() { # $1=method $2=path $3=body(optional)
  local m="$1" p="$2" b="${3:-}"
  if [ -n "$b" ]; then
    curl -sS -X "$m" -H "Authorization: Bearer ${GRAPH_TOKEN}" -H 'Content-Type: application/json' -d "$b" "${GRAPH}${p}"
  else
    curl -sS -X "$m" -H "Authorization: Bearer ${GRAPH_TOKEN}" "${GRAPH}${p}"
  fi
}
gget() { # $1=path, rest: --data-urlencode pairs
  local p="$1"; shift
  curl -sS -G -H "Authorization: Bearer ${GRAPH_TOKEN}" "$@" "${GRAPH}${p}"
}
gcheck() { # $1=response json, $2=context
  if [ "$(jq -r 'has("error")' <<<"$1" 2>/dev/null)" = "true" ]; then
    fail "$2: Graph error $(jq -r '.error.code' <<<"$1") — $(jq -r '.error.message' <<<"$1")"
  fi
}

# --- 1. vfac sign-in ----------------------------------------------------

vfac_login
note "vfac signed in as: $(vfac whoami 2>/dev/null | head -1)"

# --- 2. Graph preflight -------------------------------------------------

GRAPH_TOKEN="$(graph_token)"
[ -n "$GRAPH_TOKEN" ] || fail "Microsoft Graph token request failed (check ENTRA_TENANT_ID / ENTRA_APP_ID / ENTRA_APP_SECRET)"
mask "$GRAPH_TOKEN"

GRAPH_SP_ID=$(gget "/servicePrincipals" --data-urlencode "\$filter=appId eq '${GRAPH_APP_ID}'" --data-urlencode "\$select=id" | jq -r '.value[0].id // empty')
[ -n "$GRAPH_SP_ID" ] || fail "Microsoft Graph service principal not found in this tenant"
ROLES_JSON=$(gget "/servicePrincipals/${GRAPH_SP_ID}/appRoles" --data-urlencode "\$select=id,value")
SCOPES_JSON=$(gget "/servicePrincipals/${GRAPH_SP_ID}/oauth2PermissionScopes" --data-urlencode "\$select=id,value")
role_id()  { jq -r --arg v "$1" '.value[]|select(.value==$v)|.id' <<<"$ROLES_JSON" | head -1; }
scope_id() { jq -r --arg v "$1" '.value[]|select(.value==$v)|.id' <<<"$SCOPES_JSON" | head -1; }

PROV_SP_ID=$(gget "/servicePrincipals" --data-urlencode "\$filter=appId eq '${ENTRA_APP_ID}'" --data-urlencode "\$select=id" | jq -r '.value[0].id // empty')
[ -n "$PROV_SP_ID" ] || fail "provisioning app has no service principal in this tenant (is it a multi-tenant/guest app?)"
PROV_ROLES=$(gget "/servicePrincipals/${PROV_SP_ID}/appRoleAssignments" --data-urlencode "\$select=appRoleId" | jq -r '.value[].appRoleId')

missing=()
for perm in Application.ReadWrite.All AppRoleAssignment.ReadWrite.All DelegatedPermissionGrant.ReadWrite.All Application.Read.All; do
  id=$(role_id "$perm")
  [ -n "$id" ] || fail "Graph application permission '${perm}' not found on the Microsoft Graph service principal"
  grep -qx "$id" <<<"$PROV_ROLES" || missing+=("$perm")
done
[ ${#missing[@]} -eq 0 ] || fail "provisioning app lacks consented Microsoft Graph application permissions: ${missing[*]} (grant them with admin consent)"
note "Graph preflight OK: provisioning app holds the required application permissions"

# --- 3. Find or create the SSO target app -------------------------------

APPS=$(gget "/applications" --data-urlencode "\$filter=displayName eq '${TARGET_APP_NAME}'" --data-urlencode "\$select=id,appId,displayName")
gcheck "$APPS" "list applications"
COUNT=$(jq -r '.value|length' <<<"$APPS")
[ "$COUNT" -le 1 ] || fail "multiple_app_registrations: ${COUNT} app registrations named '${TARGET_APP_NAME}'"

if [ "$COUNT" -eq 1 ]; then
  TARGET_OBJECT_ID=$(jq -r '.value[0].id' <<<"$APPS")
  TARGET_CLIENT_ID=$(jq -r '.value[0].appId' <<<"$APPS")
  APP_CREATED=false
  note "target app '${TARGET_APP_NAME}' already exists; reusing it"
else
  CREATED=$(greq POST "/applications" "$(jq -nc --arg n "$TARGET_APP_NAME" '{displayName:$n,signInAudience:"AzureADMyOrg"}')")
  gcheck "$CREATED" "create application"
  TARGET_OBJECT_ID=$(jq -r '.id' <<<"$CREATED")
  TARGET_CLIENT_ID=$(jq -r '.appId' <<<"$CREATED")
  APP_CREATED=true
  note "created target app '${TARGET_APP_NAME}'"
fi
[ -n "$TARGET_OBJECT_ID" ] && [ "$TARGET_OBJECT_ID" != "null" ] || fail "could not obtain the target application object id"

TARGET_SP_ID=$(gget "/servicePrincipals" --data-urlencode "\$filter=appId eq '${TARGET_CLIENT_ID}'" --data-urlencode "\$select=id" | jq -r '.value[0].id // empty')
if [ -z "$TARGET_SP_ID" ]; then
  SP=$(greq POST "/servicePrincipals" "$(jq -nc --arg a "$TARGET_CLIENT_ID" '{appId:$a}')")
  gcheck "$SP" "create service principal"
  TARGET_SP_ID=$(jq -r '.id' <<<"$SP")
fi
[ -n "$TARGET_SP_ID" ] || fail "could not obtain the target service principal"

# --- 4. Existing Identity resource? ------------------------------------

INSTANCE_ID="$(find_instance_id || true)"
EXISTING=false
if [ -n "$INSTANCE_ID" ]; then EXISTING=true; fi

configured() {
  [ "$(get_condition directoryAccess)" = "READY/FRESH" ]
}

# Decide whether to mint a fresh client secret.
MINT=true
if [ "$MODE" != "rotate" ] && [ "$EXISTING" = true ] && configured; then
  MINT=false
fi

if [ "$EXISTING" = true ] && [ "$MODE" = "bootstrap" ] && configured; then
  note "Identity '${RESOURCE_KEY}' is already configured and directory access is READY/FRESH — nothing to bootstrap"
  echo "| field | value |" >> "$GITHUB_STEP_SUMMARY"
  echo "| --- | --- |" >> "$GITHUB_STEP_SUMMARY"
  echo "| result | already bootstrapped (no change) |" >> "$GITHUB_STEP_SUMMARY"
  echo "| resource id | \`${INSTANCE_ID}\` |" >> "$GITHUB_STEP_SUMMARY"
  echo "| target app client id | \`${TARGET_CLIENT_ID}\` |" >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

# --- 5. Mint the target client secret (kept in this step's memory only) --

export __SSO_CLIENT_SECRET=""
if [ "$MINT" = true ]; then
  END=$(date -u -d '+180 days' +%Y-%m-%dT%H:%M:%SZ)
  PW=$(greq POST "/applications/${TARGET_OBJECT_ID}/addPassword" \
        "$(jq -nc --arg d "$END" '{passwordCredential:{displayName:"vfac-bootstrap-180d",endDateTime:$d}}')")
  gcheck "$PW" "add password"
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
  A1=$(require_action "$PLAN1")
  note "step 1 plan action: ${A1}"
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

USER_READ=$(role_id "User.Read.All")
GROUP_MEMBER=$(role_id "GroupMember.Read.All")
[ -n "$USER_READ" ] && [ -n "$GROUP_MEMBER" ] || fail "could not resolve User.Read.All / GroupMember.Read.All app role ids"

# Required access: application roles + whichever OIDC scopes are exposed.
ACCESS=$(jq -nc \
  --arg ur "$USER_READ" --arg gm "$GROUP_MEMBER" \
  --arg openid "$(scope_id openid)" --arg profile "$(scope_id profile)" --arg email "$(scope_id email)" '
  [{id:$ur,type:"Role"},{id:$gm,type:"Role"}]
  + ([{v:$openid},{v:$profile},{v:$email}] | map(select(.v != "") | {id:.v,type:"Scope"}))')

# Redirect URI (Web) + Microsoft Graph required access (application + delegated).
PATCH_BODY=$(jq -nc \
  --arg uri "$REDIRECT_URI" --arg graph "$GRAPH_APP_ID" --argjson access "$ACCESS" \
  '{web:{redirectUris:[$uri]}, requiredResourceAccess:[{resourceAppId:$graph, resourceAccess:$access}]}')
RESP=$(greq PATCH "/applications/${TARGET_OBJECT_ID}" "$PATCH_BODY")
gcheck "$RESP" "configure target application"

# Enterprise app: Assignment required = No.
RESP=$(greq PATCH "/servicePrincipals/${TARGET_SP_ID}" '{"appRoleAssignmentRequired":false}')
gcheck "$RESP" "set assignment required = No"

# Admin consent: application roles -> app role assignments.
for rid in "$USER_READ" "$GROUP_MEMBER"; do
  RESP=$(greq POST "/servicePrincipals/${TARGET_SP_ID}/appRoleAssignments" \
    "$(jq -nc --arg p "$TARGET_SP_ID" --arg r "$GRAPH_SP_ID" --arg a "$rid" '{principalId:$p,resourceId:$r,appRoleId:$a}')")
  # A re-run answers 400 "already exists" — that is success, not a failure.
  if [ "$(jq -r 'has("error")' <<<"$RESP")" = "true" ]; then
    if ! jq -e '.error.code == "Request_BadRequest" and (.error.message|test("already";"i"))' >/dev/null <<<"$RESP"; then
      gcheck "$RESP" "consent app role ${rid}"
    fi
  fi
done

# Tenant-wide delegated consent for the OIDC scopes.
SCOPE_STR="openid profile email"
EXISTING_GRANT=$(gget "/oauth2PermissionGrants" --data-urlencode "\$filter=clientId eq '${TARGET_SP_ID}' and resourceId eq '${GRAPH_SP_ID}'" --data-urlencode "\$select=id" | jq -r '.value[0].id // empty')
if [ -n "$EXISTING_GRANT" ]; then
  RESP=$(greq PATCH "/oauth2PermissionGrants/${EXISTING_GRANT}" "$(jq -nc --arg s "$SCOPE_STR" '{scope:$s}')")
else
  RESP=$(greq POST "/oauth2PermissionGrants" "$(jq -nc --arg c "$TARGET_SP_ID" --arg r "$GRAPH_SP_ID" --arg s "$SCOPE_STR" '{clientId:$c,consentType:"AllPrincipals",resourceId:$r,scope:$s}')")
fi
gcheck "$RESP" "grant delegated consent"
note "target app configured: redirect URI, Graph permissions and consent"

# --- 9. Identity step 2 — Entra integration ----------------------------

export ADMIN_EMAIL="$INITIAL_EMAIL_ADDRESS"
export ENTRA_TENANT_ID
export ENTRA_CLIENT_ID="$TARGET_CLIENT_ID"
render_manifest /tmp/entra.yaml true
vfac validate -f /tmp/entra.yaml

SECRET_ARGS=()
if [ -n "$__SSO_CLIENT_SECRET" ]; then
  SECRET_ARGS=(--secret /entra/clientSecret=env:__SSO_CLIENT_SECRET)
fi

PLAN2=$(plan_json /tmp/entra.yaml "${SECRET_ARGS[@]}")
A2=$(require_action "$PLAN2")
SW=$(jq -c '.secretsToWrite // []' <<<"$PLAN2")
note "step 2 plan action: ${A2}; secretsToWrite: ${SW}"
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

# Best-effort cleanup of the in-memory secret.
__SSO_CLIENT_SECRET=""
unset __SSO_CLIENT_SECRET

echo "Bootstrap step complete."
