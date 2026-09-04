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

### Pre-commit (`pre-commit.yml`)

The one linting/formatting/type-checking workflow for both Python and JS/TS
repos — `pre-commit` itself is a Python tool, but hooks declared with
`language: node` (e.g. `eslint`, `prettier`, `tsc`) have their own runtime
installed automatically by the `pre-commit` framework, so no separate Node
setup step is needed here.

```yaml
name: Pre-commit

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  pre-commit:
    uses: slaclab/swapps-ci-helpers/.github/workflows/pre-commit.yml@<SHA>
```

No inputs. Runs `pre-commit` against the calling repo's own
`.pre-commit-config.yaml`. For typing/linting/formatting on a JS/TS repo,
add hooks like these to that file:

```yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v9.18.0
    hooks:
      - id: eslint
  - repo: https://github.com/rbubley/mirrors-prettier
    rev: v3.4.2
    hooks:
      - id: prettier
  - repo: local
    hooks:
      - id: tsc
        name: TypeScript type check
        entry: pnpm exec tsc --noEmit
        language: system
        pass_filenames: false
```

`tsc` needs `language: system` (not a `pre-commit` mirror) since type
checking requires the project's own `node_modules`/`tsconfig.json` — pin
`eslint`/`prettier` mirror `rev`s the same way third-party Actions are
pinned above: to a specific, deliberately-bumped version.

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
