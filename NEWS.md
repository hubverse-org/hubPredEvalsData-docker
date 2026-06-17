# hubPredEvalsData-docker 1.1.0

## Orchestrator script

* `scripts/create-predevals-data.R` now discovers oracle-output target data
  from the hub via `hubData::connect_target_oracle_output(hub_path)` by
  default, supporting CSV, parquet, and partitioned parquet layouts per
  the hubverse target-data spec. The `-d <oracle>` argument is retained as
  a deprecated back-compatibility option (single file path only) and emits
  a loud stderr warning when used; it will be removed in a future major
  release. Added a `--legacy-oracle-fallback <url>` flag used as a fallback
  when hubData discovery fails, intended for the control-room workflow's
  deprecation window (#6, see also
  hubverse-org/hub-dashboard-control-room#108).
* Replaced the inline `predevals-options.json` assembly block with a single
  call to `hubPredEvalsData::generate_predevals_options(hub_path, config_path)`.
  The script is now an orchestrator: parse args, resolve oracle, call
  `generate_eval_data()`, call `generate_predevals_options()`, write JSON.
  Requires hubPredEvalsData >= 1.1.0 (#22).

## Production image

* Production Dockerfile now builds on the shared base image. Apt/locale/renv
  layers live only in `docker/base.Dockerfile`; production and dev inherit
  them via `FROM ghcr.io/hubverse-org/hubpredevalsdata-base:<R minor>` (#19).
* Disabled the renv autoloader at runtime in the production image via
  `ENV RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`. Production uses the system
  library; renv is called only as a build-time installer. This makes the
  image robust to a consumer bind-mounting a hub directory that contains
  `.Rprofile` + `renv/activate.R`. See README "Renv approach: production vs
  dev" for the full design note.
* Pinned the rocker base to the R 4.5 minor tag (`rocker/r-ver:4.5`) and added
  a build-time guard that fails the build if `renv.lock`'s recorded R minor
  doesn't match the image's running R (#29).
* Refreshed `renv.lock` to use released package versions from r-universe/CRAN
  rather than GitHub sources; `renv::restore()` no longer needs `GITHUB_PAT`
  (#29).

## Base and dev images

* Added `docker/base.Dockerfile` (system deps + R + renv, no R packages) and
  `docker/dev.Dockerfile` (base + project files for ephemeral dev testing
  and `renv.lock` updates) (#21).
* Added `scripts/update.R` for regenerating `renv.lock` against released
  r-universe/CRAN versions inside the dev image (#21).
* Base and dev images are now published to GHCR on every relevant push to
  `main`, tagged with the R minor (e.g. `:4.5`). No `:latest`, by design (#18).

## CI workflows

* Restructured CI into three workflows, each scoped to one concern:
  `chain-build.yaml` (PR integration test, with R-minor pin consistency check
  across the three Dockerfiles), `publish-base-dev.yaml` (push to `main`,
  publishes base + dev to GHCR), and `publish-production.yaml` (`v*` tag,
  renamed from `build-container.yaml`, builds production from the published
  base then tests + pushes with build-provenance attestation) (#18, #19).
* Replaced the diff-against-`:latest` CI test with a testthat suite that
  exercises the produced predevals output against a known-good fixture (#28).
* Narrowed CI `pull_request` triggers to production-relevant paths to avoid
  unnecessary rebuilds (#26).
* Bumped pinned versions of `docker/*` and `actions/*` GitHub Actions within
  their current majors. Cross-major bumps tracked separately in #30.
* `chain-build.yaml` and `publish-production.yaml` invoke
  `create-predevals-data.R` without `-d`, exercising the new hubData-discovery
  default introduced in this release (see Orchestrator script section above).

## Documentation and release infrastructure

* Added a CI workflows section to the README explaining each workflow, what
  it validates, and the merge-vs-tag publish lifecycle.
* Introduced `NEWS.md` (this file) for release notes going forward.
