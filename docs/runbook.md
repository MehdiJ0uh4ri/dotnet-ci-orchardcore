# Runbook

## Prerequisites

- .NET SDK 10.0.200+ (`global.json` rolls forward to latest major)
- Docker (integration + black-box + OWASP stages)
- Optional: `syft`, `trivy`, `helm`

## Local pipeline

```bash
make bootstrap      # clone upstream at the pinned SHA into ./upstream
make ci             # restore -> build -> test -> coverage -> publish -> image -> sbom -> trivy -> blackbox
```

Individual stages mirror the CI job names: `make test`, `make sonar`, `make image`,
`make owasp`, `make lint-helm`.

## Moving the upstream pin

1. `git ls-remote --tags https://github.com/OrchardCMS/OrchardCore.git`
2. Edit `UPSTREAM_SHA` and `UPSTREAM_REF` in `ci/upstream.env`.
3. `make distclean bootstrap restore build test`.
4. If `bootstrap.sh` fails on the layout assertions, upstream moved `OrchardCore.slnx`
   or the Cms.Web project — fix the paths in `ci/upstream.env`, not the scripts.

The nightly `upstream-drift` job warns when a newer tag exists. It never bumps the pin.

## Secrets and variables

| Name | Where | Purpose |
| --- | --- | --- |
| `SONAR_TOKEN` | secret | SonarCloud analysis + gate polling |
| `SONAR_PROJECT_KEY`, `SONAR_ORGANIZATION` | vars | SonarCloud project identity |
| `NVD_API_KEY` | secret | OWASP dependency-check feed throttling |
| `ARTIFACTORY_URL`, `ARTIFACTORY_NUGET_REPO`, `ARTIFACTORY_USER`, `ARTIFACTORY_TOKEN` | secrets | switches restore onto the Artifactory virtual feed |
| `SELF_CONTAINED` | var | `true` publishes self-contained onto `runtime-deps` |
| `ACR_SERVICE_CONNECTION` | Azure DevOps | ACR push in `azure-pipelines.yml` |
| `ACR_USERNAME`, `ACR_PASSWORD` | secrets | ACR push from GitHub Actions without `az` |
| `CODECOV_TOKEN` | secret | PR coverage comments |
| `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | secrets | OIDC login for the `deploy` workflow |
| `APP_SERVICE_NAME`, `AZURE_RESOURCE_GROUP`, `AKS_CLUSTER` | vars | deploy targets |

Leaving the Artifactory variables unset makes every script fall back to
`ci/nuget/public.config` (nuget.org) — no branching in the pipeline definition.

## Deploy

CI pushes `ghcr.io/<owner>/orchardcore-cms:<ref>-<sha7>` and records the digest in
`.out/image-digest.txt`. The `cd` workflow writes that digest into
`helm/orchardcore/values.yaml` and commits; Argo CD (`argocd/application.yaml`) syncs the
chart. The render step fails the job if the chart is not digest-pinned, so a tag-only
deploy cannot slip through.

Rollback = revert the `chore(cd): pin ...` commit; Argo CD self-heals to the previous
digest.

For the non-GitOps targets, the `deploy` workflow takes a digest-pinned ref and runs either
`ci/deploy-appservice.sh` (Azure App Service for Containers — sets `WEBSITES_PORT=8080`,
restarts, polls the hostname) or `ci/deploy-aks.sh` (`helm upgrade --install --wait` plus
`kubectl rollout status`). Both refuse anything that is not `...@sha256:...`. Rollback there
is re-running the workflow with the previous digest, or `helm rollback cms`.

## Failure triage

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Unrecognized command or argument '--filter'` | VSTest flags under the MTP runner | move args after `--`, use `--filter-trait` |
| Coverage report empty | coverlet instrumented the wrong assemblies | check `--include "[OrchardCore*]*"` matches the build output |
| Restore hits nuget.org despite Artifactory vars | a step lost `--configfile`, or `dotnet publish -r` re-restored | see quirk 9 |
| Cache hit but restore still downloads | key missed `Directory.Packages.props` | see quirk 3 |
| CMS container starts then exits 139 | trimmed publish | `PublishTrimmed=false` |
| Black-box `Runs_as_non_root` fails | Dockerfile `USER` lost during a base image bump | keep UID 1654 |
| `sha mismatch` from bootstrap | tag was moved upstream | re-resolve the SHA, update `ci/upstream.env` |
| App Service deploy times out, container log empty | missing `WEBSITES_PORT` | see quirk 14 |
| Sonar shows coverage that does not match the artifact | auto-discovered stale report | keep the empty `sonar.cs.*.reportsPaths` overrides |
