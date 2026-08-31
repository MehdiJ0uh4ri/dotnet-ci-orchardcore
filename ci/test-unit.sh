#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
res="$OUT/tests/unit"; cov="$OUT/coverage"; mkdir -p "$res" "$cov"
proj="$SRC/$UNIT_TEST_PROJECT"
asm="$SRC/test/OrchardCore.Tests/bin/Release/$TFM/OrchardCore.Tests.dll"
export CI=true

if [ "${COVERAGE:-true}" = "true" ]; then
  dotnet tool restore >/dev/null
  log "unit tests + coverlet (cobertura)"
  dotnet coverlet "$asm" \
    --target dotnet \
    --targetargs "$asm --report-trx --report-trx-filename unit.trx --results-directory $res" \
    --format cobertura \
    --output "$cov/unit.cobertura.xml" \
    --include "[OrchardCore*]*" \
    --exclude "[*Tests*]*" \
    --exclude-by-attribute "GeneratedCodeAttribute" \
    --threshold 0
else
  log "unit tests (no coverage)"
  dotnet test "$proj" -c Release -f "$TFM" --no-build -- \
    --report-trx --report-trx-filename unit.trx --results-directory "$res"
fi
