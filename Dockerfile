FROM ghcr.io/hubverse-org/test-docker-hubutils-dev:main AS base

WORKDIR /project

ENV RENV_PATHS_LIBRARY=renv/library
COPY renv.lock renv.lock
RUN Rscript -e "renv::restore()"

COPY scripts/create-predeval-data.R /bin
