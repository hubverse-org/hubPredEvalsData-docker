#!/usr/bin/env Rscript

options(
  repos = c(
    hubverse = "https://hubverse-org.r-universe.dev",
    getOption("repos")
  ),
  renv.config.install.remotes = FALSE
)
renv::install(lock = TRUE)
