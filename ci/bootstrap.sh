#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

if [ -d "$SRC/.git" ]; then
  have=$(git -C "$SRC" rev-parse HEAD)
  [ "$have" = "$UPSTREAM_SHA" ] && { log "upstream already at $UPSTREAM_SHA"; exit 0; }
  log "upstream at $have, moving to $UPSTREAM_SHA"
else
  rm -rf "$SRC"; mkdir -p "$SRC"; git -C "$SRC" init -q
  git -C "$SRC" remote add origin "$UPSTREAM_REPO"
fi

git -C "$SRC" fetch --depth 1 origin "$UPSTREAM_SHA"
git -C "$SRC" checkout -q --detach FETCH_HEAD
git -C "$SRC" clean -xfdq

got=$(git -C "$SRC" rev-parse HEAD)
[ "$got" = "$UPSTREAM_SHA" ] || fail "sha mismatch: $got != $UPSTREAM_SHA"
[ -f "$SRC/$SOLUTION" ] || fail "$SOLUTION missing, upstream layout changed"
[ -f "$SRC/$APP_PROJECT" ] || fail "$APP_PROJECT missing, upstream layout changed"

sdk=$(cd "$SRC" && dotnet --version 2>/dev/null || echo "sdk not installed")
log "upstream $UPSTREAM_REF @ $UPSTREAM_SHA, sdk $sdk"
