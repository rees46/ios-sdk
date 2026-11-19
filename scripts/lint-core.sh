#!/usr/bin/env sh
# Lints the whole SDK with .swiftlint.yml: force unwraps, tries and casts fail the build.
# Exits 0 with a notice when swiftlint is not installed, so a machine without it is not blocked;
# on CI a missing swiftlint fails, so the check cannot pass without linting.
set -eu
cd "$(dirname "$0")/.."
if ! command -v swiftlint >/dev/null 2>&1; then
  if [ -n "${CI:-}" ]; then
    echo "swiftlint is not installed on CI"
    exit 1
  fi
  echo "swiftlint is not installed: the core lint was skipped"
  exit 0
fi
swiftlint lint --strict --quiet
