#!/usr/bin/env bash
#
# Demo teardown: delete Rute and Frende — and NOTHING else.
#
# The deployment code (manifests, the permanent varde-flyt-deploy.yml and every
# script) is left untouched, so the same environment can be created again with
# the manual bootstrap workflow followed by the permanent deploy workflow. No
# manifest or resource-list change is needed between deleting and recreating.
#
# Order: Frende first, then Rute. Frende READS Rute's outputs (serviceUrl,
# serviceApiKey), and a resource another resource reads cannot be deleted until
# that reference is gone; deleting Frende releases it.
#
# Identity (box-shared-sso-prod) is never a lifecycle target here: it is guarded
# before and after.
#
# Environment: VFAC_ENDPOINT, VFAC_CREDENTIAL_ID, VFAC_CREDENTIAL_SECRET,
#              VFAC_PROJECT_ID, ADMIN_EMAIL, ENTRA_TENANT_ID, ENTRA_CLIENT_ID.
set -euo pipefail
source .github/scripts/lib.sh

for v in VFAC_ENDPOINT VFAC_CREDENTIAL_ID VFAC_CREDENTIAL_SECRET VFAC_PROJECT_ID \
         ADMIN_EMAIL ENTRA_TENANT_ID ENTRA_CLIENT_ID; do
  [ -n "${!v:-}" ] || fail "required environment variable ${v} is not set"
done

vfac doctor
vfac context set --project "$VFAC_PROJECT_ID"

# Identity must be pristine before anything is deleted.
identity_guard

DELETE_KEYS="box-shared-chat-prod box-shared-gw-prod"

for key in $DELETE_KEYS; do
  [ "$key" = "$IDENTITY_KEY" ] && fail "refusing to delete the Identity resource"

  id=$(find_instance_id "$key")
  if [ -z "$id" ]; then
    note "${key}: not present, nothing to delete"
    continue
  fi

  # Ask the resource itself whether delete is allowed, rather than trying.
  life=$(instance_json "$id" | jq -c '.lifecycle')
  if ! jq -e '(.allowed // []) | index("delete") != null' >/dev/null <<<"$life"; then
    reason=$(jq -r '(.refused // [])[] | select(.command=="delete") | "\(.reason) \(.needs // "")"' <<<"$life" | head -1)
    fail "delete of ${key} (${id}) is not allowed for this credential: ${reason:-unknown}"
  fi

  note "${key} (${id}): deleting"
  latest_before=$(vfac get operations --resource "$id" --output json 2>/dev/null | jq -r '.operations[0].operationId // empty' || true)

  if ! vfac lifecycle delete "$id" --yes --output json > /tmp/teardown-delete.log 2>&1; then
    cat /tmp/teardown-delete.log >&2
    fail "lifecycle delete failed for ${key} (${id})"
  fi
  cat /tmp/teardown-delete.log

  opid=$(jq -r '.operationId // empty' /tmp/teardown-delete.log 2>/dev/null || true)
  [ -n "$opid" ] || opid=$(grep -oE 'op_[A-Za-z0-9]+' /tmp/teardown-delete.log | head -1 || true)
  if [ -z "$opid" ]; then
    opid=$(vfac get operations --resource "$id" --output json \
      | jq -r --arg b "$latest_before" '.operations[] | select(.operationId != $b) | .operationId' | head -1 || true)
  fi
  [ -n "$opid" ] || fail "${key}: could not find the delete operation id"
  note "${key}: delete operation ${opid} — waiting for it to settle"

  i=0
  while [ "$i" -lt 1800 ]; do
    op=$(vfac get operation "$opid" --output json)
    phase=$(jq -r '.phase // empty' <<<"$op")
    case "$phase" in
      succeeded) note "${key}: delete succeeded"; break ;;
      failed) jq -c '{phase, failure}' <<<"$op" >&2; fail "${key}: delete failed" ;;
      *) sleep 10; i=$((i + 10)) ;;
    esac
  done
  [ "$i" -lt 1800 ] || fail "${key}: delete did not settle within 1800s"

  still=$(find_instance_id "$key")
  [ -z "$still" ] || fail "${key}: still present after delete (${still})"
done

# Identity must be pristine after the deletions too.
identity_guard

echo "Remaining Product Instances:"
vfac get product-instances --output json \
  | jq -c '.productInstances[] | {key:.manifestKey, id:.productInstanceId, productId, status}'
echo "Teardown complete. Redeploy with the bootstrap workflow, then the deploy workflow."
