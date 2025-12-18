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

SUPPORTED_PLATFORMS=("linux-x86_64" "linux-aarch64" "macos-x86_64" "macos-arm64" "windows-x86_64")
CI_SUPPORTED_PLATFORMS=("linux-x86_64" "linux-aarch64" "macos-x86_64" "macos-arm64" "windows-x86_64")

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
  "linux-x86_64")
    BUILD_TARGET="linux-x64"
    PLATFORM_NAME="linux-x86_64"
    PLATFORM_ICON="🐧"
    ;;
  "linux-aarch64")
    BUILD_TARGET="linux-arm64"
    PLATFORM_NAME="linux-aarch64"
    PLATFORM_ICON="🐧"
    ;;
  "macos-x86_64")
    BUILD_TARGET="darwin-x64"
    PLATFORM_NAME="macos-x86_64"
    PLATFORM_ICON="🍎"
    ;;
  "macos-arm64")
    BUILD_TARGET="darwin-arm64"
    PLATFORM_NAME="macos-arm64"
    PLATFORM_ICON="🍎"
    ;;
  "windows-x86_64")
    BUILD_TARGET="windows-x64"
    PLATFORM_NAME="windows-x86_64"
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

bun build --compile --target="bun-$BUILD_TARGET" ./src/index.ts --outfile "../../dist/snap-nvim-${PLATFORM_NAME}${BIN_EXT}" || { echo " ❌ Build failed.";echo;exit 1; }

if [ "$CI" == false ]; then
  echo " ✅ Build completed successfully in non CI ☁️ environment."
  echo
  exit 0
fi

cd ../../ || { echo " ❌ Failed to change directory to project root.";echo;exit 1; }

echo " ✅ Build completed successfully in CI ☁️ environment."
