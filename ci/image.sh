#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
[ -d "$OUT/app" ] || fail "no publish output, run: make publish"

if [ "$SELF_CONTAINED" = "true" ]; then
  base="mcr.microsoft.com/dotnet/runtime-deps:10.0"
else
  base="mcr.microsoft.com/dotnet/aspnet:10.0"
fi
tag="${IMAGE_REF:-$IMAGE_NAME:$UPSTREAM_REF}"

log "docker build $tag (base $base)"
docker build -f ci/docker/Dockerfile -t "$tag" \
  --build-arg BASE_IMAGE="$base" \
  --build-arg UPSTREAM_SHA="$UPSTREAM_SHA" \
  --build-arg UPSTREAM_REF="$UPSTREAM_REF" \
  --build-arg SELF_CONTAINED="$SELF_CONTAINED" \
  "$ROOT"
echo "$tag" > "$OUT/image-ref.txt"
