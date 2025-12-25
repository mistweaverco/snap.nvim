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

echo " 📦 Installing dependencies..."

cd backend/bun || { echo " ❌ Failed to change to dist directory.";echo;exit 1; }
bun install --frozen-lockfile || { echo " ❌ Failed to install dependencies.";echo;exit 1; }
cd ../.. || { echo " ❌ Failed to change to root directory.";echo;exit 1; }

  # Places binaries in dist/.local-browsers
export PLAYWRIGHT_BROWSERS_PATH=./dist/.local-browsers
bunx playwright install chromium --only-shell

CURRENT_CHROMIUM_LOCALES_DIR=$(find ./dist/.local-browsers -type d -iname 'locales')
CURRENT_CHROMIUM_DIR=$(dirname "$CURRENT_CHROMIUM_LOCALES_DIR")
CURRENT_CHROMIUM_VERSION=$(basename "$CURRENT_CHROMIUM_DIR")

if [ -z "$CURRENT_CHROMIUM_DIR" ] || [ ! -d "$CURRENT_CHROMIUM_DIR" ]; then
  echo " ❌ Failed to locate Chromium directory in Playwright browsers."
  exit 1
fi

echo " 🔨 Building for backend: $BACKEND $BACKEND_ICON, platform: $PLATFORM $PLATFORM_ICON"
echo

BINARY_NAME="snap-nvim-${PLATFORM_NAME}${BIN_EXT}"

# Build the main executable
# Note: playwright-core cannot be bundled into the executable due to dynamic imports
# It will be loaded at runtime via dynamic import from node_modules
bun build --cwd ./backend/bun --compile --target="bun-$BUILD_TARGET" ./src/index.ts --outfile "../../dist/$BINARY_NAME" || { echo " ❌ Build failed.";echo;exit 1; }

# Copy playwright-core to dist for runtime loading
# playwright-core cannot be bundled, so we copy it as-is
# TODO: check if this is necessary for bun or if we can bundle it

# echo " 📦 Copying playwright-core for runtime..."
# echo
# mkdir -p "dist/node_modules"
# if [ -d "backend/bun/node_modules/playwright-core" ]; then
#   cp -R --dereference "backend/bun/node_modules/playwright-core" "dist/node_modules/" || {
#     echo " ⚠️  Warning: Failed to copy playwright-core to dist"
#   }
#   echo " ✅ Copied playwright-core to dist/node_modules/"
# else
#   echo " ⚠️  Warning: playwright-core not found in node_modules, make sure dependencies are installed"
# fi
# echo

if [ "$CI" == false ]; then
  echo " ✅ Build completed successfully in non CI ☁️ environment."
  echo
  exit 0
fi

if [ -z "$CURRENT_CHROMIUM_DIR" ] || [ ! -d "$CURRENT_CHROMIUM_DIR" ]; then
  echo " ❌ Failed to locate Chromium directory in Playwright browsers."
  exit 1
fi

echo " 🧹 Removing unused locales from Playwright ..."
echo

# Find and remove unused locale files, but keep en-US.pak and required files
find "$CURRENT_CHROMIUM_LOCALES_DIR" -type f ! -name "en-US.pak" -delete || true

