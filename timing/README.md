# Timing composite actions

Composite actions shared by the EED timing repositories (`py-tlib-*`,
`py-timing-services`, `tp-gui-*`). They live under `timing/` while they
incubate; any that prove useful elsewhere can be promoted to a general
location later (leaving a thin wrapper here so existing pins keep working).

Composite actions run as steps inside the caller's job, so the caller still
controls `runs-on`, `container`, `permissions`, and `concurrency`.

Pin every reference to a commit SHA, for example:

```yaml
- uses: slaclab/swapps-ci-helpers/timing/setup-private-git@<SHA>
```

Every action except `coverage-comment` uses only `bash`/`pwsh` steps or
pinned JavaScript actions, so they run on Linux, macOS, and Windows, and in
container jobs such as `rockylinux:9`. `coverage-comment` wraps a Docker
action and needs a Linux runner with Docker, such as `ubuntu-latest`.
`resolve-release-latest` and `create-release` query the latest release with
the GitHub CLI, so container jobs must have `gh` on `PATH` (GitHub-hosted
runners already do).

Inputs that take arguments (`pytest-args`, `spec-args`, `smoke-test-args`)
take one argument per line. Each line is passed as-is, with no shell quoting
or expansion, so an argument may contain spaces:

```yaml
pytest-args: |
  -k
  not slow
```

## `setup-private-git`

Rewrites `https://github.com/` Git URLs to authenticate with a token so `uv`
can fetch internal timing dependencies. Replaces the `gh auth setup-git`,
`~/.git-credentials`, and per-OS `insteadOf` variants.

```yaml
- uses: slaclab/swapps-ci-helpers/timing/setup-private-git@<SHA>
  with:
    token: ${{ secrets.TIMING_REPOS_TOKEN }}
```

| Input | Default | Description |
| --- | --- | --- |
| `token` | required | Token with read access to the private repositories |
| `host` | `github.com` | Git host to authenticate |

## `resolve-release-latest`

Decides whether a tag should be marked as the "latest" GitHub release: only
stable tags (matching `tag-pattern`) that are at least as high as the current
latest release qualify. Fails rather than guessing if the current latest
release can't be queried. Needs `gh` on `PATH` unless `current-latest` is set.

| Input | Default | Description |
| --- | --- | --- |
| `tag` | `github.ref_name` | Tag being released |
| `tag-pattern` | `^R[0-9]+\.[0-9]+\.[0-9]+$` | Extended regex for stable release tags |
| `tag-prefix` | `R` | Prefix stripped before comparing versions |
| `current-latest` | `""` | Override the queried latest tag (`none` = no releases); for testing |
| `token` | `github.token` | Token used to query the latest release |

Outputs: `make_latest`, and `prerelease` (`true` when the tag doesn't match
`tag-pattern`).

## `create-release`

Creates the GitHub Release, using the same logic as `resolve-release-latest`
to set `make_latest`. The caller job needs `permissions: contents: write` and
`gh` on `PATH`; no checkout is required unless `files` come from the workspace.

```yaml
release:
  if: startsWith(github.ref, 'refs/tags/')
  runs-on: ubuntu-latest
  concurrency:
    group: release-${{ github.repository }}
    cancel-in-progress: false
  permissions:
    contents: write
  steps:
    - uses: slaclab/swapps-ci-helpers/timing/create-release@<SHA>
      with:
        files: |
          artifacts/tpggui-linux-x86_64.tar.gz
```

| Input | Default | Description |
| --- | --- | --- |
| `tag` | `github.ref_name` | Tag to release |
| `files` | `""` | Newline-separated asset paths or globs |
| `generate-release-notes` | `true` | Generate notes from merged PRs |
| `mark-prereleases` | `false` | Publish tags that don't match `tag-pattern` as pre-releases |
| `tag-pattern` | `^R[0-9]+\.[0-9]+\.[0-9]+$` | Extended regex for stable release tags |
| `tag-prefix` | `R` | Prefix stripped before comparing versions |
| `token` | `github.token` | Token with `contents: write` |

Outputs: `url`, `make_latest`.

## `pytest-coverage`

Runs `uv sync`, then `pytest` under `coverage`, and uploads the data as a
`coverage-<suffix>` artifact. Requires checkout and `astral-sh/setup-uv` (or
another uv install) first. For `coverage-comment` to find the sources, the
project must record relative paths:

```toml
[tool.coverage.run]
relative_files = true
```

```yaml
- uses: slaclab/swapps-ci-helpers/timing/pytest-coverage@<SHA>
  with:
    artifact-suffix: ${{ matrix.os }}
```

| Input | Default | Description |
| --- | --- | --- |
| `dependency-group` | `dev` | uv dependency group to sync |
| `pytest-args` | `""` | Extra pytest arguments, one per line |
| `artifact-suffix` | runner OS | Unique per matrix entry |
| `step-summary` | `false` | Also write pytest output to the job summary |

## `coverage-comment`

Merges every `coverage-*` artifact and reports it with
`python-coverage-comment-action`. Run it on a Linux runner with Docker, in a
job that `needs` the test jobs, after a checkout, with `pull-requests: write`
and `contents: write`.

```yaml
coverage:
  needs: test
  runs-on: ubuntu-latest
  permissions:
    pull-requests: write
    contents: write
  steps:
    - uses: actions/checkout@<SHA>
    - uses: slaclab/swapps-ci-helpers/timing/coverage-comment@<SHA>
```

| Input | Default | Description |
| --- | --- | --- |
| `github-token` | `github.token` | Token for the comment and coverage data |
| `only-on-pull-request` | `false` | Skip non-PR events. Keep `false` so default-branch pushes record the baseline |

## `pyinstaller-build`

Runs `uv sync`, builds a PyInstaller spec, smoke tests each executable
(Windows uses `Start-Process -Wait` so windowed executables report their real
exit code), and uploads all executables as one artifact. Requires checkout,
uv, and any system packages first.

Artifacts don't keep file permissions, so run `chmod +x` on downloaded Linux
and macOS executables before running or archiving them.

```yaml
- uses: slaclab/swapps-ci-helpers/timing/pyinstaller-build@<SHA>
  with:
    spec: tp_controls.spec
    executables: |
      pattern_selection
      test_log
    artifact-name: tp-controls-linux-x86_64
```

| Input | Default | Description |
| --- | --- | --- |
| `spec` | required | PyInstaller `.spec` path |
| `spec-args` | `""` | Extra pyinstaller arguments, one per line, e.g. `--`, `--guis`, `pattern_selection` |
| `executables` | required | Newline-separated names produced in `dist/` (`.exe` added on Windows) |
| `artifact-name` | required | Name of the uploaded artifact |
| `dependency-group` | `dev` | uv group to sync; must include pyinstaller |
| `smoke-test-args` | `--import-check` | Smoke test arguments, one per line; empty to skip |
| `qt-offscreen` | `true` | Set `QT_QPA_PLATFORM=offscreen` |

Output: `paths`, the built executable paths.

## Development

Run the `resolve.sh` unit tests locally:

```bash
bash timing/resolve-release-latest/test_resolve.sh
```
