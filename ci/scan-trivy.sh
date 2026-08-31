#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
sc="$OUT/scan"; mkdir -p "$sc"
ignore=""; [ "$TRIVY_IGNORE_UNFIXED" = "true" ] && ignore="--ignore-unfixed"

log "trivy fs (NuGet graph)"
trivy fs "$SRC" --scanners vuln --severity "$TRIVY_SEVERITY" $ignore \
  --format json --output "$sc/trivy-fs.json" --exit-code 0 --quiet

if [ -f "$OUT/image-ref.txt" ]; then
  ref=$(cat "$OUT/image-ref.txt")
  log "trivy image $ref"
  trivy image "$ref" --severity "$TRIVY_SEVERITY" $ignore \
    --format sarif --output "$sc/trivy-image.sarif" --exit-code 0 --quiet
  trivy image "$ref" --severity "$TRIVY_SEVERITY" $ignore \
    --exit-code 1 --quiet || fail "trivy: $TRIVY_SEVERITY findings in image"
fi

hits=$(grep -o '"VulnerabilityID"' "$sc/trivy-fs.json" | wc -l)
log "trivy fs findings ($TRIVY_SEVERITY): $hits"