# Create playwright directory and copy contents (not the directory itself)
mkdir -p "dist/playwright"
cp -R "$CURRENT_CHROMIUM_DIR"/* "dist/playwright/" || { echo " ❌ Failed to copy Playwright.";echo;exit 1; }
echo " ✅ Bundled Chromium version: $CURRENT_CHROMIUM_VERSION"
echo

echo " 📦 Creating release archive..."
echo

BINARY_NAME="snap-nvim-${PLATFORM_NAME}${BIN_EXT}"

# Function to create zip archive (cross-platform)
create_zip() {
  local archive_name="$1"
  shift
  local files=("$@")

  # Check if zip command is available
  if command -v zip >/dev/null 2>&1; then
    # Use zip command if available
    if [ ${#files[@]} -gt 1 ]; then
      zip -9 -r "$archive_name" "${files[@]}" || return 1
    else
      zip -9 "$archive_name" "${files[@]}" || return 1
    fi
  else
    # Fallback to PowerShell on Windows (Git Bash doesn't have zip by default)
    # Check if we're on Windows
    if [[ -n "$WINDIR" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "msys2" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$RUNNER_OS" == "Windows" ]]; then
      # Use PowerShell Compress-Archive
      # Convert Unix paths to Windows paths if needed (Git Bash uses Unix-style paths)
      # Get current directory in Windows format for PowerShell
      local pwd_win
      if command -v cygpath >/dev/null 2>&1; then
        pwd_win=$(cygpath -w "$(pwd)")
      else
        pwd_win=$(pwd)
      fi

      # Build PowerShell command with proper file list
      local ps_cmd="Set-Location -LiteralPath '$pwd_win'; Compress-Archive -Path @("
      local first=true
      for file in "${files[@]}"; do
        if [ "$first" = true ]; then
          first=false
        else
          ps_cmd+=","
        fi
        # Remove trailing slash for directories (PowerShell handles them correctly without it)
        local clean_file="${file%/}"
        # Convert to Windows path if needed
        local win_file
        if command -v cygpath >/dev/null 2>&1; then
          win_file=$(cygpath -w "$clean_file")
        else
          win_file="$clean_file"
        fi
        # Escape single quotes and wrap in quotes
        local escaped_file=$(echo "$win_file" | sed "s/'/''/g")
        ps_cmd+="'$escaped_file'"
      done
      # Convert archive name to Windows path
      local win_archive
      if command -v cygpath >/dev/null 2>&1; then
        win_archive=$(cygpath -w "$archive_name")
      else
        win_archive="$archive_name"
      fi
      local escaped_archive=$(echo "$win_archive" | sed "s/'/''/g")
      ps_cmd+=") -DestinationPath '$escaped_archive' -Force"
      powershell.exe -NoProfile -Command "$ps_cmd" || return 1
    else
      echo " ❌ zip command not found and not on Windows. Cannot create zip archive."
      return 1
    fi
  fi
}

# Create archive based on platform
# Include playwright-core node_modules if it exists
ARCHIVE_FILES=("$BINARY_NAME")
if [ -d "dist/playwright" ]; then
  ARCHIVE_FILES+=("playwright")
fi
if [ -d "dist/node_modules" ]; then
  ARCHIVE_FILES+=("node_modules")
fi

case "$PLATFORM" in
  "windows-x86_64")
    ARCHIVE_NAME="snap-nvim-${PLATFORM_NAME}.zip"
    cd dist || { echo " ❌ Failed to change to dist directory.";echo;exit 1; }
    create_zip "$ARCHIVE_NAME" "${ARCHIVE_FILES[@]}" || { echo " ❌ Failed to create zip archive.";echo;exit 1; }
    cd ..
    ;;
  *)
    ARCHIVE_NAME="snap-nvim-${PLATFORM_NAME}.tar.gz"
    cd dist || { echo " ❌ Failed to change to dist directory.";echo;exit 1; }
    tar --use-compress-program='gzip -9' -cf "$ARCHIVE_NAME" "${ARCHIVE_FILES[@]}" || { echo " ❌ Failed to create tar.gz archive.";echo;exit 1; }
    cd ..
    ;;
esac

echo " ✅ Build completed successfully in CI ☁️ environment."
echo " 📦 Archive created: dist/$ARCHIVE_NAME"
echo

echo " 🧹 Cleaning up temporary files..."
echo
# Remove copied playwright and node_modules to keep dist clean
rm -rf "$PLAYWRIGHT_BROWSERS_PATH" \
  "./dist/playwright" \
  "./dist/.local-browsers" \
  "./dist/$BINARY_NAME"
echo " ✅ Cleanup completed."
echo
