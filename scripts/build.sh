#!/usr/bin/env bash

BACKEND="$1"
PLATFORM="$2"
CI=${CI:-false}
VERSION=${VERSION:-""}

if [ -z "$BACKEND" ] || [ -z "$PLATFORM" ]; then
  echo "Usage: $0 <backend> <platform>"
  echo "Example: $0 node linux-amd64"
  exit 1
fi

if [ -z "$VERSION" ]; then
  echo " ❌ VERSION environment variable is not set."
  exit 1
fi

SUPPORTED_PLATFORMS=("linux-amd64" "linux-arm64" "macos-amd64" "macos-arm64" "windows-amd64" "windows-arm64")
CI_SUPPORTED_PLATFORMS=("ubuntu-latest-x86_64" "ubuntu-latest-aarch64" "macos-latest-x86_64" "macos-latest-aarch64" "windows-latest-x86_64" "windows-latest-aarch64")

SUPPORTED_BACKENDS=("bun")

list_supported_platforms() {
  if [ "$CI" != false ]; then
    echo "    (CI Environment - Supported platform labels are:)"
    for platform in "${CI_SUPPORTED_PLATFORMS[@]}"; do
      echo "    - $platform"
    done
    return
  fi
  for platform in "${SUPPORTED_PLATFORMS[@]}"; do
    echo "    - $platform"
  done
}

list_supported_backends() {
  for backend in "${SUPPORTED_BACKENDS[@]}"; do
    echo "    - $backend"
  done
}

BUILD_TARGET=""
BIN_EXT=""
PLATFORM_CI_AGNOSTIC_NAME=""
BACKEND_ICON=""
PLATFORM_ICON=""

case "$BACKEND" in
  "bun")
    BACKEND_ICON="🔥"
    ;;
  *)
    echo " ❌ Unsupported backend: $BACKEND"
    echo "    Supported backends are:"
    list_supported_backends
    echo
    exit 1
    ;;
esac

case "$PLATFORM" in
  "linux-amd64"|"ubuntu-latest-x86_64")
    BUILD_TARGET="linux-x64"
    PLATFORM_CI_AGNOSTIC_NAME="linux-amd64"
    PLATFORM_ICON="🐧"
    ;;
  "linux-arm64"|"ubuntu-latest-aarch64")
    BUILD_TARGET="linux-arm64"
    PLATFORM_CI_AGNOSTIC_NAME="linux-arm64"
    PLATFORM_ICON="🐧"
    ;;
  "macos-amd64"|"macos-latest-x86_64")
    BUILD_TARGET="darwin-x64"
    PLATFORM_CI_AGNOSTIC_NAME="macos-amd64"
    PLATFORM_ICON="🍎"
    ;;
  "macos-arm64"|"macos-latest-aarch64")
    BUILD_TARGET="darwin-arm64"
    PLATFORM_CI_AGNOSTIC_NAME="macos-arm64"
    PLATFORM_ICON="🍎"
    ;;
  "windows-amd64"|"windows-latest-x86_64")
    BUILD_TARGET="windows-x64"
    PLATFORM_CI_AGNOSTIC_NAME="windows-amd64"
    PLATFORM_ICON="🪟"
    BIN_EXT=".exe"
    ;;
  "windows-arm64"|"windows-latest-aarch64")
    BUILD_TARGET="windows-arm64"
    PLATFORM_CI_AGNOSTIC_NAME="windows-arm64"
    PLATFORM_ICON="🪟"
    BIN_EXT=".exe"
    ;;
  *)
    echo " ❌ Unsupported platform: $PLATFORM"
    echo "    Supported platforms are:"
    list_supported_platforms
    echo
    exit 1
    ;;
esac

cd "backend/$BACKEND" || { echo " ❌ Backend directory not found: backend/$BACKEND";echo;exit 1; }

if [[ ! -d "node_modules" ]]; then
  echo " 📦 Installing dependencies..."
  echo
  bun install --frozen-lockfile
else
  echo " ✅ Dependencies already installed."
  echo
fi

echo " 🔨 Building for backend: $BACKEND $BACKEND_ICON, platform: $PLATFORM $PLATFORM_ICON"
echo

bun build --compile --target="bun-$BUILD_TARGET" ./src/index.ts --outfile "../../dist/snap-nvim-${PLATFORM_CI_AGNOSTIC_NAME}${BIN_EXT}" || { echo " ❌ Build failed.";echo;exit 1; }

if [ "$CI" == false ]; then
  echo " ✅ Build completed successfully in non CI ☁️ environment."
  echo
  exit 0
fi

cd ../../ || { echo " ❌ Failed to change directory to project root.";echo;exit 1; }

echo " ✅ Build completed successfully in CI ☁️ environment."
