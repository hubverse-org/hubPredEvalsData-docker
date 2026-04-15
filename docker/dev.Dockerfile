FROM hubpredevalsdata-base

LABEL org.opencontainers.image.description="Dev image for ephemeral testing and renv.lock updates"
LABEL org.opencontainers.image.licenses="MIT"

WORKDIR /project

COPY DESCRIPTION DESCRIPTION
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY scripts/ scripts/
