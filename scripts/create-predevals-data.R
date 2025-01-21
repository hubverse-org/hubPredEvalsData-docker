#!/usr/bin/env Rscript
# DOC
#
# Calculate eval scores data and a predevals-config.json file
#
# USAGE
#
#    create-predevals-data.R [--help] -h </path/to/hub> -c <cfg> -d <oracle> [-o <dir>]
#
# ARGUMENTS
# 
#   --help             print help and exit
#   -h </path/to/hub>  path to a local copy of the hub
#   -c <cfg>           path or URL of predevals config file
#   -d <oracle>        path or URL to oracle output data
#   -o <dir>           output directory
# 
# EXAMPLE
#
# ```
# prefix="https://raw.githubusercontent.com/elray1/flusight-dashboard/refs/heads"
# cfg="${prefix}/main/predevals-config.yml"
# oracle="${prefix}/oracle-data/oracle-output.csv"
#
# tmp=$(mktemp -d)
# git clone https://github.com/cdcepi/FluSight-forecast-hub.git $tmp
#
# create-predevals-data.R -h $tmp -c $cfg -d $oracle
# ```
# DOC

args <- commandArgs()
print_help <- function(script) {
  lines <- readLines(script)
  bookends <- which(lines == "# DOC")
  writeLines(sub("# ?", "", lines[(bookends[1] + 1):(bookends[2] - 1)], perl = TRUE))
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
oracle_output <- readr::read_csv(parse_args(args, "-d"))
output_dir <- parse_args(args, "-o")
if (is.na(output_dir)) {
  output_dir <- getwd()
}

out_path <- fs::path(output_dir, "scores")
out_cfg <- fs::path(output_dir, "predevals-options.json")
if (!dir.exists(out_path)) {
  dir.create(out_path)
}

hubPredEvalsData::generate_eval_data(hub_path, predevals_config_path, out_path, oracle_output)

# create json objects used for initializing the dashboard
# config <- hubPredEvalsData:::read_config(hub_path, predevals_config_path)
config <- yaml::read_yaml(predevals_config_path)

# update config with additional options
# TODO: move this into a function in hubPredEvalsData
predevals_options <- config
predevals_options$targets <- purrr::map(
  predevals_options$targets,
  function(target) {
    if (length(target$relative_metrics) > 0) {
      target$metrics <- purrr::map(
        target$metrics,
        function(metric) {
          if (metric %in% target$relative_metrics) {
            return(c(paste0(metric, "_scaled_relative_skill"), metric))
          } else {
            return(metric)
          }
        }
      ) |> unlist()
      return(target)
    }
  }
)
jsonlite::write_json(predevals_options, out_cfg, auto_unbox = TRUE)
