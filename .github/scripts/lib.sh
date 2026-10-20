#!/usr/bin/env bash
#
# Shared helpers for the Varde Flyt PdAC scripts. Sourced, never executed
# directly.

IDENTITY_KEY="box-shared-sso-prod"
IDENTITY_ID="pri_01m5crw6b7e008b4jz1d67xbkk"

fail() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "::notice::$*"; }
mask() { echo "::add-mask::$1"; }

# Product id -> manifest key
resource_key() {
  case "$1" in
    identity-sso) echo "box-shared-sso-prod" ;;
    rute-ai-gateway) echo "box-shared-gw-prod" ;;
    frende-ai-chat) echo "box-shared-chat-prod" ;;
    *) echo "$1" ;;
  esac
}

# Condition this resource must reach READY/FRESH when it changed this run.
resource_conditions() {
  case "$1" in
    identity-sso) echo "signIn directoryAccess" ;;
    rute-ai-gateway) echo "routingConfiguration" ;;
    frende-ai-chat) echo "modelEndpoint" ;;
    *) echo "" ;;
  esac
}

render_manifest() { bash .github/scripts/render-manifest.sh "$1" "$2" "${3:-true}"; }
plan_json() { local f="$1"; shift; vfac plan -f "$f" "$@" --output json; }

run_apply() { # $1=file, rest=args
  local f="$1"; shift
  if ! vfac apply -f "$f" "$@" --wait > /tmp/vfac-apply.log 2>&1; then
    cat /tmp/vfac-apply.log >&2
    fail "apply failed for ${f}"
  fi
  cat /tmp/vfac-apply.log
}

# Refuse every plan action we must not perform on an ordinary run.
require_action() { # $1=plan json, $2=allow_create(true|false)
  local action; action=$(jq -r '.action // empty' <<<"$1")
  case "$action" in
    NO_CHANGE|UPDATE|ADOPT) echo "$action" ;;
    CREATE)
      if [ "${2:-false}" = "true" ]; then
        echo "$action"
      else
        fail "plan would CREATE '$(jq -r '.manifestKey' <<<"$1")'; first creation is a bootstrap, not an ordinary push"
      fi ;;
    GONE|UPGRADE_REQUIRED|RECREATE_REQUIRED) fail "plan is terminal (${action}); refusing to apply" ;;
    "") fail "plan returned no action" ;;
    *) fail "unexpected plan action '${action}'; refusing to apply" ;;
  esac
}

find_instance_id() { # $1=manifest key
  vfac get product-instances --output json \
    | jq -r --arg k "$1" '
        (.productInstances // [])[]
        | select((.manifestKey // .metadata.key // .key // .displayName) == $k)
        | (.productInstanceId // .id // .resourceId) ' 2>/dev/null | head -1
}

instance_json() { vfac get product-instance "$1" --output json; }

get_output() { # $1=id $2=output key
  instance_json "$1" | jq -r --arg k "$2" '(.resource.outputs // .outputs // {})[$k] // empty'
}

get_condition() { # $1=id $2=condition key -> STATE/FRESHNESS
  instance_json "$1" | jq -r --arg k "$2" '(.resource.conditions // [])[] | select(.key==$k) | "\(.state)/\(.freshness)"' 2>/dev/null | head -1
}

wait_condition() { # $1=id $2=condition $3=timeout seconds
  local t="${3:-900}" i=0 st=""
  while [ "$i" -lt "$t" ]; do
    st=$(get_condition "$1" "$2")
    if [ "$st" = "READY/FRESH" ]; then note "condition '${2}' = READY/FRESH"; return 0; fi
    sleep 10; i=$((i + 10))
  done
  fail "condition '${2}' did not reach READY/FRESH within ${t}s (last: ${st:-unknown})"
}

# The existing Identity resource must be untouched before (and after) a mutation.
identity_guard() {
  local f=/tmp/guard-identity.yaml plan action sw id
  render_manifest resources/identity-sso.yaml "$f" true
  id=$(find_instance_id "$IDENTITY_KEY")
  [ "$id" = "$IDENTITY_ID" ] || fail "Identity resource id changed: expected ${IDENTITY_ID}, got '${id:-none}'"
  plan=$(vfac plan -f "$f" --output json)
  action=$(jq -r '.action // empty' <<<"$plan")
  [ "$action" = "NO_CHANGE" ] || fail "Identity plan action is '${action}', expected NO_CHANGE"
  sw=$(jq -c '.secretsToWrite // []' <<<"$plan")
  [ "$sw" = "[]" ] || fail "Identity would write secrets (${sw})"
  [ "$(jq -r '.health.status // empty' <<<"$plan")" = "ACTIVE" ] || fail "Identity is not ACTIVE"
  [ "$(jq -r '.health.converged // empty' <<<"$plan")" = "true" ] || fail "Identity is not converged"
  note "Identity guard OK: ${IDENTITY_ID} unchanged, NO_CHANGE, secretsToWrite []"
}
