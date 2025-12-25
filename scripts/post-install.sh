#!/bin/bash

bunx simple-git-hooks

if [ -z "$PLAYWRIGHT_BROWSERS_PATH" ]; then
  echo " ❌ PLAYWRIGHT_BROWSERS_PATH is not set."
  exit 1
fi


CURRENT_CHROMIUM_LOCALES_DIR=$(find ./dist/.local-browsers -type d -iname 'locales')
CURRENT_CHROMIUM_DIR=$(dirname "$CURRENT_CHROMIUM_LOCALES_DIR")
CHROMIUM_FOUND=false

for file in "$CURRENT_CHROMIUM_DIR/"*; do
  if [[ "$(basename "$file")" == "chrom"* && -x "$file" ]]; then
    CHROMIUM_FOUND=true
    break
  fi
done

if [ "$CHROMIUM_FOUND" = false ]; then
  echo " ℹ️ Installing Chromium browser via Playwright..."
  bunx playwright install chromium --only-shell
fi

