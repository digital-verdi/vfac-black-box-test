#!/usr/bin/env bash
#
# Permanent PdAC deployment: apply an ordered list of committed manifests,
# secret-less, on every push to main.
#
# For each resource: render -> validate -> plan -> enforce the action ->
# (NO_CHANGE: verify ACTIVE + converged and skip) or (UPDATE/ADOPT: require
# secretsToWrite [] then apply --wait) -> verify.
#
# It refuses CREATE: first creation carries secrets and belongs to the
# temporary bootstrap workflow. It never sends a product secret, so the platform
# keeps the secrets the resources already hold.
#
# Environment: VFAC_ENDPOINT, VFAC_CREDENTIAL_ID, VFAC_CREDENTIAL_SECRET,
#              VFAC_PROJECT_ID, ADMIN_EMAIL, ENTRA_TENANT_ID, ENTRA_CLIENT_ID,
#              RESOURCES (space-separated product ids, in dependency order).
set -euo pipefail
source .github/scripts/lib.sh

for v in VFAC_ENDPOINT VFAC_CREDENTIAL_ID VFAC_CREDENTIAL_SECRET VFAC_PROJECT_ID \
         ADMIN_EMAIL ENTRA_TENANT_ID ENTRA_CLIENT_ID; do
  [ -n "${!v:-}" ] || fail "required environment variable ${v} is not set"
done
RESOURCES="${RESOURCES:-identity-sso}"

vfac doctor
vfac context set --project "$VFAC_PROJECT_ID"

identity_guard

for r in $RESOURCES; do
  key=$(resource_key "$r")
  f="/tmp/${r}.yaml"
  render_manifest "resources/${r}.yaml" "$f" true
  vfac validate -f "$f"

  if ! plan=$(plan_json "$f" 2>/tmp/plan.err); then
    cat /tmp/plan.err >&2
    fail "${r}: the platform refused the plan. If the resource does not exist, its first creation is a bootstrap — run the bootstrap workflow; an ordinary push never creates it."
  fi
  echo "$plan" | jq -c '{manifestKey, action, health, secretsToWrite, requiredSecrets}'

  action=$(require_action "$plan" false)
  sw=$(jq -c '.secretsToWrite // []' <<<"$plan")
  [ "$sw" = "[]" ] || fail "${r} would write a product secret (${sw}); that needs the bootstrap workflow"

  id=$(find_instance_id "$key")

  if [ "$action" = "NO_CHANGE" ]; then
    [ "$(jq -r '.health.status // empty' <<<"$plan")" = "ACTIVE" ] || fail "${r}: NO_CHANGE but not ACTIVE"
    [ "$(jq -r '.health.converged // empty' <<<"$plan")" = "true" ] || fail "${r}: NO_CHANGE but not converged"
    note "${r}: NO_CHANGE, ACTIVE and converged"
  else
    [ -n "$id" ] || fail "${r}: ${action} but no existing resource id"
    run_apply "$f"
    id=$(find_instance_id "$key")
    [ -n "$id" ] || fail "${r}: apply did not yield a resource id"
    for c in $(resource_conditions "$r"); do wait_condition "$id" "$c" 1800; done
  fi

  instance_json "$id" | jq -c --arg r "$r" --arg id "$id" \
    '{resource:$r, id:$id, status:.resource.status, conditions:[.resource.conditions[]|{key,state,freshness}]}'
done

identity_guard
echo "All resources converged."
