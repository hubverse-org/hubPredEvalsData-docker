FROM ghcr.io/hubverse-org/test-docker-hubutils-dev:main AS base
ARG YQ_VERSION="v4.44.3"
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

WORKDIR /project

ENV RENV_PATHS_LIBRARY=renv/library
COPY renv.lock renv.lock
RUN Rscript -e "renv::restore()"
RUN apt-get update && apt-get install -y --no-install-recommends \
curl \
jq \
&& rm -rf /var/lib/apt/lists/*

RUN curl -ssL -o - https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz |\
  tar xz && mv yq_linux_amd64 /usr/bin/yq

COPY scripts/create-predevals-data.R /usr/local/bin
RUN chmod u+x /usr/local/bin/create-predevals-data.R
