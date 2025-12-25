#!/usr/bin/env bun

import { execSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";

// Run simple-git-hooks
try {
  execSync("bunx simple-git-hooks", { stdio: "inherit" });
} catch (error) {
  console.error("Failed to run simple-git-hooks:", error);
  process.exit(1);
}

// Check if PLAYWRIGHT_BROWSERS_PATH is set
const playwrightBrowsersPath = process.env.PLAYWRIGHT_BROWSERS_PATH;
if (!playwrightBrowsersPath) {
  console.error(" ❌ PLAYWRIGHT_BROWSERS_PATH is not set.");
  process.exit(1);
}

// Find Chromium locales directory
function findChromiumLocalesDir(dir: string): string | null {
  if (!existsSync(dir)) {
    return null;
  }

  try {
    const entries = readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = join(dir, entry.name);

      if (entry.isDirectory()) {
        // Check if this directory is named "locales" (case-insensitive)
        if (entry.name.toLowerCase() === "locales") {
          return fullPath;
        }
        // Recursively search in subdirectories
        const found = findChromiumLocalesDir(fullPath);
        if (found) {
          return found;
        }
      }
    }
  } catch (error) {
    // Ignore permission errors and continue
  }

  return null;
}

const currentChromiumLocalesDir = findChromiumLocalesDir(playwrightBrowsersPath);
const currentChromiumDir = currentChromiumLocalesDir ? dirname(currentChromiumLocalesDir) : null;

let chromiumFound = false;

if (currentChromiumDir && existsSync(currentChromiumDir)) {
  try {
    const files = readdirSync(currentChromiumDir);

    for (const file of files) {
      const filePath = join(currentChromiumDir, file);

      try {
        const stats = statSync(filePath);

        // Check if it's a file (not a directory) and name starts with "chrom" (case-insensitive)
        if (stats.isFile() && file.toLowerCase().startsWith("chrom")) {
          // On Unix-like systems, also check if it's executable
          // On Windows, all files can be executed if they have the right extension
          const isExecutable = process.platform === "win32" || (stats.mode & 0o111) !== 0; // Check if executable (Unix)

          if (isExecutable) {
            chromiumFound = true;
            break;
          }
        }
      } catch (error) {
        // Skip files we can't stat
        continue;
      }
    }
  } catch (error) {
    // If we can't read the directory, assume Chromium is not found
    chromiumFound = false;
  }
}

if (!chromiumFound) {
  console.log(" ℹ️ Installing Chromium browser via Playwright...");
  try {
    execSync("bunx playwright install chromium --only-shell", {
      stdio: "inherit",
    });
  } catch (error) {
    console.error("Failed to install Chromium:", error);
    process.exit(1);
  }
}
