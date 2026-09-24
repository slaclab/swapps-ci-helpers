# swapps-ci-helpers

Shared, reusable GitHub Actions workflows for SWAPPS Python and JS/TS
projects. Instead of copy-pasting the same test/lint/docs workflow into every
repo (and then forgetting to update them all when a pin or a step changes),
consumer repos call into the workflows defined here.

## Usage

Pin `@<SHA>` to a specific commit in this repo — never a mutable branch or
tag — so a consumer only picks up changes when it deliberately bumps the pin.

### Tests (`python-test.yml`)

```yaml
name: Test

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  test:
    uses: slaclab/swapps-ci-helpers/.github/workflows/python-test.yml@<SHA>
    with:
      python-version: "3.12"
      test-path: "tests/"
```

Inputs:

| Name | Default | Description |
| --- | --- | --- |
| `python-version` | `"3.12"` | Python version to run tests against |
| `os-matrix` | `'["ubuntu-latest", "windows-latest", "macos-latest"]'` | JSON array string of runner OSes |
| `test-path` | `"tests/"` | Path passed to `pytest` |

### JS/TS Tests (`js-test.yml`)

```yaml
name: Test

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  test:
    uses: slaclab/swapps-ci-helpers/.github/workflows/js-test.yml@<SHA>
    with:
      node-version: "22"
      test-command: "pnpm test"
```

Inputs:

| Name | Default | Description |
| --- | --- | --- |
| `node-version` | `"22"` | Node.js version to run tests against |
| `test-command` | `"pnpm test"` | Command used to run the test suite |

### Pre-commit (`python-pre-commit.yml`)

Python-only: runs `uvx pre-commit run --all-files` against the calling
repo's own `.pre-commit-config.yaml` (ruff/isort/mypy, etc). JS/TS repos use
`js-check.yml` instead (below) — pre-commit's isolated hook environments
don't add value there, since flat `eslint.config.js` files and `tsc` both
need to resolve against the project's own `node_modules` anyway, and
running `language: system` hooks through pre-commit was just adding
indirection around commands `pnpm` already runs natively.

```yaml
name: Pre-commit

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  pre-commit:
    uses: slaclab/swapps-ci-helpers/.github/workflows/python-pre-commit.yml@<SHA>
```

No inputs.

### JS/TS Check (`js-check.yml`)

