# Docker container for hubPredEvalsData generation

This docker container is a wrapper around
`hubPredEvalsData::generate_evals_data()` and hosts the in-development code
from
[hubverse-org/hubPredEvalsData](https://github.com/hubverse-org/hubPredEvalsData),
which is used to generate tables of evaluation data from a hub's [oracle
output](https://docs.hubverse.io/en/latest/user-guide/target-data.html#oracle-output).

The image is built and deployed to the GitHub Container Registry (https://ghcr.io).
You can find the [latest version of the
image](https://github.com/hubverse-org/hubPredEvalsData-docker/pkgs/container/hubpredevalsdata-docker/340871974?tag=latest)
by using the `latest` tag:

From the command line:

```sh
docker pull ghcr.io/hubverse-org/hubpredevalsdata-docker:latest
```

## Usage

The main usage for this image is a step in [the hub dashboard control
room](https://github.com/hubverse-org/hub-dashboard-control-room) that builds
evals data if it exists.

The container packages the `create-predevals-data.R` script, which will display
help documentation if you pass `--help` to it.

```sh
docker run --rm -it \
ghcr.io/hubverse-org/hubpredevalsdata-docker:latest \
create-predevals-data.R --help
```

````
Calculate eval scores data and a predevals-config.json file

USAGE

   create-predevals-data.R [--help] -h </path/to/hub> -c <cfg> -d <oracle> [-o <dir>]

ARGUMENTS

  --help             print help and exit
  -h </path/to/hub>  path to a local copy of the hub
  -c <cfg>           path or URL of predevals config file
  -d <oracle>        path or URL to oracle output data
  -o <dir>           output directory

EXAMPLE

```bash
prefix="https://raw.githubusercontent.com/elray1/flusight-dashboard/refs/heads"
cfg="${prefix}/main/predevals-config.yml"
oracle="${prefix}/oracle-data/oracle-output.csv"

tmp=$(mktemp -d)
git clone https://github.com/cdcepi/FluSight-forecast-hub.git $tmp

create-predevals-data.R -h $tmp -c $cfg -d $oracle
```
````

## Example

This is an example of running this container with the [reichlab/flu-metrocast hub](https://github.com/reichlab/flu-metrocast/tree/main).

```sh
# setup --------------------------------------------------------------
git clone https://github.com/reichlab/flu-metrocast.git flu-metrocast
cd flu-metrocast
mkdir -p predevals/data
cfg=https://raw.githubusercontent.com/reichlab/metrocast-dashboard/refs/heads/main/predevals-config.yml

# run the container
docker run --rm -it --platform=linux/amd64 -v "$(pwd)":"/project" \
ghcr.io/hubverse-org/hubpredevalsdata-docker:latest \
create-predevals-data.R -h /project -c $cfg -d /project/target-data/oracle-output.csv -o /project/predevals/data
```

## Dependency management

This project uses `renv` with the `explicit` snapshot type. Dependencies are
declared in the `DESCRIPTION` file, which ensures reproducible and predictable
lockfile generation. This approach:

- Captures only the packages actually needed (declared in `DESCRIPTION`)
- Avoids including unrelated packages from the base R image
- Is the standard R approach for dependency management

> [!NOTE]
> If you add a new dependency to any script in this project, you must also add
> it to the `DESCRIPTION` file's `Imports` field for it to be captured in the
> lockfile.

## Base and dev Docker images

Two additional Dockerfiles in `docker/` support local development and
`renv.lock` updates. They provide a container with an empty R package library,
which is required for resolving packages from r-universe instead of GitHub
(see [#16](https://github.com/hubverse-org/hubPredEvalsData-docker/issues/16)
for details).

- **`docker/base.Dockerfile`** — system dependencies + R + renv. No R
  packages installed. A reusable foundation intended to also back the
  production image in future (see
  [#19](https://github.com/hubverse-org/hubPredEvalsData-docker/issues/19)).
- **`docker/dev.Dockerfile`** — builds on the base image, adds project files
  (DESCRIPTION, .Rprofile, renv/activate.R, scripts). Still no R packages
  installed — they are installed at runtime so they always resolve fresh from
  r-universe/CRAN.

### Building the images

```bash
# Build base (cached, rarely needs rebuilding)
docker build --platform linux/amd64 -f docker/base.Dockerfile -t hubpredevalsdata-base .

# Build dev image
docker build --platform linux/amd64 -f docker/dev.Dockerfile -t hubpredevalsdata-dev .
```

> [!NOTE]
> Use `--platform linux/amd64` even on Apple Silicon Macs. This ensures
> pre-built CRAN binaries are available (the rocker base image uses Posit
> Package Manager which serves binaries for x86_64 Linux). Without it,
> all packages compile from source (~24 min vs ~2 min).

### Updating `renv.lock`

Mount the project directory into the dev container and run `update.R`. This
is the **only** workflow that modifies the host lockfile:

```bash
docker run --rm --platform linux/amd64 \
  -v "$(pwd)":/project -w /project \
  hubpredevalsdata-dev Rscript scripts/update.R
```

If there are updates, the lockfile will change and you will need to commit it.
Once you commit and push, the docker image will be rebuilt automatically.

<!-- TODO: document automated CI workflow for renv.lock updates (#18) -->

### Ephemeral dev testing

Use a named container for persistent testing sessions. Packages are installed
at runtime from r-universe/CRAN (~2 min), then dev packages can be layered on.
Nothing is written back to the host.

```bash
# Start a persistent dev container
docker run -d --platform linux/amd64 --name dev-test hubpredevalsdata-dev sleep infinity

# Install released packages from r-universe/CRAN (~2 min)
docker exec dev-test Rscript scripts/update.R
```

#### Installing dev package versions

Layer a dev version on top of the released packages.

From a GitHub branch or PR:

```bash
docker exec dev-test Rscript -e \
  'renv::install("hubverse-org/hubEvals@feature-branch", lock = TRUE)'

# Or from a GitHub PR (by number)
docker exec dev-test Rscript -e \
  'renv::install("hubverse-org/hubPredEvalsData#42", lock = TRUE)'
```

From a local checkout (mount it when starting the container):

```bash
# Start the container with a local package mounted
docker run -d --platform linux/amd64 --name dev-test \
  -v /path/to/local/hubEvals:/dev/hubEvals \
  hubpredevalsdata-dev sleep infinity

# Install released packages, then overlay the local dev version
docker exec dev-test Rscript scripts/update.R
docker exec dev-test Rscript -e 'renv::install("/dev/hubEvals", lock = TRUE)'
```

#### Running the pipeline and cleaning up

```bash
# Run the pipeline as many times as needed
docker exec dev-test Rscript scripts/create-predevals-data.R [args...]

# Clean up when done
docker stop dev-test && docker rm dev-test
```


