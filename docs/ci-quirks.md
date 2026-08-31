# .NET CI quirks found while wrapping OrchardCore

Everything below was forced by the real upstream tree (`OrchardCMS/OrchardCore@v3.0.1`,
SHA `b9c4b2f`), not by a toy app.

## 1. `dotnet test --filter` is dead here — the repo opted into Microsoft.Testing.Platform

Upstream `global.json`:

```json
"test": { "runner": "Microsoft.Testing.Platform" }
```

Every test project is `<OutputType>Exe</OutputType>` + `xunit.v3.mtp-v2`. Under MTP,
`dotnet test` is a thin launcher for the test executable, and the VSTest vocabulary
(`--filter`, `--logger trx`, `--collect "XPlat Code Coverage"`, `--results-directory`)
is rejected. The arguments have to cross the `--` boundary and use MTP names:

```bash
dotnet test <proj> -c Release -f net10.0 --no-build -- \
  --report-trx --report-trx-filename unit.trx --results-directory .out/tests/unit
```

Trait filtering becomes `--filter-trait`, `--filter-not-trait`, `--filter-namespace`.
Forcing the old runner (`-p:TestingPlatformDotnetTestSupport=false`) would mean editing
upstream properties, so the wrapper speaks MTP instead.

## 2. Coverlet's collector cannot be used — the console tool can

`coverlet.collector` is a **VSTest data collector**. It is not in
`Directory.Packages.props` and it would do nothing under MTP even if it were. Adding it
means patching upstream csproj files, which this lab forbids.

`ci/test-unit.sh` therefore drives `coverlet.console` (a local tool in
`.config/dotnet-tools.json`), which instruments assemblies on disk and runs the test
binary as its target — runner-agnostic:

```bash
dotnet coverlet OrchardCore.Tests.dll \
  --target dotnet --targetargs "OrchardCore.Tests.dll --report-trx ..." \
  --format cobertura --include "[OrchardCore*]*" --exclude "[*Tests*]*"
```

`--include` matters: instrumenting the whole 300-project graph roughly triples the test
stage. `dotnet-coverage collect` (also in the tool manifest) is the alternative when the
goal is Sonar-native coverage instead of Cobertura.

## 3. Cache key: hashing `**/*.csproj` is not enough under Central Package Management

Upstream uses CPM — csproj files carry `<PackageReference Include="X" />` with **no
version**. All versions live in `Directory.Packages.props`. A cache key built from
`hashFiles('**/*.csproj')` survives a dependency bump and hands you a stale, incomplete
package folder; restore then partially re-downloads and the "cache hit" is a lie.

`ci/cache-key.sh` hashes: the pinned upstream SHA + the active NuGet config + every
csproj + `Directory.Packages.props` + `global.json`. Because upstream is pinned, the SHA
alone is nearly sufficient — the file hashes are what catch a *local* change to feed
config or SDK band.

There is no `packages.lock.json` upstream, so `--locked-mode` is not available; the SHA
pin is the substitute for lockfile determinism.

## 4. `.slnx`, not `.sln`

`OrchardCore.slnx` is the XML solution format. It needs SDK ≥ 9.0.200 and it is silently
invisible to older `dotnet restore SolutionDir` heuristics — passing the file explicitly
is required. `global.json` pins `10.0.200` with `rollForward: latestMajor`, so
`actions/setup-dotnet@v4` with `10.0.x` is the floor.

## 5. Artifactory routing without touching upstream `NuGet.config`

Upstream ships its own `NuGet.config` with `<clear />` + nuget.org. NuGet resolves config
by walking up from the project directory, so upstream's file wins over anything placed at
the wrapper root. Editing it = patching upstream.

The wrapper passes `--configfile ci/nuget/artifactory.config` on every restore/publish
instead — an explicit config replaces the whole discovery chain. Credentials are `%ENV%`
placeholders, which NuGet expands at read time, so no token is ever written to disk:

```xml
<add key="artifactory" value="%ARTIFACTORY_URL%/api/nuget/v3/%ARTIFACTORY_NUGET_REPO%/index.json" protocolVersion="3" />
```

`ci/lib.sh` picks `artifactory.config` when `ARTIFACTORY_URL` is set and `public.config`
otherwise, so the same scripts run on a laptop and behind a locked-down enterprise proxy.

## 6. Self-contained publish changes the base image

`dotnet publish -r linux-x64 --self-contained true` embeds the runtime, so
`mcr.microsoft.com/dotnet/aspnet:10.0` is the *wrong* base — it ships a runtime the app no
longer uses (~120 MB of dead weight). The correct pair is
`runtime-deps:10.0`; `ci/image.sh` swaps the base off `SELF_CONTAINED`.

Two constraints for OrchardCore specifically:

- `PublishTrimmed` must stay **false**. Modules are discovered by scanning assemblies at
  runtime; the trimmer removes types nothing statically references and the CMS boots into
  an empty module list.
