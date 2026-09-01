set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a
. "$ROOT/ci/upstream.env"
. "$ROOT/ci/gates.env"
set +a

SRC="$ROOT/$UPSTREAM_DIR"
OUT="$ROOT/.out"
mkdir -p "$OUT"

export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export NUGET_PACKAGES="${NUGET_PACKAGES:-$ROOT/.nuget/packages}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

nuget_config() {
  if [ -n "${ARTIFACTORY_URL:-}" ]; then
    echo "$ROOT/ci/nuget/artifactory.config"
  else
    echo "$ROOT/ci/nuget/public.config"
  fi
}

need_src() { [ -d "$SRC" ] || fail "upstream not present, run: make bootstrap"; }
