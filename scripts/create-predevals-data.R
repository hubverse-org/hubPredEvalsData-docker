#!/usr/bin/env Rscript
# DOC
#
# Calculate eval scores data and a predevals-config.json file
#
# USAGE
#
#    create-predevals-data.R [--help] -h </path/to/hub> -c <cfg> [-o <dir>] \
#      [-d <oracle>] [--legacy-oracle-fallback <url>]
#
# ARGUMENTS
#
#   --help                          print help and exit
#   -h </path/to/hub>               path to a local copy of the hub
#   -c <cfg>                        path or URL of predevals config file
#   -o <dir>                        output directory
#   -d <oracle>                     [DEPRECATED] path or URL to a single
#                                   oracle-output file. When supplied, used
#                                   directly and a deprecation warning is
#                                   printed. When absent, oracle output is
#                                   auto-discovered from <hub>/target-data/
#                                   via hubData (supports CSV, parquet, and
#                                   partitioned parquet per hubverse spec).
#   --legacy-oracle-fallback <url>  [TRANSITIONAL] URL to read oracle output
#                                   from if hubData auto-discovery fails.
#                                   Intended for the control-room workflow's
#                                   deprecation window. Will be removed once
#                                   dashboards are migrated.
#
# EXAMPLE
#
# ```
# prefix="https://raw.githubusercontent.com/hubverse-org/dashboard-test-hub-dashboard/refs/heads"
# cfg="${prefix}/main/predevals-config.yml"
# mkdir -p evals
#
# tmp=$(mktemp -d)
# git clone https://github.com/hubverse-org/dashboard-test-hub.git $tmp
#
# create-predevals-data.R -h $tmp -c $cfg -o evals
# ```
# DOC

args <- commandArgs()
print_help <- function(script) {
  lines <- readLines(script)
  bookends <- which(lines == "# DOC")
  writeLines(sub(
    "# ?",
    "",
    lines[(bookends[1] + 1):(bookends[2] - 1)],
    perl = TRUE
  ))
  quit(save = "no", status = 0)
}

ci_cat <- function(...) {
  not_ci <- isFALSE(as.logical(Sys.getenv("CI", "false")))
  if (not_ci) {
    return(invisible(NULL))
  }
  cat(...)
}
parse_args <- function(args, flag) {
  if (any(args == "--help")) {
    script <- sub("--file=", "", args[startsWith(args, "--file")], fixed = TRUE)
    print_help(script)
  }
  args[which(args == flag) + 1]
}

hub_path <- parse_args(args, "-h")
predevals_config_path <- parse_args(args, "-c")
oracle_path <- parse_args(args, "-d")
legacy_oracle_fallback <- parse_args(args, "--legacy-oracle-fallback")
output_dir <- parse_args(args, "-o")
if (is.na(output_dir)) {
  output_dir <- getwd()
}

out_path <- fs::path(output_dir, "scores")
out_cfg <- fs::path(output_dir, "predevals-options.json")
if (!dir.exists(out_path)) {
  dir.create(out_path)
}

# Resolves oracle output via three paths, in priority order:
#   1. -d <oracle>: explicit single-file path (deprecated, #35).
#   2. hubData::connect_target_oracle_output(hub_path): default discovery.
#   3. --legacy-oracle-fallback <url>: fallback when (2) fails (deprecated, #34).
# When both deprecated options are removed (#34, #35), this function
# disappears entirely: the orchestrator stops loading oracle output at all
# and calls `generate_eval_data(hub_path, config_path, out_path)` without an
# `oracle_output` argument, letting the package handle discovery internally
# via `hubData::connect_target_oracle_output()`.
resolve_oracle_output <- function(hub_path, oracle_path, legacy_fallback) {
  if (length(oracle_path) > 0 && !is.na(oracle_path)) {
    cat(
      "WARNING: -d <oracle> is deprecated and will be removed in a future ",
      "major release.\n",
      "  Oracle output is now auto-discovered from <hub>/target-data/ via\n",
      "  hubData::connect_target_oracle_output(), which supports CSV, ",
      "parquet,\n",
      "  and partitioned parquet per the hubverse spec. Drop -d to use it.\n",
      sep = "",
      file = stderr()
    )
    return(readr::read_csv(oracle_path))
  }
  discovery <- tryCatch(
    hubData::connect_target_oracle_output(hub_path) |> dplyr::collect(),
    error = function(e) e
  )
  if (!inherits(discovery, "error")) {
    return(discovery)
  }
  if (length(legacy_fallback) > 0 && !is.na(legacy_fallback)) {
    cat(
      "WARNING: hubData oracle discovery failed for hub_path=",
      hub_path,
      "\n",
      "  Falling back to --legacy-oracle-fallback=",
      legacy_fallback,
      "\n",
      "  Discovery error: ",
      conditionMessage(discovery),
      "\n",
      "  This is a transitional fallback. The hub should publish oracle ",
      "output per\n",
      "  https://docs.hubverse.io/en/latest/user-guide/target-data.html\n",
      sep = "",
      file = stderr()
    )
    return(readr::read_csv(legacy_fallback))
  }
  # No -d, no fallback URL, and the hub publishes no recognised oracle output.
  stop(
    "Oracle output discovery failed for hub_path=",
    hub_path,
    ": ",
    conditionMessage(discovery)
  )
}

oracle_output <- resolve_oracle_output(
  hub_path,
  oracle_path,
  legacy_oracle_fallback
)

# TODO(#35): drop `oracle_output` from this call (and delete
# resolve_oracle_output()) once `-d` is removed; `generate_eval_data()`
# discovers oracle internally via hubData.
hubPredEvalsData::generate_eval_data(
  hub_path,
  predevals_config_path,
  out_path,
  oracle_output
)

predevals_options <- hubPredEvalsData::generate_predevals_options(
  hub_path,
  predevals_config_path
)
jsonlite::write_json(predevals_options, out_cfg, auto_unbox = TRUE)
