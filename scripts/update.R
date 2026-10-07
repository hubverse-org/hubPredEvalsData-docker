#!/usr/bin/env Rscript
# Refresh renv.lock to the current release of every package.
#
# The rocker base image sets `CRAN` to a dated Posit Package Manager
# snapshot that does not advance between image builds. Resolving through
# it would leave every CRAN dependency at that date while r-universe
# serves the hubverse packages current, so the date is replaced. The
# README section "Dependency management" gives the full reasoning.
cran <- Sys.getenv("CRAN")
stopifnot("CRAN is not set; run update.R in the dev image" = nzchar(cran))
# Yesterday's snapshot, not today's: today's can still change while P3M
# syncs CRAN during the day, and `renv::restore()` in the production
# build must find the same versions later.
cran <- sub("[^/]+$", format(Sys.Date() - 1), cran)
stopifnot(
  "CRAN URL does not end in a snapshot date" =
    grepl("/\\d{4}-\\d{2}-\\d{2}$", cran)
)

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
