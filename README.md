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

## Updating

Because hubPredEvalsData is constantly improving, this image needs to be
rebuilt with the updated version. This can be achieved by running the update
script:

```
./scripts/update.R
```

When the update is complete, if there are updates, then the lockfile will change
and you will need to commit it. Once you commit and push, the docker image will
be rebuilt.


