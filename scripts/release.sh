#!/usr/bin/env bash
set -euo pipefail

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require git
require svu

BRANCH=${BRANCH:-main}

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit or stash changes first." >&2
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  echo "Switch to $BRANCH before releasing. (current: $CURRENT_BRANCH)" >&2
  exit 1
fi

git fetch origin "$BRANCH" --tags

LOCAL_HEAD=$(git rev-parse HEAD)
REMOTE_HEAD=$(git rev-parse "origin/$BRANCH")
if [[ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
  echo "Local $BRANCH is not up to date with origin/$BRANCH." >&2
  echo "Run: git pull --ff-only origin $BRANCH" >&2
  exit 1
fi

echo "Running tests..."
task test

NEXT_VERSION=$(svu next)
if [[ -z "$NEXT_VERSION" ]]; then
  echo "svu did not return a version." >&2
  exit 1
fi

echo "Next version: $NEXT_VERSION"
read -r -p "Create tag $NEXT_VERSION and push it? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

git tag -a "$NEXT_VERSION" -m "$NEXT_VERSION"
git push origin "$NEXT_VERSION"

echo "Tag pushed. GitHub Release will be created by CI."
