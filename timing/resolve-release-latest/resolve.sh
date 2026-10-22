#!/usr/bin/env bash
# Decide whether a release for TAG should be marked "latest" on GitHub.
#
# Environment:
#   TAG             tag being released (required)
#   TAG_PATTERN     ERE a stable release tag must match (required)
#   TAG_PREFIX      prefix stripped before comparing versions (may be empty)
#   CURRENT_LATEST  tag of the repo's current latest release; when empty it is
#                   queried with `gh`, and the literal "none" means no release
#   GH_TOKEN        token for `gh` (only needed when CURRENT_LATEST is empty)
#   GITHUB_REPOSITORY  owner/name (only needed when CURRENT_LATEST is empty)
#
# Writes make_latest=<true|false> and prerelease=<true|false> to $GITHUB_OUTPUT,
# or to stdout when GITHUB_OUTPUT is unset.
set -euo pipefail

: "${TAG:?TAG is required}"
: "${TAG_PATTERN:?TAG_PATTERN is required}"
TAG_PREFIX="${TAG_PREFIX-}"
CURRENT_LATEST="${CURRENT_LATEST-}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

emit() {
  echo "make_latest=$1" >> "$OUT"
  echo "prerelease=$2" >> "$OUT"
}

if ! [[ "$TAG" =~ $TAG_PATTERN ]]; then
  echo "Tag '$TAG' does not match '$TAG_PATTERN'; not marking as latest." >&2
  emit false true
  exit 0
fi

if [ -z "$CURRENT_LATEST" ]; then
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required to query the latest release}"
  # The $owner/$name below are GraphQL variables, not shell expansions.
  # shellcheck disable=SC2016
  if ! CURRENT_LATEST=$(gh api graphql \
    -f query='query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { latestRelease { tagName } } }' \
    -f owner="${GITHUB_REPOSITORY%/*}" \
    -f name="${GITHUB_REPOSITORY#*/}" \
    --jq '.data.repository.latestRelease.tagName // ""'); then
    echo "Unable to determine the current latest release; refusing to guess." >&2
    exit 1
  fi
  CURRENT_LATEST="${CURRENT_LATEST:-none}"
fi

if [ "$CURRENT_LATEST" = "none" ]; then
  emit true false
  exit 0
fi

if ! [[ "$CURRENT_LATEST" =~ $TAG_PATTERN ]]; then
  echo "Current latest '$CURRENT_LATEST' does not match '$TAG_PATTERN'; not marking as latest." >&2
  emit false false
  exit 0
fi

current_ver="${TAG#"$TAG_PREFIX"}"
latest_ver="${CURRENT_LATEST#"$TAG_PREFIX"}"
highest=$(printf '%s\n%s\n' "$current_ver" "$latest_ver" | sort -V | tail -n1)

if [ "$highest" = "$current_ver" ]; then
  emit true false
else
  emit false false
fi
