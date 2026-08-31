#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
need_src
: "${SONAR_TOKEN:?}" "${SONAR_PROJECT_KEY:?}" "${SONAR_ORGANIZATION:?}"
dotnet tool restore >/dev/null
cov="$OUT/coverage/unit.cobertura.xml"
args=(
  /k:"$SONAR_PROJECT_KEY"
  /o:"$SONAR_ORGANIZATION"
  /d:sonar.host.url=https://sonarcloud.io
  /d:sonar.token="$SONAR_TOKEN"
  /d:sonar.cs.opencover.reportsPaths=
  /d:sonar.cs.vscoveragexml.reportsPaths=
  /d:sonar.coverageReportPaths=
  /d:sonar.cs.cobertura.reportsPaths="$cov"
  /d:sonar.scanner.scanAll=false
  /d:sonar.exclusions="**/wwwroot/**,**/node_modules/**,**/*.min.js"
)
[ -n "${PR_NUMBER:-}" ] && args+=(
  /d:sonar.pullrequest.key="$PR_NUMBER"
  /d:sonar.pullrequest.branch="${PR_BRANCH:-}"
  /d:sonar.pullrequest.base="${PR_BASE:-main}"
)

log "sonarscanner begin"
dotnet sonarscanner begin "${args[@]}"
dotnet build "$SRC/$SOLUTION" -c Release -p:RunAnalyzers=false -v minimal
dotnet sonarscanner end /d:sonar.token="$SONAR_TOKEN"

if [ "${SONAR_WAIT_FOR_GATE:-true}" = "true" ]; then
  log "waiting on quality gate"
  task="$SRC/.sonarqube/out/.sonar/report-task.txt"
  ceid=$(grep '^ceTaskId=' "$task" | cut -d= -f2)
  for _ in $(seq 1 60); do
    st=$(curl -sfu "$SONAR_TOKEN:" "https://sonarcloud.io/api/ce/task?id=$ceid" | grep -o '"status":"[A-Z]*"' | head -1 | cut -d'"' -f4)
    [ "$st" = "SUCCESS" ] && break
    [ "$st" = "FAILED" ] || [ "$st" = "CANCELED" ] && fail "sonar analysis $st"
    sleep 10
  done
  gate=$(curl -sfu "$SONAR_TOKEN:" \
    "https://sonarcloud.io/api/qualitygates/project_status?projectKey=$SONAR_PROJECT_KEY" \
    | grep -o '"status":"[A-Z_]*"' | head -1 | cut -d'"' -f4)
  log "quality gate: $gate"
  [ "$gate" = "OK" ] || fail "quality gate $gate"
fi
