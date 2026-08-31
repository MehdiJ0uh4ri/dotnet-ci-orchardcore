#!/bin/sh
set -e
if [ -x /app/OrchardCore.Cms.Web ]; then
  exec /app/OrchardCore.Cms.Web "$@"
fi
exec dotnet /app/OrchardCore.Cms.Web.dll "$@"
