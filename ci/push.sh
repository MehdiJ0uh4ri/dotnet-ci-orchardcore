#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
[ -f "$OUT/image-ref.txt" ] || fail "no local image, run: make image"
local_ref=$(cat "$OUT/image-ref.txt")
: "${REGISTRY:?set REGISTRY (e.g. myacr.azurecr.io, artifactory.example.com/docker, ghcr.io/owner)}"

# One login path per registry flavour; ACR admin creds are the fallback when no
# federated identity is configured on the runner.
case "$REGISTRY" in
  *.azurecr.io*)
    if [ -n "${ACR_USERNAME:-}" ]; then
      log "docker login ACR ${REGISTRY%%/*} (service principal)"
      printf '%s' "${ACR_PASSWORD:?ACR_PASSWORD required with ACR_USERNAME}" \
        | docker login "${REGISTRY%%/*}" -u "$ACR_USERNAME" --password-stdin
    elif command -v az >/dev/null; then
      log "az acr login ${REGISTRY%%/*}"
      az acr login --name "$(echo "${REGISTRY%%/*}" | cut -d. -f1)"
    else
      fail "no ACR credentials: set ACR_USERNAME/ACR_PASSWORD or install az"
    fi
    ;;
  *artifactory*)
    log "docker login Artifactory ${REGISTRY%%/*}"
    printf '%s' "${ARTIFACTORY_TOKEN:?}" \
      | docker login "${REGISTRY%%/*}" -u "${ARTIFACTORY_USER:?}" --password-stdin
    ;;
  ghcr.io*)
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      printf '%s' "$GITHUB_TOKEN" | docker login ghcr.io -u "${GITHUB_ACTOR:-x}" --password-stdin
    fi
    ;;
esac

remote="$REGISTRY/$IMAGE_NAME:$UPSTREAM_REF-$(echo "$UPSTREAM_SHA" | cut -c1-7)"
docker tag "$local_ref" "$remote"
log "push $remote"
docker push "$remote"

digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$remote" | cut -d@ -f2)
[ -n "$digest" ] || fail "no digest after push"
echo "$remote@$digest" | tee "$OUT/image-digest.txt"
