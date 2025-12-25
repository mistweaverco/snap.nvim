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

# Clean dist directory
# Remove all files except .gitignore
echo " 🧹 Cleaning dist directory..."
echo
cd dist || { echo " ❌ Failed to change to dist directory.";echo;exit 1; }
rm -rf ./*
cd .. || { echo " ❌ Failed to change to root directory.";echo;exit 1; }

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

bun build --cwd ./backend/bun --compile --target="bun-$BUILD_TARGET" --external electron ./src/index.ts --outfile "../../dist/snap-nvim-${PLATFORM_NAME}${BIN_EXT}" || { echo " ❌ Build failed.";echo;exit 1; }

if [ "$CI" == false ]; then
  echo " ✅ Build completed successfully in non CI ☁️ environment."
  echo
  exit 0
fi

echo " 🎭 Installing Playwright Chromium..."
echo
bunx playwright install chromium || { echo " ❌ Failed to install Chromium.";echo;exit 1; }

echo " 🧹 Removing unused locales..."
echo
# Find and remove unused locale files, but keep en-US.pak and required files
# Use a loop to handle multiple chromium directories
for chromium_dir in ~/.cache/ms-playwright/chromium-*; do
  if [ -d "$chromium_dir" ]; then
    find "$chromium_dir" -path "*locales*" -type f ! -name "en-US.pak" -delete || true
  fi
done

# Ensure required files are kept
# icudtl.dat, chrome_100_percent.pak, chrome_200_percent.pak are kept automatically

echo " 📦 Bundling Playwright..."
echo
# Create playwright directory in dist
mkdir -p "dist/playwright"

# Copy only the latest playwright chromium version to dist
PLAYWRIGHT_FOUND=false
LATEST_CHROMIUM_DIR=$(ls -1d ~/.cache/ms-playwright/chromium-* 2>/dev/null | sort -V | tail -1)

if [ -n "$LATEST_CHROMIUM_DIR" ] && [ -d "$LATEST_CHROMIUM_DIR" ]; then
  # Extract just the directory name (e.g., chromium-1200)
  CHROMIUM_VERSION=$(basename "$LATEST_CHROMIUM_DIR")
  cp -R "$LATEST_CHROMIUM_DIR" "dist/playwright/$CHROMIUM_VERSION" || { echo " ❌ Failed to copy Playwright.";echo;exit 1; }
  PLAYWRIGHT_FOUND=true
  echo " ✅ Bundled Chromium version: $CHROMIUM_VERSION"
  echo
fi

if [ "$PLAYWRIGHT_FOUND" = false ]; then
  echo " ⚠️  Warning: Playwright cache not found, skipping bundling"
fi

echo " 📦 Creating release archive..."
echo

BINARY_NAME="snap-nvim-${PLATFORM_NAME}${BIN_EXT}"

# Create archive based on platform
case "$PLATFORM" in
  "windows-x86_64")
    ARCHIVE_NAME="snap-nvim-${PLATFORM_NAME}.zip"
    cd dist || { echo " ❌ Failed to change to dist directory.";echo;exit 1; }
    if [ -d "playwright" ]; then
      zip -9 -r "$ARCHIVE_NAME" "$BINARY_NAME" playwright/ || { echo " ❌ Failed to create zip archive.";echo;exit 1; }
    else
      zip -9 "$ARCHIVE_NAME" "$BINARY_NAME" || { echo " ❌ Failed to create zip archive.";echo;exit 1; }
    fi
    cd ..
    ;;
  *)
    ARCHIVE_NAME="snap-nvim-${PLATFORM_NAME}.tar.gz"
    cd dist || { echo " ❌ Failed to change to dist directory.";echo;exit 1; }
    if [ -d "playwright" ]; then
      tar --use-compress-program='gzip -9' -cf "$ARCHIVE_NAME" "$BINARY_NAME" playwright/ || { echo " ❌ Failed to create tar.gz archive.";echo;exit 1; }
    else
      tar --use-compress-program='gzip -9' -cf "$ARCHIVE_NAME" "$BINARY_NAME" || { echo " ❌ Failed to create tar.gz archive.";echo;exit 1; }
    fi
    cd ..
    ;;
esac

echo " ✅ Build completed successfully in CI ☁️ environment."
echo " 📦 Archive created: dist/$ARCHIVE_NAME"
