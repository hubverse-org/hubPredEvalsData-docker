#!/usr/bin/env Rscript

renv::restore()
renv::update(packages = c("hubPredEvalsData", "scoringutils"))
renv::snapshot()