- `PublishSingleFile` breaks Razor/static asset resolution from module assemblies.

Default in `ci/gates.env` is framework-dependent (smaller layer sharing across builds);
set `SELF_CONTAINED=true` to take the other path.

## 7. `RunAnalyzers=false` is the difference between a 12-minute and a 25-minute build

Upstream turns on a large analyzer set plus `GenerateDocumentationFile`. Upstream's own
`Dockerfile` already passes `/p:RunAnalyzers=false`. The CI build does the same and lets
SonarCloud own static analysis — running both is paying twice for the same findings.

## 8. Splitting the test stages

- **unit** — `test/OrchardCore.Tests`, no containers, coverage measured here.
- **integration** — `test/OrchardCore.Tests.Integration` (S3/file-storage paths) needs a
  live backing service; it runs in its own job with Docker available.
- **black-box** — `it/OrchardCore.BlackBox.Tests`, this lab's own suite, driving
  Testcontainers against the *built image* rather than the compiled assemblies. It asserts
  image contract facts (non-root UID 1654, OCI revision label) that no upstream test can.

Upstream also has `CIFactAttribute`, which self-skips unless `CI` or `BUILD_BUILDID` is
set. The scripts export `CI=true` so those tests actually run locally through `make test`.

## 9. `dotnet publish` re-restores unless told not to

With `-r linux-x64`, publish computes a RID-specific graph and will restore again, hitting
nuget.org even after a warm cache — and in the Artifactory case, failing outright because
the default config is back in play. Framework-dependent publish uses `--no-restore` (the
solution restore already covered it); the self-contained path must restore and so gets
`--configfile` instead.

## 10. Coverage number is small on purpose

`COVERAGE_MIN_LINE=35` is not a quality target. Coverlet reports coverage over the whole
`[OrchardCore*]` surface while only the unit suite runs, so the absolute number is low and
the gate exists to catch a *drop*, not to certify the codebase. SonarCloud's own
new-code condition is where the real quality gate lives.

## 11. You cannot pass `-f net10.0` to the solution

`OrchardCore.SourceGenerators` targets `netstandard2.0` (it has to — Roslyn analyzers do).
A solution-level `dotnet build -f net10.0` sets `TargetFramework` as a global property for
every project in the graph and that one project fails with "not compatible". The TFM is
therefore only ever passed at the *project* level (`dotnet test`, `dotnet publish`), never
at the solution level.

## 12. .NET Aspire is the wrong tool for *this* upstream

The modern answer to "integration tests need a database" is Aspire: an AppHost project
declares Redis/SQL/Postgres resources and `DistributedApplicationTestingBuilder` boots the
whole graph inside one test host, so CI needs no compose file and no Testcontainers
lifetime management.

It does not apply here, for a reason worth writing down: Aspire is opt-in at the *solution*
level — it needs an `AppHost` project and `Aspire.Hosting.Testing` wired into the test
projects. OrchardCore has neither, and adding them is patching upstream. Aspire also
orchestrates *services the app under test talks to*; this lab's black-box suite tests the
**published image**, which Aspire has no notion of.

So: Testcontainers for both the upstream integration suite (which brings its own
S3/file-storage dependencies) and for `it/`, where the image itself is the container under
test and Postgres is a sidecar. On an Aspire-native repo the `it/` fixture would collapse to

```csharp
var app = await DistributedApplicationTestingBuilder.CreateAsync<Projects.AppHost>();
await app.StartAsync();
var client = app.CreateHttpClient("cms");
```

and the `integration` CI job would lose its Docker requirement entirely — but it would also
stop testing the artifact that actually ships.

## 13. Cobertura goes to two places, for two audiences

One `unit.cobertura.xml` feeds:

- **SonarCloud** via `sonar.cs.cobertura.reportsPaths` — the quality gate, which blocks the
  PR on *new-code* coverage rather than on the absolute number.
- **Codecov** via `codecov/codecov-action` — the inline PR comment and per-file diff view.

The other Sonar coverage properties (`opencover`, `vscoveragexml`, `coverageReportPaths`)
are explicitly set empty in `ci/sonar.sh`: leaving them unset lets the scanner auto-discover
stale reports from a previous run's `.sonarqube` folder and silently report the wrong number.

`ci/coverage-report.sh` writes the same numbers into `$GITHUB_STEP_SUMMARY`, so the gate
value is visible without opening either SaaS.

## 14. App Service containers need `WEBSITES_PORT`

`ci/deploy-appservice.sh` sets `WEBSITES_PORT=8080` alongside the image. Without it App
Service probes port 80, the container answers on 8080, and the deploy fails as a health
timeout with nothing useful in the container log. Deploys are digest-pinned
(`registry/name@sha256:...`) and `deploy.yml` refuses a tag-only ref outright — App Service
caches image tags aggressively, so `:latest` produces deploys that "succeed" while running
yesterday's build.
