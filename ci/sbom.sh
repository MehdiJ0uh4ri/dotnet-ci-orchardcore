#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
sb="$OUT/sbom"; mkdir -p "$sb"

if command -v syft >/dev/null; then
  log "syft sbom (source + image)"
  syft "dir:$OUT/app" -o cyclonedx-json="$sb/app.cdx.json" -o spdx-json="$sb/app.spdx.json" -q
  if [ -f "$OUT/image-ref.txt" ]; then
    syft "docker:$(cat "$OUT/image-ref.txt")" -o cyclonedx-json="$sb/image.cdx.json" -q
  fi
else
  log "syft absent, falling back to sbom-tool (SPDX only)"
  dotnet tool restore >/dev/null
  dotnet sbom-tool generate -b "$OUT/app" -bc "$SRC" -pn "$IMAGE_NAME" \
    -pv "$UPSTREAM_REF" -ps OrchardCMS -m "$sb" -D true
fi

f="$sb/app.cdx.json"
[ -f "$f" ] || f="$sb/_manifest/spdx_2.2/manifest.spdx.json"
n=$(grep -o '"purl"' "$f" | wc -l)
log "sbom components: $n (min $SBOM_MIN_COMPONENTS)"
[ "$n" -ge "$SBOM_MIN_COMPONENTS" ] || fail "sbom looks truncated ($n components)"
