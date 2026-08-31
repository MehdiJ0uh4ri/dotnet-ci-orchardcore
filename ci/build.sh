#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
log "build Release, no-restore (one netstandard2.0 project in the solution, so no global -f)"
dotnet build "$SRC/$SOLUTION" \
  -c Release \
  --no-restore \
  -p:RunAnalyzers=false \
  -p:ContinuousIntegrationBuild=true \
  -v minimal
