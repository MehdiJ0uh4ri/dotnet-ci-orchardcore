#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
{
  echo "$UPSTREAM_SHA"
  cat "$(nuget_config)"
  find "$SRC" -name '*.csproj' -o -name 'Directory.Packages.props' -o -name 'global.json' \
    | sort | xargs sha256sum
} | sha256sum | cut -c1-40
