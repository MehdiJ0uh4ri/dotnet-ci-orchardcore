#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
: "${APP_SERVICE_NAME:?}" "${AZURE_RESOURCE_GROUP:?}"
ref="${IMAGE_DIGEST_REF:-$(cat "$OUT/image-digest.txt" 2>/dev/null || true)}"
[ -n "$ref" ] || fail "no digest-pinned image ref, run: make push"
command -v az >/dev/null || fail "az cli required"

log "az webapp config container set -> $ref"
az webapp config container set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --container-image-name "$ref" \
  --output none

# App Service probes the first exposed port unless told otherwise; the image listens on 8080.
az webapp config appsettings set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --settings WEBSITES_PORT=8080 ASPNETCORE_URLS=http://+:8080 \
  --output none

az webapp restart --name "$APP_SERVICE_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --output none

host=$(az webapp show --name "$APP_SERVICE_NAME" --resource-group "$AZURE_RESOURCE_GROUP" \
  --query defaultHostName -o tsv)
log "waiting for https://$host"
for _ in $(seq 1 40); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://$host/" || true)
  [ "$code" != "000" ] && [ "$code" -lt 500 ] && { log "up ($code)"; exit 0; }
  sleep 15
done
fail "app service did not become healthy"
