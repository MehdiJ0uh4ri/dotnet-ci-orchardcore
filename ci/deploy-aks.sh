#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
: "${K8S_NAMESPACE:=cms}"
ref="${IMAGE_DIGEST_REF:-$(cat "$OUT/image-digest.txt" 2>/dev/null || true)}"
[ -n "$ref" ] || fail "no digest-pinned image ref, run: make push"
repo="${ref%@*}"; repo="${repo%%:*}"
digest="${ref#*@}"

log "helm upgrade --install cms ($repo@${digest:0:19})"
helm upgrade --install cms "$ROOT/helm/orchardcore" \
  --namespace "$K8S_NAMESPACE" --create-namespace \
  -f "$ROOT/helm/orchardcore/values.yaml" \
  ${HELM_VALUES_FILE:+-f "$HELM_VALUES_FILE"} \
  --set image.repository="$repo" \
  --set image.digest="$digest" \
  --wait --timeout 10m

kubectl -n "$K8S_NAMESPACE" rollout status deploy/cms-orchardcore --timeout=5m
