#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
res="$OUT/tests/blackbox"; mkdir -p "$res"
: "${IMAGE_REF:?set IMAGE_REF to the image under test}"
export IMAGE_REF
log "black-box suite against $IMAGE_REF"
dotnet test "$ROOT/it/OrchardCore.BlackBox.Tests/OrchardCore.BlackBox.Tests.csproj" \
  -c Release --nologo -- \
  --report-trx --report-trx-filename blackbox.trx --results-directory "$res"