Runs lint/format/type checks with pnpm, mirroring `js-test.yml`'s setup.
For local enforcement, add [husky](https://typicode.github.io/husky/) +
[lint-staged](https://github.com/lint-staged/lint-staged) to the repo
instead of a `.pre-commit-config.yaml` — everything JS/TS-related then runs
in the same pnpm environment, no extra tooling required.

```yaml
name: Check

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  check:
    uses: slaclab/swapps-ci-helpers/.github/workflows/js-check.yml@<SHA>
    with:
      node-version: "22"
      check-command: "pnpm lint && pnpm format:check && pnpm exec tsc -b"
```

Inputs:

| Name | Default | Description |
| --- | --- | --- |
| `node-version` | `"22"` | Node.js version to run checks against |
| `check-command` | `"pnpm lint && pnpm format:check && pnpm exec tsc -b"` | Command used to run lint/format/type checks |

### Docs (`docs.yml`)

Shared between Python and JS/TS repos — both build with `zensical`, so this
workflow isn't Python-specific. Build and deploy are separate jobs: `build`
runs on every push/PR so you get build-failure feedback without publishing;
`deploy` only runs on `push`/`workflow_dispatch` and publishes via
`actions/deploy-pages`, GitHub's native Pages deployment action.

```yaml
name: Build & Deploy Documentation

on:
  pull_request:
    branches:
      - main
    paths:
      - "zensical.toml"
      - "mkdocs.yml"
      - "docs/**"
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  docs:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: slaclab/swapps-ci-helpers/.github/workflows/docs.yml@<SHA>
    with:
      docs-group: "docs"
```

Inputs:

| Name | Default | Description |
| --- | --- | --- |
| `docs-group` | `"docs"` | uv dependency group to sync for building the docs |
| `docs-tool` | `"zensical"` | Doc build tool: `"zensical"` or `"mkdocs"` — set to `"mkdocs"` for repos not yet migrated |

No `secrets: inherit` needed — `actions/deploy-pages` authenticates via the
job's own `id-token: write` permission, not a token secret. The calling job
must explicitly request `pages: write`/`id-token: write` (as shown above) —
a reusable workflow's jobs can never receive more permissions than the
caller job grants. The consuming repo's GitHub Pages source must be set to
"GitHub Actions" (Settings → Pages) for the deploy step to work.

### Build GHCR Image and Dispatch Deployment (`build-image-and-dispatch.yml`)

Builds a Docker image from the calling repo, pushes it to GHCR for the
deployment ref, then dispatches `deploy-image` to
`slaclab/swapps-deployment`. Pull requests still build the image, but do not
push or dispatch, including `pull_request_target` runs. This is the
recommended default for SWAPPS apps whose image can be built directly from a
Dockerfile.

```yaml
name: Build image and deploy dev

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-and-deploy:
    permissions:
      contents: read
      packages: write
    uses: slaclab/swapps-ci-helpers/.github/workflows/build-image-and-dispatch.yml@<SHA>
    with:
      app: canopy
      environment: dev
      dockerfile: docker/Dockerfile.prod
      context: .
      sha-tag-prefix: ""
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Inputs:

| Name | Default | Description |
| --- | --- | --- |
| `app` | required | App name in `slaclab/swapps-deployment` |
| `environment` | `"dev"` | Deployment environment to update |
| `deployment-owner` | calling repository owner | Owner of the repository that receives deployment dispatches |
| `deployment-repo` | `"swapps-deployment"` | Repository that receives the `deploy-image` dispatch |
| `deploy-ref` | `"refs/heads/main"` | Git ref allowed to push the image and dispatch deployment |
| `image-name` | calling repo | GHCR image name without registry, for example `slaclab/canopy` |
| `dockerfile` | `"Dockerfile"` | Dockerfile path |
| `context` | `"."` | Docker build context |
| `platforms` | `"linux/amd64"` | Platform list passed to Buildx |
| `setup-qemu` | `false` | Install QEMU before Buildx, usually for multi-arch builds |
| `sha-tag-prefix` | `"sha-"` | Prefix for the deployable SHA tag; use `""` for bare short-SHA tags or `"main-"` for `main-<sha>` |
| `latest-tag` | `true` | Also publish `latest` on the deployment ref |
| `extra-tags` | `""` | Additional `docker/metadata-action` tag rules |
| `labels` | `""` | Additional `docker/metadata-action` labels |
| `build-args` | `""` | Newline-separated Docker build args |
| `target` | `""` | Optional Docker build target |
| `provenance` | `""` | Provenance setting passed to `docker/build-push-action` |
| `cache-from` | `"type=gha"` | Docker build cache source |
| `cache-to` | `"type=gha,mode=max"` | Docker build cache destination |

Secrets:

| Name | Description |
| --- | --- |
| `APP_ID` | GitHub App ID with access to `swapps-deployment` |
| `APP_PRIVATE_KEY` | GitHub App private key with access to `swapps-deployment` |

The deployable image is always the GHCR image plus the SHA tag generated from
`sha-tag-prefix`, for example `ghcr.io/slaclab/react-squirrel:main-abcdef0`.
The workflow output `image` contains that immutable full image reference.
Deploy-capable runs verify the deployment credentials before publishing.

### Build GHCR Image (`build-ghcr-image.yml`)

Use this workflow when an application can build directly from a Dockerfile but
dispatches deployment separately. It validates every build. Only `push` or
`workflow_dispatch` runs on `deploy-ref` authenticate to GHCR and publish.
The `image` output is the normalized-lowercase GHCR name with its immutable
SHA tag.

```yaml
jobs:
  image:
    permissions:
      contents: read
      packages: write
    uses: slaclab/swapps-ci-helpers/.github/workflows/build-ghcr-image.yml@<SHA>
    with:
      image-name: slaclab/canopy
      dockerfile: docker/Dockerfile.prod
      sha-tag-prefix: ""
```

It accepts the image-related inputs listed for
`build-image-and-dispatch.yml`: `deploy-ref`, `image-name`, `dockerfile`,
`context`, `platforms`, `setup-qemu`, `sha-tag-prefix`, `latest-tag`,
`extra-tags`, `labels`, `build-args`, `target`, `provenance`, `cache-from`,
and `cache-to`.

### Dispatch SWAPPS Deployment (`dispatch-swapps-deployment.yml`)

Use this workflow after custom test, package, and image-publishing jobs. It
only mints the GitHub App token and sends `deploy-image` for a `push` or
`workflow_dispatch` run on `deploy-ref`; pull request events never access the
App credentials. The `image` input must be an immutable full image reference;
the same value is returned as the `image` output after dispatch.

```yaml
jobs:
  dispatch:
    needs: publish-image
    uses: slaclab/swapps-ci-helpers/.github/workflows/dispatch-swapps-deployment.yml@<SHA>
    with:
      app: canopy
      environment: dev
      image: ${{ needs.publish-image.outputs.image }}
      deployment-owner: slaclab
      deployment-repo: swapps-deployment
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Inputs are `app` (required), `environment` (`"dev"`), `image` (required),
`deployment-owner` (calling repository owner), `deployment-repo`
(`"swapps-deployment"`), and `deploy-ref` (`"refs/heads/main"`). The
workflow sends `app`, `environment`, and `image` in the receiver's expected
`deploy-image` payload.

## Bumping the pin

When this repo changes, consumers keep running the old, working version of
the workflow until they deliberately update their `@<SHA>` reference. Update
the pin in each consumer repo after confirming the change here is safe.

Use Dependabot to keep this up to date automatically: add a `dependabot.yml`
with a `github-actions` ecosystem entry to your consumer repo (see this
repo's own [`.github/dependabot.yml`](.github/dependabot.yml) for an
example), and it will open a PR bumping your `uses:
.../swapps-ci-helpers/...@<SHA>` reference whenever this repo publishes a new
commit.
