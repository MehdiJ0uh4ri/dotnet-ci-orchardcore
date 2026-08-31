#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
[ -f "$OUT/image-ref.txt" ] || fail "no local image, run: make image"
local_ref=$(cat "$OUT/image-ref.txt")
: "${REGISTRY:?set REGISTRY (e.g. myacr.azurecr.io or artifactory.example.com/docker)}"
remote="$REGISTRY/$IMAGE_NAME:$UPSTREAM_REF-$(echo "$UPSTREAM_SHA" | cut -c1-7)"

docker tag "$local_ref" "$remote"
log "push $remote"
docker push "$remote"
digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$remote" | cut -d@ -f2)
[ -n "$digest" ] || fail "no digest after push"
echo "$remote@$digest" | tee "$OUT/image-digest.txt"
