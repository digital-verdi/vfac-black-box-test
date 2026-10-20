#!/usr/bin/env bash
#
# TEMPORARY first deployment (bootstrap) for Rute and Frende.
#
# Runs only from a manually dispatched workflow, only from main, and is removed
# once the bootstrap is verified. It is the ONLY place that sends the product
# secrets Rute and Frende need for their first configuration:
#   Rute   --secret openRouterApiKey=env:OPENROUTER_API
#   Frende --secret searchProviderApiKey=env:TAVILY_API_KEY   (only when CREATE)
# Frende reaches Rute purely by Resource-output references; no API key is created
# or copied by hand anywhere.
#
# Environment: VFAC_ENDPOINT, VFAC_CREDENTIAL_ID, VFAC_CREDENTIAL_SECRET,
#              VFAC_PROJECT_ID, ADMIN_EMAIL, ENTRA_TENANT_ID, ENTRA_CLIENT_ID,
#              OPENROUTER_API, TAVILY_API_KEY.
set -euo pipefail
source .github/scripts/lib.sh

for v in VFAC_ENDPOINT VFAC_CREDENTIAL_ID VFAC_CREDENTIAL_SECRET VFAC_PROJECT_ID \
         ADMIN_EMAIL ENTRA_TENANT_ID ENTRA_CLIENT_ID OPENROUTER_API TAVILY_API_KEY; do
  [ -n "${!v:-}" ] || fail "required environment variable ${v} is not set"
done

vfac doctor
vfac context set --project "$VFAC_PROJECT_ID"

identity_guard

# --- Rute ---------------------------------------------------------------

render_manifest resources/rute-ai-gateway.yaml /tmp/rute-ai-gateway.yaml true
vfac validate -f /tmp/rute-ai-gateway.yaml

RUTE_SECRETS=()
if plan_json /tmp/rute-ai-gateway.yaml > /tmp/rute.plan.json 2>/tmp/rute.plan.err; then
  note "Rute plans without the OpenRouter credential — it already holds one"
else
  note "Rute needs the OpenRouter credential (first configuration)"
  RUTE_SECRETS=(--secret openRouterApiKey=env:OPENROUTER_API)
  plan_json /tmp/rute-ai-gateway.yaml "${RUTE_SECRETS[@]}" > /tmp/rute.plan.json
fi
cat /tmp/rute.plan.json | jq -c '{manifestKey, action, health, secretsToWrite, requiredSecrets}'
require_action "$(cat /tmp/rute.plan.json)" true >/dev/null

if [ "$(jq -r '.action' /tmp/rute.plan.json)" = "NO_CHANGE" ]; then
  RUTE_ID=$(find_instance_id box-shared-gw-prod)
  wait_condition "$RUTE_ID" routingConfiguration 600
else
  run_apply /tmp/rute-ai-gateway.yaml "${RUTE_SECRETS[@]}"
  RUTE_ID=$(find_instance_id box-shared-gw-prod)
  [ -n "$RUTE_ID" ] || fail "Rute apply did not yield a resource id"
  wait_condition "$RUTE_ID" routingConfiguration 1800
fi
note "Rute id=${RUTE_ID} serviceUrl=$(get_output "$RUTE_ID" serviceUrl)"
note "Rute consoleUrl=$(get_output "$RUTE_ID" consoleUrl)"

# --- Frende -------------------------------------------------------------

render_manifest resources/frende-ai-chat.yaml /tmp/frende-ai-chat.yaml true
vfac validate -f /tmp/frende-ai-chat.yaml

plan=$(plan_json /tmp/frende-ai-chat.yaml)
action=$(jq -r '.action' <<<"$plan")
FRENDE_SECRETS=()
if [ "$action" = "CREATE" ]; then
  note "Frende first configuration: sending the web-search credential"
  FRENDE_SECRETS=(--secret searchProviderApiKey=env:TAVILY_API_KEY)
  plan=$(plan_json /tmp/frende-ai-chat.yaml "${FRENDE_SECRETS[@]}")
  action=$(jq -r '.action' <<<"$plan")
fi
echo "$plan" | jq -c '{manifestKey, action, health, secretsToWrite, requiredSecrets}'
require_action "$plan" true >/dev/null

if [ "$action" = "NO_CHANGE" ]; then
  FRENDE_ID=$(find_instance_id box-shared-chat-prod)
  wait_condition "$FRENDE_ID" modelEndpoint 900
else
  run_apply /tmp/frende-ai-chat.yaml "${FRENDE_SECRETS[@]}"
  FRENDE_ID=$(find_instance_id box-shared-chat-prod)
  [ -n "$FRENDE_ID" ] || fail "Frende apply did not yield a resource id"
  wait_condition "$FRENDE_ID" modelEndpoint 2400
fi
note "Frende id=${FRENDE_ID} serviceUrl=$(get_output "$FRENDE_ID" serviceUrl)"
note "Frende adminPanelUrl=$(get_output "$FRENDE_ID" adminPanelUrl)"

# --- Verify identities, references and bindings -------------------------

[ "$RUTE_ID" != "$FRENDE_ID" ] || fail "Rute and Frende share a resource id"
[ "$RUTE_ID" != "$IDENTITY_ID" ] || fail "Rute collides with Identity"
[ "$FRENDE_ID" != "$IDENTITY_ID" ] || fail "Frende collides with Identity"

vfac export product-instance "$FRENDE_ID" --output json > /tmp/frende.export.json 2>/dev/null \
  || vfac export product-instance "$FRENDE_ID" > /tmp/frende.export.json
echo "Frende references:"
jq -c '{baseURL:.spec.configuration.aiEndpoints[0].baseURL, apiKey:.spec.configuration.modelProviderApiKey,
        identityBindings:[.spec.dependencyBindings|to_entries[]|{k:.key,v:.value.resourceKey}]}' \
  /tmp/frende.export.json 2>/dev/null || cat /tmp/frende.export.json

identity_guard
echo "Bootstrap complete."
