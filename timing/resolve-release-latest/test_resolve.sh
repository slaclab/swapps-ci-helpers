#!/usr/bin/env bash
# Unit tests for resolve.sh. Run: bash timing/resolve-release-latest/test_resolve.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/resolve.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failures=0
pattern='^R[0-9]+\.[0-9]+\.[0-9]+$'

# Fake gh: prints $FAKE_GH_LATEST, or fails when FAKE_GH_FAIL=1.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "${FAKE_GH_FAIL:-0}" = "1" ] && exit 1
printf '%s\n' "${FAKE_GH_LATEST:-}"
EOF
chmod +x "$tmp/bin/gh"

# check <name> <expected make_latest> <expected prerelease> [VAR=value ...]
check() {
  local name="$1" want_latest="$2" want_pre="$3"
  shift 3
  local out="$tmp/out"
  : > "$out"
  if ! env TAG_PATTERN="$pattern" TAG_PREFIX=R GITHUB_OUTPUT="$out" \
      GITHUB_REPOSITORY=slaclab/example PATH="$tmp/bin:$PATH" "$@" \
      bash "$script" 2> "$tmp/err"; then
    echo "FAIL $name: script exited non-zero: $(cat "$tmp/err")"
    failures=$((failures + 1))
    return
  fi
  local got
  got="$(tr '\n' ' ' < "$out")"
  local want="make_latest=$want_latest prerelease=$want_pre "
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: want '$want' got '$got'"
    failures=$((failures + 1))
  fi
}

check "pre-release tag is not latest"        false true  TAG=R1.0.0-alpha.1 CURRENT_LATEST=R0.9.0
check "first release is latest"              true  false TAG=R1.0.0 CURRENT_LATEST=none
check "newer patch is latest"                true  false TAG=R1.2.1 CURRENT_LATEST=R1.2.0
check "older backport is not latest"         false false TAG=R1.1.5 CURRENT_LATEST=R1.2.0
check "re-releasing latest stays latest"     true  false TAG=R1.2.0 CURRENT_LATEST=R1.2.0
check "versions compare numerically"         true  false TAG=R1.10.0 CURRENT_LATEST=R1.9.0
check "non-stable current latest is kept"    false false TAG=R2.0.0 CURRENT_LATEST=R2.0.0-beta.1
check "custom pattern and prefix"            true  false TAG=v2.0.0 CURRENT_LATEST=v1.9.9 \
  TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$' TAG_PREFIX=v
check "queries gh when no override"          true  false TAG=R1.3.0 FAKE_GH_LATEST=R1.2.0
check "gh reports no releases"               true  false TAG=R0.1.0 FAKE_GH_LATEST=

# A failed query must fail the step rather than guess.
if env TAG=R1.0.0 TAG_PATTERN="$pattern" TAG_PREFIX=R GITHUB_OUTPUT="$tmp/out" \
    GITHUB_REPOSITORY=slaclab/example PATH="$tmp/bin:$PATH" FAKE_GH_FAIL=1 \
    bash "$script" 2>/dev/null; then
  echo "FAIL gh failure exits non-zero"
  failures=$((failures + 1))
else
  echo "ok   gh failure exits non-zero"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
