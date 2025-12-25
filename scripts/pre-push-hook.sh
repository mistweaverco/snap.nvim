#!/bin/bash

# Git pre-push hook script to validate version consistency before pushing tags
# This script is called by simple-git-hooks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-version.sh"

# Check if we're pushing a tag
while read local_ref local_oid remote_ref remote_oid; do
  # Check if this is a tag reference
  if [[ "$local_ref" =~ ^refs/tags/ ]]; then
    tag_name="${local_ref#refs/tags/}"
    
    # Validate that versions match before allowing tag push
    if [[ -f "$VALIDATE_SCRIPT" ]]; then
      echo "Validating version consistency before pushing tag: $tag_name"
      if ! bash "$VALIDATE_SCRIPT" "$tag_name"; then
        echo ""
        echo "✗ Tag push blocked: Version validation failed!"
        echo "  Please fix the version issues before pushing the tag."
        exit 1
      fi
      
      # Also check if the tag matches the version in plugin.lua
      plugin_version=$(grep -oP 'return "\K[^"]+' "$PROJECT_ROOT/lua/snap/globals/versions/plugin.lua" 2>/dev/null || echo "")
      expected_tag="v$plugin_version"
      
      if [[ "$tag_name" != "$expected_tag" ]]; then
        echo ""
        echo "✗ Tag push blocked: Tag name doesn't match plugin version!"
        echo "  Tag name: $tag_name"
        echo "  Expected: $expected_tag (based on plugin.lua)"
        echo ""
        echo "Either:"
        echo "  1. Update the version with: ./scripts/set-version.sh $plugin_version"
        echo "  2. Use the correct tag name: $expected_tag"
        exit 1
      fi
      
      echo "✓ Version validation passed for tag: $tag_name"
    else
      echo "⚠ Warning: validate-version.sh not found, skipping version validation"
    fi
  fi
done

exit 0

