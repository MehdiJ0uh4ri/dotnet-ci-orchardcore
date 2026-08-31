# Decisions and rejected alternatives

**Upstream: OrchardCore, not eShop / eShopOnWeb.** eShop is Aspire-orchestrated, so its CI
is `dotnet run --project AppHost` and the interesting parts get hidden behind Aspire.
eShopOnWeb is archived and small enough that caching and analyzer cost never bite.
OrchardCore is a real ASP.NET Core 10 application, ~300 projects, CPM, `.slnx`, and the
MTP runner — every quirk in `ci-quirks.md` came from it for free.

**Wrapper, not fork.** The only coupling to upstream is `ci/upstream.env`. Nothing under
`upstream/` is ever edited; `bootstrap.sh` runs `git clean -xfdq` and asserts the SHA, so
an accidental local edit fails the build instead of silently shipping.

**Coverlet console over the collector.** The collector is VSTest-only and would need a
`PackageReference` added to upstream test projects. Rejected. `dotnet-coverage` stays in
the tool manifest as the Sonar-native option.

**SonarCloud in its own job, not gating `package`.** Analysis needs a full rebuild under
the scanner (~2× build time). Running it in parallel with packaging keeps PR feedback
under the timeout; the branch protection rule, not job ordering, is what blocks merge on a
failed gate.

**Trivy blocks, OWASP dependency-check warns.** Trivy's image scan is fast and its
findings are actionable (base image bump). Dependency-check's NuGet analyzer produces
enough false positives on a 300-project graph — and its NVD feed download is flaky enough
— that `continue-on-error: true` plus a suppression file is the honest configuration.

**Framework-dependent by default.** Self-contained is implemented and switchable, but the
default layer-shares `aspnet:10.0` across every build in the registry. Self-contained is
the right call only when the target host cannot be trusted to carry a runtime.

**Digest-pinned GitOps, no `latest`.** The `cd` job writes `image.digest` and the render
step greps for `@sha256:`. A tag can be re-pointed; a digest cannot, so what Argo CD syncs
is exactly what the black-box suite tested.

**Azure Pipelines kept as a mirror, not the primary.** `azure-pipelines.yml` exists to
show the `Cache@2` restore-key semantics (exact-key-only hits, prefix `restoreKeys`) which
differ from `actions/cache`. Both drive the identical `ci/*.sh` scripts — the YAML is
scheduling, never logic.
