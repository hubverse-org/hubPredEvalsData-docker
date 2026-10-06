#!/usr/bin/env Rscript
# Refresh renv.lock to the current release of every package.
#
# The rocker base image sets `CRAN` to the Posit Package Manager snapshot
# dated the day its R patch release was built, and that date moves only
# when rocker publishes a new image. A refresh resolved through it would
# update the hubverse packages, which r-universe serves current, while
# every CRAN dependency stayed frozen at that date. Moving the snapshot
# date to today refreshes all packages together.
snapshot_date <- "[0-9]{4}-[0-9]{2}-[0-9]{2}$"
cran <- Sys.getenv("CRAN")
stopifnot("CRAN is not a dated P3M snapshot URL" = grepl(snapshot_date, cran))
cran <- sub(snapshot_date, format(Sys.Date()), cran)

options(
  repos = c(
    hubverse = "https://hubverse-org.r-universe.dev",
    CRAN = cran
  ),
  renv.config.install.remotes = FALSE
)
renv::install(lock = TRUE)

# `renv::install(lock = TRUE)` replaces the package records in renv.lock
# but keeps the repositories already recorded there. Production's
# `renv::restore()` installs from the recorded repositories, so the lock
# must name the snapshot the packages were resolved from.
lockfile <- renv::lockfile_read("renv.lock")
lockfile <- renv::lockfile_modify(lockfile, repos = getOption("repos"))
invisible(renv::lockfile_write(lockfile, "renv.lock"))
