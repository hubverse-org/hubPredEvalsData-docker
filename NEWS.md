# hubPredEvalsData-docker (development version)

# hubPredEvalsData-docker 1.2.0

## Dependencies

Refreshed `renv.lock` to pull the latest releases of the hubverse packages the
image wraps: hubPredEvalsData 1.1.1 -> 1.2.0, hubEvals 0.2.0 -> 0.3.1,
hubUtils 1.2.0 -> 1.2.1, and hubData 2.2.1 -> 2.2.2 (#47).

The user-visible changes these bring to the generated dashboard data:

* `predevals-options.json` targets now carry `target_name` and `target_units`,
  read from the hub's tasks config. The dashboard uses `target_name` to label
  target menu items (hubverse-org/hubPredEvalsData#21).
* `scores.csv` rows are now sorted on the `(model_id, by)` key before writing,
  so the file is byte-stable across runs. Output can be diffed or
  md5-compared to confirm a no-change situation
  (hubverse-org/hubPredEvalsData#25).
* Models scored only on a later output type are no longer silently dropped
  from `scores.csv`. The per-output-type score frames are now merged with a
  full join rather than a left join anchored on the first output type, so
  which models survived no longer depends on the order metrics happen to be
  listed in the config (hubverse-org/hubPredEvalsData#75).
* Relative-skill scoring no longer aborts the run on single-model input, or
  on disaggregated comparison groups that cannot be compared. Such groups are
  reported as relative skill `1` or `NA` with a warning, and their absolute
  scores are returned unchanged (hubverse-org/hubEvals#75,
  hubverse-org/hubEvals#135).
* Scoring on transformed scales with `transform_append` now returns one row
  per scale instead of silently averaging across scales
  (hubverse-org/hubEvals#122).
* Oracle output is now read correctly from cloud (S3) hubs whose `admin.json`
  declares a non-parquet submission format such as `csv`. The cloud sync always
  writes `model-output/` to parquet on S3 regardless of the declared format, so
  such hubs previously came back as an empty connection
  (hubverse-org/hubData#148).

# hubPredEvalsData-docker 1.1.1

## Dependencies

* Updated `renv.lock` to pull hubPredEvalsData 1.1.1, which fixes a pipeline
  failure on hubs whose oracle output carries a versioned `as_of` column (for
  example FluSight). Such hubs previously aborted during scoring (#42, fix in
  hubverse-org/hubPredEvalsData#70).

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
