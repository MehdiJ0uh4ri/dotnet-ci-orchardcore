#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
cfg="$(nuget_config)"
log "restore via $(basename "$cfg") into $NUGET_PACKAGES"
dotnet restore "$SRC/$SOLUTION" \
  --configfile "$cfg" \
  --nologo \
  -p:RunAnalyzers=false \
  -v minimal
dotnet nuget locals http-cache --list >/dev/null
