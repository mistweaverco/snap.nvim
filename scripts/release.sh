#!/usr/bin/env bash

set -euo pipefail

GH_TAG="v$VERSION"

set_version() {
  if [[ -z "${VERSION:-}" ]]; then
    echo "Error: VERSION environment variable is not set"
    echo "Usage: VERSION=1.4.0 ./scripts/release.sh"
    exit 1
  fi
  ./scripts/set-version.sh "$VERSION"
}

check_git_dirty() {
  if [[ -n $(git status -s) ]]; then
    echo "Working directory is dirty. Please commit or stash your changes before releasing."
    exit 1
  fi
}

validate_version() {
  if ! ./scripts/validate-version.sh; then
    echo "Error: Version validation failed. Please run './scripts/set-version.sh $VERSION' first."
    exit 1
  fi
}

do_gh_release() {
  echo "Creating new release $GH_TAG"
  gh release create --generate-notes "$GH_TAG"
}

boot() {
  check_git_dirty
  set_version
  validate_version
  do_gh_release
}

boot
