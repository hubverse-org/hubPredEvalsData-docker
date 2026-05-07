FROM rocker/r-ver:4

LABEL org.opencontainers.image.description="Base R image with system deps and renv for hubverse dashboard"
LABEL org.opencontainers.image.licenses="MIT"

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

ENV RENV_PATHS_LIBRARY=renv/library
RUN Rscript -e "install.packages('renv')"
