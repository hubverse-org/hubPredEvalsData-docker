# Pin to the R 4.5 minor tag: patch releases are ABI-stable, so this picks up
# fixes safely while minor/major R bumps stay deliberate (see #24).
FROM rocker/r-ver:4.5

LABEL org.opencontainers.image.description="A thin wrapper around hubPredEvalsData"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="Hubverse"
LABEL org.opencontainers.image.source="https://github.com/hubverse-org/hubPredEvalsData-docker"

ARG YQ_VERSION="v4.44.3"
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# install OS binaries required by R packages - via rocker-versioned2/scripts/install_tidyverse.sh
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    git \
    libxml2-dev \
    libcairo2-dev \
    libgit2-dev \
    default-libmysqlclient-dev \
    libpq-dev \
    libsasl2-dev \
    libsqlite3-dev \
    libssh2-1-dev \
    libxtst6 \
    libcurl4-openssl-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    unixodbc-dev \
    cmake \
    libnode-dev \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /project

ENV RENV_PATHS_LIBRARY=renv/library
COPY renv.lock renv.lock
RUN Rscript -e "install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))"

# Fail the build before restoring if renv.lock was resolved against a
# different R minor than this image: restore() only warns on a mismatch and
# would then pull p3m binaries built for the wrong R (#24).
RUN Rscript -e 'lk <- package_version(renv::lockfile_read("renv.lock")$R$Version); img <- getRversion(); if (lk[1, 1:2] != img[1, 1:2]) stop(sprintf("renv.lock R (%s) does not match image R (%s)", lk, img))'

RUN Rscript -e "renv::restore()"

# YQ is needed here because we need it inside of GitHub actions
RUN curl -ssL -o - https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz |\
  tar xz && mv yq_linux_amd64 /usr/bin/yq

COPY scripts/create-predevals-data.R /usr/local/bin
COPY scripts/test.R /usr/local/bin
COPY tests/testthat/test-predevals-output.R /usr/local/bin
RUN chmod u+x /usr/local/bin/create-predevals-data.R /usr/local/bin/test.R
