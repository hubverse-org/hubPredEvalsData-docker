# Tests for the predevals output produced by the docker pipeline.
#
# Driven by scripts/test.R, which sets PREDEVALS_OUT_DIR before calling
# testthat::test_file() on this file. Asserts that the pipeline produces
# the expected output structure when run against
# hubverse-org/dashboard-test-hub + hubverse-org/dashboard-test-hub-dashboard.
#
# Changes to those fixtures may require updates to the expected_* lists below.
#
# Schema validation of the input config happens inside generate_eval_data()
# in create-predevals-data.R, so a misconfigured config fails the pipeline
# step before we reach this file; we do not re-validate it here. Anything
# tested by hubPredEvalsData / hubEvals / scoringutils (metric columns,
# types, value bounds) is intentionally not re-tested here either.

out_dir <- Sys.getenv("PREDEVALS_OUT_DIR")
if (!nzchar(out_dir)) {
  stop("PREDEVALS_OUT_DIR is not set; run via scripts/test.R", call. = FALSE)
}
opts_path <- file.path(out_dir, "predevals-options.json")
scores_root <- file.path(out_dir, "scores")

# ---- Fixture expectations -------------------------------------------------
# Pinned to (fixtures these expectations were derived from):
#   dashboard-test-hub           @ 0a00609 (main, 2026-05-19)
#   dashboard-test-hub-dashboard @ a5e5e30 (main, 2026-06-04)
# Update tests if a change in either repo alters the pipeline output shape.

# Metrics listed in predevals-options.json per target. For transformable
# metrics on targets that configure a `transform`, the transformed-scale
# columns (`<metric>__<label>`) appear alongside the natural-scale ones.
# For targets that also configure `relative_metrics`, `_scaled_relative_skill`
# entries are spliced in; on a transformed target those carry their own
# transformed-scale variants too.
expected_metrics_by_target <- list(
  "wk inc flu hosp" = c(
    "wis_scaled_relative_skill",
    "wis_scaled_relative_skill__log",
    "wis",
    "wis__log",
    "ae_median_scaled_relative_skill",
    "ae_median_scaled_relative_skill__log",
    "ae_median",
    "ae_median__log",
    "interval_coverage_50",
    "interval_coverage_95"
  ),
  "wk inc flu death" = c(
    "wis_scaled_relative_skill",
    "wis",
    "ae_median_scaled_relative_skill",
    "ae_median",
    "interval_coverage_50",
    "interval_coverage_95"
  ),
  "wk flu hosp rate category" = c(
    "log_score",
    "rps"
  )
)

# Per-target `transform` block expected in predevals-options.json. Only
# targets that configure a transform appear here; for all other targets
# the `transform` field must be absent (NULL after JSON round-trip).
expected_transform_by_target <- list(
  "wk inc flu hosp" = list(
    fun = "log_shift",
    label = "log",
    append = TRUE,
    description = "Natural logarithm after adding an offset to the values (offset = 1)."
  )
)

expected_targets <- names(expected_metrics_by_target)

# All targets currently share the same eval set and disaggregations. If that
# ever diverges, replace this with explicit per-target entries.
disagg_cols <- c("location", "reference_date", "horizon", "target_end_date")
expected_files <- do.call(c, lapply(expected_targets, function(t) {
  c(
    list(list(target = t, eval_set = "All rounds", by = NULL)),
    lapply(disagg_cols, function(b) {
      list(target = t, eval_set = "All rounds", by = b)
    })
  )
}))

# ---- predevals-options.json -----------------------------------------------

test_that("predevals-options.json is present", {
  expect_true(file.exists(opts_path), info = opts_path)
})

opts <- jsonlite::read_json(opts_path)

test_that("predevals-options.json contains expected targets", {
  expect_setequal(
    purrr::map_chr(opts$targets, "target_id"),
    expected_targets
  )
})

for (target_id in expected_targets) {
  test_that(sprintf("predevals-options.json metrics for '%s' match expected", target_id), {
    # Pick the entry in opts$targets whose target_id matches.
    target <- Filter(function(x) x$target_id == target_id, opts$targets)[[1]]
    expect_setequal(
      unlist(target$metrics),
      expected_metrics_by_target[[target_id]]
    )
  })
}

# ---- transform block in predevals-options.json ----------------------------

for (target_id in names(expected_transform_by_target)) {
  test_that(sprintf("predevals-options.json transform block for '%s' matches expected", target_id), {
    target <- Filter(function(x) x$target_id == target_id, opts$targets)[[1]]
    expected <- expected_transform_by_target[[target_id]]
    expect_equal(target$transform$fun, expected$fun)
    expect_equal(target$transform$label, expected$label)
    expect_equal(target$transform$append, expected$append)
    expect_equal(target$transform$description, expected$description)
  })
}

for (target_id in setdiff(expected_targets, names(expected_transform_by_target))) {
  test_that(sprintf("predevals-options.json has no transform block for '%s'", target_id), {
    target <- Filter(function(x) x$target_id == target_id, opts$targets)[[1]]
    expect_null(target$transform)
  })
}

# ---- scores.csv files -----------------------------------------------------

for (fx in expected_files) {
  rel_path <- file.path(fx$target, fx$eval_set)
  if (!is.null(fx$by)) rel_path <- file.path(rel_path, fx$by)
  rel_path <- file.path(rel_path, "scores.csv")
  full_path <- file.path(scores_root, rel_path)

  test_that(sprintf("[%s] exists", rel_path), {
    expect_true(file.exists(full_path), info = full_path)
  })
  if (!file.exists(full_path)) next

  test_that(sprintf("[%s] is non-empty with expected columns", rel_path), {
    df <- readr::read_csv(full_path, show_col_types = FALSE, progress = FALSE)
    expect_gt(nrow(df), 0L)
    by_col <- if (!is.null(fx$by)) fx$by else character(0)
    expected_cols <- c(
      "model_id",
      by_col,
      expected_metrics_by_target[[fx$target]],
      "n"
    )
    expect_setequal(names(df), expected_cols)
  })
}
