#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
app="$OUT/app"; rm -rf "$app"
cfg="$(nuget_config)"
extra=(-p:PublishTrimmed=false -p:PublishSingleFile=false -p:RunAnalyzers=false)

if [ "$SELF_CONTAINED" = "true" ]; then
  log "publish self-contained $RID"
  dotnet publish "$SRC/$APP_PROJECT" -c Release -f "$TFM" -r "$RID" \
    --self-contained true --configfile "$cfg" -o "$app" "${extra[@]}" -v minimal
else
  log "publish framework-dependent $RID"
  dotnet publish "$SRC/$APP_PROJECT" -c Release -f "$TFM" -r "$RID" \
    --self-contained false --no-restore -o "$app" "${extra[@]}" -v minimal
fi

[ -f "$app/OrchardCore.Cms.Web.dll" ] || fail "publish output missing entry assembly"
du -sh "$app" | sed 's/^/    /'
