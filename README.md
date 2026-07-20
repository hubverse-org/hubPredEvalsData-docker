# Docker container for hubPredEvalsData generation

This docker container wraps `hubPredEvalsData::generate_eval_data()` and
`hubPredEvalsData::generate_predevals_options()`, hosting the in-development
code from
[hubverse-org/hubPredEvalsData](https://github.com/hubverse-org/hubPredEvalsData),
which together generate the score tables and `predevals-options.json` the
evals dashboard reads from a hub's [oracle output](https://docs.hubverse.io/en/latest/user-guide/target-data.html#oracle-output).

The image is built and deployed to the GitHub Container Registry (https://ghcr.io).
It is published for the `linux/amd64` architecture only, since its job is to
generate dashboard data on amd64 CI. It still runs on Apple Silicon (arm64)
Macs under emulation; see [Running locally on Apple Silicon](#running-locally-on-apple-silicon-arm64).

You can find the [latest version of the
image](https://github.com/hubverse-org/hubPredEvalsData-docker/pkgs/container/hubpredevalsdata-docker/340871974?tag=latest)
by using the `latest` tag:

From the command line:

```sh
docker pull ghcr.io/hubverse-org/hubpredevalsdata-docker:latest
```

## Usage

This image is invoked in two contexts:

- **CI**: by the [hub-dashboard-control-room](https://github.com/hubverse-org/hub-dashboard-control-room)
  reusable workflow as part of the dashboard data pipeline. This is the
  primary production caller; every dashboard that consumes the control-room
  workflow picks up the `:latest` tag automatically on the next run. See the
  hubverse docs on [dashboard operational workflows](https://docs.hubverse.io/en/latest/developer/dashboard-workflows.html)
  for the full pipeline context.
- **Local**: directly via `docker run` for testing, debugging, or one-off
  generation against a local hub clone. See the [Example](#example) below
  and the hubverse docs on the [local dashboard workflow](https://docs.hubverse.io/en/latest/developer/dashboard-local.html).

### Running locally on Apple Silicon (arm64)

The published images are `linux/amd64` only (see above). To run them on an Apple
Silicon (arm64) Mac you need amd64 emulation enabled, otherwise `docker run` fails
with:

```
exec /usr/local/bin/create-predevals-data.R: exec format error
```

That error is the amd64 entrypoint failing to start on an arm64 host. Enable amd64
emulation in Docker Desktop (**Settings → General → "Use Rosetta for x86_64/amd64
emulation"**, or ensure QEMU emulation is otherwise available), and the amd64 image
runs transparently.

On arm64, `docker run` also prints a harmless `platform does not match host` warning;
add `--platform=linux/amd64` to silence it. When *building* the images
locally on arm64, `--platform linux/amd64` matters more: it pulls fast prebuilt
package binaries instead of compiling everything from source (see the note under
[Getting the images](#getting-the-images)). It also builds the same amd64 image the
dashboard eval pipeline uses, so it reproduces that build environment more accurately.

> [!NOTE]
> **Why no native arm64 image?** The image is scoped to generating dashboard data on
> amd64 CI, so it is published for amd64 only. A native arm64 image would have to
> compile every R package from source at build time (Posit Package Manager serves
> Linux binaries for amd64 only), which greatly increases build times, and it adds the
> ongoing cost of building, testing, and publishing a second architecture. Running the
> amd64 image under emulation already covers local arm64 use, so multi-arch is not
> currently worth that trade-off.

### Help

The container packages the `create-predevals-data.R` script, which will display
help documentation if you pass `--help` to it.

```sh
docker run --rm -it --platform=linux/amd64 \
ghcr.io/hubverse-org/hubpredevalsdata-docker:latest \
create-predevals-data.R --help
```

`--platform=linux/amd64` silences the platform-mismatch warning on Apple Silicon
(see [Running locally on Apple Silicon](#running-locally-on-apple-silicon-arm64)).

````
Calculate eval scores data and a predevals-config.json file

USAGE

   create-predevals-data.R [--help] -h </path/to/hub> -c <cfg> [-o <dir>] \
     [-d <oracle>] [--legacy-oracle-fallback <url>]

ARGUMENTS

  --help                          print help and exit
  -h </path/to/hub>               path to a local copy of the hub
  -c <cfg>                        path or URL of predevals config file
  -o <dir>                        output directory
  -d <oracle>                     [DEPRECATED] path or URL to a single
                                  oracle-output file. When supplied, used
                                  directly and a deprecation warning is
                                  printed. When absent, oracle output is
                                  auto-discovered from <hub>/target-data/
                                  via hubData (supports CSV, parquet, and
                                  partitioned parquet per hubverse spec).
  --legacy-oracle-fallback <url>  [TRANSITIONAL] URL to read oracle output
                                  from if hubData auto-discovery fails.
                                  Intended for the control-room workflow's
                                  deprecation window. Will be removed once
                                  dashboards are migrated.

EXAMPLE

```bash
prefix="https://raw.githubusercontent.com/hubverse-org/dashboard-test-hub-dashboard/refs/heads"
cfg="${prefix}/main/predevals-config.yml"
mkdir -p evals

tmp=$(mktemp -d)
git clone https://github.com/hubverse-org/dashboard-test-hub.git $tmp

create-predevals-data.R -h $tmp -c $cfg -o evals
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

# run the container (oracle is auto-discovered from /project/target-data/)
docker run --rm -it --platform=linux/amd64 -v "$(pwd)":"/project" \
ghcr.io/hubverse-org/hubpredevalsdata-docker:latest \
create-predevals-data.R -h /project -c $cfg -o /project/predevals/data
```

## Releasing the production image

This covers the production image only; the
[base and dev images](#base-and-dev-docker-images) publish automatically on
merge to `main`. Most releases are a `renv.lock` refresh plus a version bump
(see [Dependency management](#dependency-management)).

Merging does **not** publish the production image. Pushing the `v*` tag does
(step 5). Until then consumers stay on the previous release.

1. **Branch off `main` and refresh `renv.lock`** using one of the
   [Updating `renv.lock`](#updating-renvlock) patterns. Prefer an update *and
   verify* pattern over a bare update, so the new lockfile is known to produce
   a working pipeline before it reaches CI.

2. **Bump the version** with `usethis::use_version()`, which updates
   the version in `DESCRIPTION` and finalises the `NEWS.md` heading.

3. **Open the PR and request review.** `chain-build` runs on it, building base,
   dev and production in one runner and testing production against
   `dashboard-test-hub`.

4. **Merge to `main`** with a merge commit once approved and green.

5. **Cut a signed tag on `main`.** This is the step that publishes the image.

   ```bash
   git checkout main && git pull
   git tag -s v1.2.0 -m "<short summary of the release>"
   git push origin v1.2.0
   ```

   `publish-production.yaml` then builds production from the published base,
   runs the testthat suite once more, and pushes both the version tag and
   `:latest` to GHCR with build-provenance attestation. The workflow does not
   create the GitHub release, so publish that with
   `usethis::use_github_release()`, which drafts it from the `NEWS.md` section
   for this version and attaches it to the tag pushed above.

6. **Verify downstream.** Consumers pick up `:latest` on their next run, so
   trigger a dashboard build (for example the `dashboard-test-hub-dashboard`
   "Rebuild Data" run) and confirm it is green against the new image. This is
   the first point at which the release is exercised against a hub other than
   the `dashboard-test-hub` fixture.

7. **Open a post-release PR** setting the next development version with
   `usethis::use_dev_version()`.

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

- **`docker/base.Dockerfile`**: system dependencies + R + renv. No R packages
  installed. The shared foundation that the production image also builds on.
- **`docker/dev.Dockerfile`**: builds on the base image, adds project files
  (DESCRIPTION, .Rprofile, renv/activate.R, scripts). Still no R packages
  installed: they are installed at runtime so they always resolve fresh from
  r-universe/CRAN.

Both are published to GHCR on every push to `main` that changes the relevant
files, tagged with the R minor (`:4.5`). Pull by the explicit R-minor tag;
there is intentionally no `:latest`.

### Renv approach: production vs dev

The base image installs no R packages, so renv doesn't come into play there.
Production and dev, by contrast, each use renv but in deliberately different
ways:

**Production** uses renv only as a **build-time installer**. `renv::restore()`
runs during `docker build` and installs the renv.lock-pinned package versions
into R's default site library at `/usr/local/lib/R/site-library`. At runtime,
renv is explicitly **not activated**: the production Dockerfile sets
`ENV RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`, which tells the renv autoloader
to skip activation even if a `.Rprofile` is present in the container's working
directory. This matters because consumers run production as
`docker run -v <hub>:/project ...`, and if their hub happens to contain a
`.Rprofile` + `renv/activate.R`, the bind mount would otherwise expose those
files to the container, activate renv against an empty mounted `renv/library`,
and break package loading. With the autoloader disabled, `.libPaths()` stays
at R's defaults, the site library is searched, and packages are found
regardless of what the consumer mounts. The same safeguard also covers this
repo's own `chain-build` CI. Chain-build does `actions/checkout` of this repo
before `docker run -v $(pwd):/project`. That puts this repo's own `.Rprofile`
and `renv/` inside the container, which would otherwise trigger the same
package-loading break as a consumer hub with a `.Rprofile`. The previous CI
workflow didn't checkout-and-bind-mount in this way, so the issue only
surfaced once chain-build was introduced.

**Dev** uses renv the conventional way. `.Rprofile` and `renv/activate.R` are
copied into the image, the autoloader is enabled, renv activates at R startup,
and the project library lives at `/project/renv/library/...`. The whole point
of dev is to be bind-mounted with the user's project (`-v $(pwd):/project`),
so renv operating on the bind-mounted state is correct: `update.R` installs
to the user's `renv/library` and writes the refreshed lockfile back to their
`renv.lock` on the host. Dev users get full renv project semantics; production
consumers get a self-contained image with no runtime renv overhead.

In short:

- **Production**: renv as build-time installer only, system library used at runtime, no renv activation.
- **Dev**: full renv project, runtime-active, host-state-aware.

The R-version guard (see below) ensures production's `renv.lock` and image R
version stay coordinated regardless of which approach the image uses.

### Getting the images

Pull the published images:

```bash
docker pull ghcr.io/hubverse-org/hubpredevalsdata-base:4.5
docker pull ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5
```

Or build them locally:

```bash
# Build base (cached, rarely needs rebuilding)
docker build --platform linux/amd64 -f docker/base.Dockerfile \
  -t ghcr.io/hubverse-org/hubpredevalsdata-base:4.5 .

# Build dev image (FROMs the base image above)
docker build --platform linux/amd64 -f docker/dev.Dockerfile \
  -t ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5 .
```

> [!NOTE]
> Use `--platform linux/amd64` even on Apple Silicon Macs. This ensures
> pre-built CRAN binaries are available (the rocker base image uses Posit
> Package Manager which serves binaries for x86_64 Linux). Without it,
> all packages compile from source (~24 min vs ~2 min).

### Updating `renv.lock`

Three patterns, depending on what you want to do alongside the update:

| Goal | Pattern |
|---|---|
| Just refresh the lockfile, no verification. | [Just update (ephemeral)](#just-update-ephemeral) |
| Refresh the lockfile *and* confirm it produces a working pipeline. | [Update + verify (ephemeral, one-shot)](#update--verify-ephemeral-one-shot) |
| Update, verify, and keep iterating in the same container (e.g. trying a dev branch of an upstream package alongside the bump). | [Update + verify + explore (persistent)](#update--verify--explore-persistent) |

All three bind-mount your project at `/project` and write the new lockfile back
to your host, which is what you usually want when bumping `renv.lock`. If you
specifically want to smoke-test a dev package version *without* modifying your
`renv.lock`, see [Ephemeral dev testing](#ephemeral-dev-testing) below instead
(no project mount, lockfile stays in the container).

#### Just update (ephemeral)

Runs `update.R` and writes the refreshed lockfile back to your host. The
container's package cache is thrown away with the container.

```bash
docker run --rm --platform linux/amd64 \
  -v "$(pwd)":/project -w /project \
  ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5 Rscript scripts/update.R
```

If there are updates, the lockfile will change and you will need to commit it.
The PR's chain-build CI validates the new lockfile end-to-end; the production
image picks it up on the next release (`v*` tag).

#### Update + verify (ephemeral, one-shot)

Single `docker run --rm` that updates the lockfile, stages the canonical test
hub and dashboard config in a temporary workspace, runs the pipeline, and runs
testthat. The container disappears at the end; only the lockfile change
persists on host. Good for routine PRs where you want a quick sanity check
before committing.

```bash
docker run --rm --platform linux/amd64 \
  -v "$(pwd)":/project \
  -v "$(mktemp -d)":/work \
  -w /project \
  ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5 \
  bash -lc 'set -euo pipefail
    Rscript scripts/update.R
    git clone https://github.com/hubverse-org/dashboard-test-hub.git /work/dashboard-test-hub
    curl -sSL -o /work/predevals-config.yml \
      https://raw.githubusercontent.com/hubverse-org/dashboard-test-hub-dashboard/main/predevals-config.yml
    mkdir -p /work/out
    Rscript scripts/create-predevals-data.R \
      -h /work/dashboard-test-hub -c /work/predevals-config.yml -o /work/out
    PREDEVALS_OUT_DIR=/work/out Rscript -e \
      "testthat::test_file(\"tests/testthat/test-predevals-output.R\", stop_on_failure = TRUE)"
  '
```

The invocation is on the chunky side; an ergonomic improvement (a small
helper script that wraps the verify steps) is tracked in
[#38](https://github.com/hubverse-org/hubPredEvalsData-docker/issues/38).

#### Update + verify + explore (persistent)

Start a persistent container with your project mounted, run `update.R` inside
it (writes the lockfile back to host *and* populates the container's renv
cache in one step), then run as many pipeline/test commands as you want
against the same container. Good for exploratory work where one verification
pass isn't enough (e.g. iterating with a dev branch of an upstream package
alongside the lockfile bump).

```bash
# 1. Start the persistent container
docker run -d --platform linux/amd64 --name dev-test \
  -v "$(pwd)":/project \
  -v "$(mktemp -d)":/work \
  -w /project \
  ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5 sleep infinity

# 2. Update the lockfile (writes to host, populates container cache)
docker exec dev-test Rscript scripts/update.R

# 3. Stage test fixtures once
docker exec dev-test bash -lc '
  git clone https://github.com/hubverse-org/dashboard-test-hub.git /work/dashboard-test-hub
  curl -sSL -o /work/predevals-config.yml \
    https://raw.githubusercontent.com/hubverse-org/dashboard-test-hub-dashboard/main/predevals-config.yml
  mkdir -p /work/out
'

# 4. Run the pipeline + tests (repeat as often as you like)
docker exec dev-test bash -lc '
  Rscript scripts/create-predevals-data.R \
    -h /work/dashboard-test-hub -c /work/predevals-config.yml -o /work/out
  PREDEVALS_OUT_DIR=/work/out Rscript -e \
    "testthat::test_file(\"tests/testthat/test-predevals-output.R\", stop_on_failure = TRUE)"
'

# 5. Optionally layer a dev branch of an upstream package and re-run step 4
docker exec dev-test Rscript -e \
  'renv::install("hubverse-org/hubPredEvalsData@some-branch")'

# 6. Clean up when done
docker stop dev-test && docker rm dev-test
```

### Ephemeral dev testing

For smoke-testing dev versions of upstream packages (e.g. a `hubPredEvalsData`
branch or PR) *without* modifying your local `renv.lock`. The container is
mounted with no project directory, so any `renv::install(..., lock = TRUE)`
calls inside it only touch the container's lockfile, not your host's.

Packages are installed at runtime from r-universe/CRAN (~2 min), then dev
packages can be layered on. Nothing is written back to the host.

```bash
# Start a persistent dev container
docker run -d --platform linux/amd64 --name dev-test \
  ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5 sleep infinity

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
  ghcr.io/hubverse-org/hubpredevalsdata-dev:4.5 sleep infinity

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

## CI workflows

Three workflows in `.github/workflows/`, each scoped to one concern:

| Workflow | Fires on | What it does | What it validates / catches |
|---|---|---|---|
| `chain-build.yaml` | PR touching any file that affects an image | Builds base, dev, and production locally in one runner; runs testthat against the `dashboard-test-hub` fixture using the just-built production image. | The R-minor pin in `docker/base.Dockerfile` is coordinated with the `FROM` tags in `Dockerfile` and `docker/dev.Dockerfile`; the full chain builds end-to-end; production produces correct output for a real hub config. |
| `publish-base-dev.yaml` | Push to `main` when `docker/base.Dockerfile`, `docker/dev.Dockerfile`, or files dev embeds change | Builds and pushes `ghcr.io/hubverse-org/hubpredevalsdata-base:<R minor>` and `:<R minor>` for `dev` to GHCR. | n/a (publishing only; PR-time tests already ran via `chain-build` before merge). |
| `publish-production.yaml` | Push of a `v*` tag (or manual `workflow_dispatch` from main with `publish=true`) | Builds the production image from the published base, runs testthat one more time, then pushes the release tag and `:latest` to GHCR with build-provenance attestation. | Drift between the chain-build-tested state and the release-time environment (e.g. base has been republished since the PR merged). |

**Merge vs tag lifecycle.** `base` and `dev` publish on every relevant merge to `main`, so infrastructure changes (e.g. an R-minor bump) become available immediately for dev/testing. Production publishes only on `v*` tags, so the already-released production image at the last tag is untouched on merge and continues to serve consumers until you cut a new release tag, at which point the new production image picks up whatever `base` is current. Per-release changes are tracked in [`NEWS.md`](NEWS.md).

**R-version guard.** Production's `Dockerfile` has a `RUN` step before `renv::restore()` that fails the build if `renv.lock`'s recorded R minor doesn't match the image's running R. This complements the pin-coordination check in `chain-build`: the workflow check verifies the three Dockerfiles agree on a version (by inspecting their `FROM` strings); the guard verifies `renv.lock` was regenerated against that version (by inspecting the running R at build time).

**Tags and `:latest`.** Base and dev use explicit R-minor version tags only (`:4.5`); there is intentionally no floating `:latest` for them, consistent with how `rocker/r-ver:4.5` is itself a minor pin. Production is different: each `v*` release publishes both the version tag (e.g. `:v1.1.1`) and a `:latest` tag pointing at the same build. The `:latest` tag is generated automatically by `docker/metadata-action`'s default `latest=auto` flavor, so it advances on every release with no manual step. Production maintains `:latest` because the control-room workflow consumes the image by that tag.
