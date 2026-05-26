FROM ghcr.io/hubverse-org/hubpredevalsdata-base:4.5

LABEL org.opencontainers.image.description="A thin wrapper around hubPredEvalsData"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="Hubverse"
LABEL org.opencontainers.image.source="https://github.com/hubverse-org/hubPredEvalsData-docker"

ARG YQ_VERSION="v4.44.3"

# Disable renv autoloader at runtime: production uses the system library, not
# a renv project library. renv is called only at build time, by `renv::restore()`
# below, to install pinned package versions into `/usr/local/lib/R/site-library`.
# Without this, a consumer's `-v <hub>:/project` could expose their `.Rprofile`
# to the container and activate renv against an empty mounted renv/library.
# See README "Renv approach: production vs dev" for the full design note.
ENV RENV_CONFIG_AUTOLOADER_ENABLED=FALSE

WORKDIR /project

COPY renv.lock renv.lock

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

# (trailing newline added to force a chain-build trigger; remove if it works)
