#!/usr/bin/env Rscript

renv::restore()
renv::settings$snapshot.type("explicit")
renv::update(packages = c("hubPredEvalsData", "scoringutils"))
renv::snapshot()
