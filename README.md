# Docker container for hubPredEvalsData generation

This docker container is a wrapper around
`hubPredEvalsData::generate_evals_data()` and hosts the in-development code
from
[hubverse-org/hubPredEvalsData](https://github.com/hubverse-org/hubPredEvalsData),
which is used to generate tables of evaluation data from a hub's [oracle
output](https://hubverse.io/en/latest/user-guide/target-data.html#oracle-output).

The image is built and deployed to the GitHub Container Registry (https://ghcr.io).
You can find the [latest version of the
image](https://github.com/hubverse-org/hubPredEvalsData-docker/pkgs/container/hubpredevalsdata-docker/340871974?tag=main)
by using the `main` tag:

From the command line:

```sh
docker pull ghcr.io/hubverse-org/hubpredevalsdata-docker:main
```

## Usage

The main usage for this image is a step in [the hub dashboard control
room](https://github.com/hubverse-org/hub-dashboard-control-room) that builds
evals data if it exists.

The container packages the `create-predevals-data.R` script, which will display
help documentation if you pass `--help` to it.

```sh
docker run --rm -it \
ghcr.io/hubverse-org/hubpredevalsdata-docker:main \
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


