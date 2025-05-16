#!/usr/bin/env Rscript
args <- commandArgs(TRUE)

load_data <- function(dir) {
  fs::dir_ls(dir, recurse = TRUE, glob = "*csv") |>
    purrr::map(readr::read_csv, show_col_types = FALSE, progress = FALSE)
}
expect_df_equal_up_to_order <- function(df_act, df_exp, ignore_attr = FALSE, ...) {
  cols <- colnames(df_act)
  all.equal(
    dplyr::arrange(df_act, dplyr::across(dplyr::all_of(cols))),
    dplyr::arrange(df_exp, dplyr::across(dplyr::all_of(cols))),
    ignore.attr = ignore_attr,
    ...
  ) |> isTRUE()
}

latest <- load_data(args[1])
new    <- load_data(args[2])

results <- purrr::map2_lgl(latest, new, expect_df_equal_up_to_order)

if (!all(results)) {
  cat("These are not identical\n")
  cat(sprintf("\n- %s", names(results[!results])))
  stop("\nSome results failed")
}

cat("All identical\n")


