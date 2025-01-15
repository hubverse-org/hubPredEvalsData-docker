FROM ghcr.io/hubverse-org/test-docker-hubutils-dev:main AS base

WORKDIR /project

ENV RENV_PATHS_LIBRARY=renv/library
COPY renv.lock renv.lock
RUN Rscript -e "renv::restore()"
RUN apt-get update && apt-get install -y --no-install-recommends \
curl \
jq \
&& rm -rf /var/lib/apt/lists/*

COPY scripts/create-predeval-data.R /bin
