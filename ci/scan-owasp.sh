#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
sc="$OUT/scan"; mkdir -p "$sc"
data="${DC_DATA_DIR:-$ROOT/.cache/dependency-check}"; mkdir -p "$data"
: "${NVD_API_KEY:=}"

log "owasp dependency-check (NuGet, cvss>=$OWASP_CVSS_FAIL fails)"
docker run --rm \
  -v "$SRC:/src:ro" -v "$ROOT/ci/gates:/gates:ro" -v "$sc:/report" -v "$data:/usr/share/dependency-check/data" \
  owasp/dependency-check:latest \
  --scan /src --format "ALL" --out /report --project "$IMAGE_NAME" \
  --failOnCVSS "$OWASP_CVSS_FAIL" \
  --disableAssembly \
  ${NVD_API_KEY:+--nvdApiKey "$NVD_API_KEY"} \
  --suppression /gates/owasp-suppressions.xml 2>&1 | tail -20
