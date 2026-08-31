#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
f="$OUT/coverage/unit.cobertura.xml"
[ -f "$f" ] || { echo "_no coverage report produced_"; exit 0; }
line=$(grep -o 'line-rate="[0-9.]*"' "$f" | head -1 | grep -o '[0-9.]*')
branch=$(grep -o 'branch-rate="[0-9.]*"' "$f" | head -1 | grep -o '[0-9.]*')
printf '### Coverage\n\n| metric | value | gate |\n| --- | --- | --- |\n'
awk -v l="$line" -v b="$branch" -v m="$COVERAGE_MIN_LINE" 'BEGIN{
  printf "| line | %.2f%% | >= %s%% |\n", l*100, m
  printf "| branch | %.2f%% | - |\n", b*100
}'
printf '\nupstream `%s` @ `%s`\n' "$UPSTREAM_REF" "${UPSTREAM_SHA:0:12}"
