#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
res="$OUT/tests/integration"; mkdir -p "$res"
export CI=true

log "upstream integration suite (containers required)"
dotnet test "$SRC/test/OrchardCore.Tests.Integration/OrchardCore.Tests.Integration.csproj" \
  -c Release -f "$TFM" --no-build -- \
  --report-trx --report-trx-filename integration.trx --results-directory "$res"
