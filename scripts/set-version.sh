#!/usr/bin/env bash

# Script to set version in plugin.lua and README.md
# Optionally updates backend.lua version if --backend flag is used
# Usage: ./scripts/set-version.sh [VERSION] [--backend]
#   VERSION: Version to set (X.Y.Z format). If not provided, read from plugin.lua
#   --backend: Also update backend.lua version to match

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_VERSION_FILE="$PROJECT_ROOT/lua/snap/globals/versions/plugin.lua"
BACKEND_VERSION_FILE="$PROJECT_ROOT/lua/snap/globals/versions/backend.lua"
README_FILE="$PROJECT_ROOT/README.md"

# Extract version from plugin.lua (format: return "X.Y.Z")
get_plugin_version() {
  if [[ -f "$PLUGIN_VERSION_FILE" ]]; then
    grep -oP 'return "\K[^"]+' "$PLUGIN_VERSION_FILE" || echo ""
  else
    echo ""
  fi
}

# Extract version from README.md (format: vX.Y.Z)
get_readme_version() {
  if [[ -f "$README_FILE" ]]; then
    # Find the first version reference (vX.Y.Z format)
    grep -oP "version\s*=\s*['\"]v?\K[^'\"]+" "$README_FILE" | head -1 || echo ""
  else
    echo ""
  fi
}

# Set version in plugin.lua
set_plugin_version() {
  local version="$1"
  if [[ -f "$PLUGIN_VERSION_FILE" ]]; then
    sed -i "s/return \"[^\"]*\"/return \"$version\"/" "$PLUGIN_VERSION_FILE"
    echo "✓ Updated version in $PLUGIN_VERSION_FILE to $version"
  else
    echo "✗ Error: $PLUGIN_VERSION_FILE not found"
    exit 1
  fi
}

# Set version in README.md (all occurrences)
set_readme_version() {
  local version="$1"
  local version_with_v="v$version"
  
  if [[ -f "$README_FILE" ]]; then
    # Replace all version references in README.md
    # Matches: version = 'vX.Y.Z', version = "vX.Y.Z", tag = 'vX.Y.Z'
    sed -i "s/\(version\|tag\)\s*=\s*['\"]v\?[^'\"]*['\"]/\1 = '$version_with_v'/" "$README_FILE"
    echo "✓ Updated version in $README_FILE to $version_with_v"
  else
    echo "✗ Error: $README_FILE not found"
    exit 1
  fi
}

# Set version in backend.lua
set_backend_version() {
  local version="$1"
  if [[ -f "$BACKEND_VERSION_FILE" ]]; then
    sed -i "s/return \"[^\"]*\"/return \"$version\"/" "$BACKEND_VERSION_FILE"
    echo "✓ Updated version in $BACKEND_VERSION_FILE to $version"
  else
    echo "✗ Error: $BACKEND_VERSION_FILE not found"
    exit 1
  fi
}

# Main logic
main() {
  cd "$PROJECT_ROOT"
  
  local new_version=""
  local update_backend=false
  
  # Parse arguments
  for arg in "$@"; do
    if [[ "$arg" == "--backend" ]]; then
      update_backend=true
    elif [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      new_version="$arg"
    fi
  done
  
  if [[ -z "$new_version" ]]; then
    # If no version provided, read from plugin.lua
    new_version=$(get_plugin_version)
    if [[ -z "$new_version" ]]; then
      echo "✗ Error: Could not determine version from $PLUGIN_VERSION_FILE"
      echo "Usage: $0 [VERSION] [--backend]"
      exit 1
    fi
    echo "Using version from plugin.lua: $new_version"
  fi
  
  # Validate version format (X.Y.Z)
  if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✗ Error: Invalid version format. Expected X.Y.Z (e.g., 1.4.0)"
    exit 1
  fi
  
  # Update plugin and README
  set_plugin_version "$new_version"
  set_readme_version "$new_version"
  
  # Optionally update backend version
  if [[ "$update_backend" == true ]]; then
    set_backend_version "$new_version"
  fi
  
  echo ""
  echo "✓ Version synchronized successfully!"
  echo "  Plugin version: $new_version"
  echo "  README version: v$new_version"
  if [[ "$update_backend" == true ]]; then
    echo "  Backend version: $new_version"
  fi
}

main "$@"

