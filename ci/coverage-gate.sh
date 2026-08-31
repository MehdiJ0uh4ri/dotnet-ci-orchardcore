#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
f="$OUT/coverage/unit.cobertura.xml"
[ -f "$f" ] || fail "no cobertura report at $f"
rate=$(grep -o 'line-rate="[0-9.]*"' "$f" | head -1 | grep -o '[0-9.]*')
pct=$(awk -v r="$rate" 'BEGIN{printf "%.2f", r*100}')
log "line coverage ${pct}% (min ${COVERAGE_MIN_LINE}%)"
awk -v p="$pct" -v m="$COVERAGE_MIN_LINE" 'BEGIN{exit !(p+0 >= m+0)}' \
  || fail "coverage ${pct}% below gate ${COVERAGE_MIN_LINE}%"
