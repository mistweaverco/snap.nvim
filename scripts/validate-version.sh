#!/usr/bin/env bash

# Script to validate that versions in plugin.lua and README.md match
# Also validates backend version if backend files have changed since last release
# Exit code 0 if versions match, 1 if they don't
#
# Usage: ./scripts/validate-version.sh [TAG_NAME]
#   TAG_NAME: Optional tag name (e.g., v1.4.0) to check backend changes against

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_VERSION_FILE="$PROJECT_ROOT/lua/snap/globals/versions/plugin.lua"
BACKEND_VERSION_FILE="$PROJECT_ROOT/lua/snap/globals/versions/backend.lua"
README_FILE="$PROJECT_ROOT/README.md"
TAG_NAME="${1:-}"

# Extract version from plugin.lua (format: return "X.Y.Z")
get_plugin_version() {
  if [[ -f "$PLUGIN_VERSION_FILE" ]]; then
    grep -oP 'return "\K[^"]+' "$PLUGIN_VERSION_FILE" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Extract all versions from README.md and check if they match
get_readme_versions() {
  if [[ -f "$README_FILE" ]]; then
    # Extract all version references (vX.Y.Z or X.Y.Z)
    grep -oP "(?:version|tag)\s*=\s*['\"]v?\K[^'\"]+" "$README_FILE" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Extract version from backend.lua (format: return "X.Y.Z")
get_backend_version() {
  if [[ -f "$BACKEND_VERSION_FILE" ]]; then
    grep -oP 'return "\K[^"]+' "$BACKEND_VERSION_FILE" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Check if backend files have changed since the last tag
has_backend_changes() {
  local tag_name="$1"
  
  # If no tag provided, assume there are changes (first release or can't determine)
  if [[ -z "$tag_name" ]]; then
    return 0  # true - has changes
  fi
  
  # Get all tags sorted by version (descending)
  # Note: --sort=-v:refname handles version sorting correctly, even with different-length
  # version parts (e.g., v100.20000.1 vs v10.5.3 will be sorted correctly)
  local all_tags=$(git tag --sort=-v:refname 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
  
  if [[ -z "$all_tags" ]]; then
    # No tags exist, assume changes
    return 0  # true - has changes
  fi
  
  # Find the previous tag (the one before the current tag in version-sorted order)
  # This works correctly even with different-length version parts thanks to git's version sorting
  local previous_tag=$(echo "$all_tags" | grep -A1 "^$tag_name$" | tail -n1 | grep -v "^$tag_name$" || echo "")
  
  if [[ -z "$previous_tag" ]]; then
    # Current tag is the first one or not found, assume changes
    return 0  # true - has changes
  fi
  
  # Check if any backend files changed between previous tag and current HEAD
  # Check both backend/ and lua/snap/globals/versions/backend.lua
  if git diff --name-only "$previous_tag" HEAD -- "backend/**" "lua/snap/globals/versions/backend.lua" | grep -q "."; then
    return 0  # true - has changes
  else
    return 1  # false - no changes
  fi
}

# Normalize version (remove 'v' prefix if present)
normalize_version() {
  echo "$1" | sed 's/^v//'
}

# Main validation logic
main() {
  cd "$PROJECT_ROOT"
  
  local plugin_version=$(get_plugin_version)
  local readme_versions=$(get_readme_versions)
  
  if [[ -z "$plugin_version" ]]; then
    echo "✗ Error: Could not read version from $PLUGIN_VERSION_FILE"
    exit 1
  fi
  
  if [[ -z "$readme_versions" ]]; then
    echo "✗ Error: Could not find version references in $README_FILE"
    exit 1
  fi
  
  local normalized_plugin_version=$(normalize_version "$plugin_version")
  local all_match=true
  local mismatches=()
  
  # Check each version in README
  while IFS= read -r readme_version; do
    local normalized_readme_version=$(normalize_version "$readme_version")
    if [[ "$normalized_readme_version" != "$normalized_plugin_version" ]]; then
      all_match=false
      mismatches+=("$readme_version")
    fi
  done <<< "$readme_versions"
  
  if [[ "$all_match" != true ]]; then
    echo "✗ Version mismatch detected!"
    echo "  Plugin version: $plugin_version"
    echo "  README versions found:"
    printf "    - %s\n" "${mismatches[@]}"
    echo ""
    echo "Run './scripts/set-version.sh' to synchronize versions."
    exit 1
  fi
  
  # Check backend version if backend files have changed
  if has_backend_changes "$TAG_NAME"; then
    local backend_version=$(get_backend_version)
    
    if [[ -z "$backend_version" ]]; then
      echo "✗ Error: Backend files have changed, but could not read version from $BACKEND_VERSION_FILE"
      exit 1
    fi
    
    # If tag is provided, check if backend version matches tag
    if [[ -n "$TAG_NAME" ]]; then
      local normalized_tag=$(normalize_version "$TAG_NAME")
      local normalized_backend_version=$(normalize_version "$backend_version")
      
      if [[ "$normalized_backend_version" != "$normalized_tag" ]]; then
        echo "✗ Backend version mismatch detected!"
        echo "  Backend files have changed since last release"
        echo "  Tag version: $normalized_tag"
        echo "  Backend version: $backend_version"
        echo ""
        echo "Since backend files changed, the backend version must match the tag version."
        echo "Update $BACKEND_VERSION_FILE to: return \"$normalized_tag\""
        exit 1
      fi
      
      echo "✓ Backend version matches tag: $backend_version"
    else
      echo "⚠ Backend files have changed, but no tag provided for validation"
      echo "  Backend version: $backend_version"
    fi
  else
    echo "✓ No backend changes detected since last release"
  fi
  
  echo ""
  echo "✓ All version validations passed!"
  echo "  Plugin version: $plugin_version"
  echo "  README version: v$normalized_plugin_version"
  exit 0
}

main "$@"

