#!/usr/bin/env Rscript
# Run the predevals-output tests via testthat.
#
# Thin wrapper around testthat::test_file(), same pattern as r-lib/actions's
# check-r-package step. The actual assertions live in
# tests/testthat/test-predevals-output.R.
#
# USAGE
#   test.R -o <output_dir>
#
# ARGUMENTS
#   -o <output_dir>   directory containing predevals-options.json and scores/

suppressPackageStartupMessages(library(testthat))

args <- commandArgs(TRUE)
parse_args <- function(args, flag) {
  i <- which(args == flag)
  if (length(i) == 0L) NA_character_ else args[i + 1L]
}

out_dir <- parse_args(args, "-o")
if (is.na(out_dir)) stop("missing required -o <output_dir>", call. = FALSE)

# Pass the output dir to the test file via env var. testthat::test_file()
# runs in its own environment so this is the simplest cross-scope handoff.
Sys.setenv(PREDEVALS_OUT_DIR = out_dir)

# stop_on_failure = TRUE makes test_file() throw if any test failed, which
# exits the script non-zero. Same exit-code behaviour as `Rscript -e
# 'testthat::test_dir(...)'` in a standard R package CI.
testthat::test_file(
  "/usr/local/bin/test-predevals-output.R",
  stop_on_failure = TRUE
)
