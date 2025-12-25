import fs from "node:fs";
import path from "node:path";
import os from "node:os";

/**
 * Checks if a file is executable
 * @param file - Path to the file to check
 * @returns True if the file is executable
 */
function isExecutable(file: string): boolean {
  try {
    fs.accessSync(file, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

const EXE_NAMES =
  process.platform === "win32"
    ? ["chrome.exe", "chrome-headless-shell.exe"]
    : process.platform === "darwin"
      ? ["chrome-headless-shell", "Chromium"]
      : ["chrome", "chrome-headless-shell"];

/**
 * Searches recursively for the Chromium executable in the given directory
 * and its subdirectories.
 * @param dir - Directory containing chromium files
 * @returns The path to the Chromium executable, or null if not found
 */
function findChromiumInDirectory(dir: string): string | null {
  if (!fs.existsSync(dir)) {
    return null;
  }
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isFile()) {
      if (EXE_NAMES.includes(entry.name) && isExecutable(fullPath)) {
        return fullPath;
      }
    } else if (entry.isDirectory()) {
      const found = findChromiumInDirectory(fullPath);
      if (found) return found;
    }
  }

  return null;
}

/**
 * Resolves the Chromium executable path
 * First tries to find bundled Playwright (for production builds),
 * then falls back to Playwright cache directory (for development mode)
 * @returns The path to the Chromium executable
 * @throws Error if the executable is not found
 */
export function resolveChromiumExecutable(): string {
  // First, try to find bundled Playwright (production builds)
  const baseDir =
    process.execPath && process.execPath.endsWith(".exe")
      ? path.dirname(process.execPath)
      : path.dirname(process.execPath ?? process.cwd());

  const bundledPlaywrightDir = path.join(baseDir, "playwright");
  const bundledExecutable = findChromiumInDirectory(bundledPlaywrightDir);
  if (bundledExecutable) {
    return bundledExecutable;
  }

  // Development mode
  const cacheDir = path.join(process.cwd(), "dist", ".local-browsers");
  const cacheExecutable = findChromiumInDirectory(cacheDir);
  if (cacheExecutable) {
    return cacheExecutable;
  }

  throw new Error(
    `Chromium executable not found. Tried bundled directory: ${bundledPlaywrightDir} and cache directory: ${cacheDir}`,
  );
}
