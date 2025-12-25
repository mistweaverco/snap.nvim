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

/**
 * Finds Chromium executable in a given directory
 * @param playwrightDir - Directory containing chromium files
 * @returns The path to the Chromium executable, or null if not found
 */
function findChromiumInDirectory(playwrightDir: string): string | null {
  if (!fs.existsSync(playwrightDir)) {
    return null;
  }

  // For bundled builds: executable is directly in playwright directory
  // For cache (development): executable is in chromium-* or chromium_headless_shell* subdirectories

  // Executable names to search for
  const exeNames =
    process.platform === "win32"
      ? ["chrome.exe", "chrome-headless-shell.exe"]
      : process.platform === "darwin"
        ? ["chrome-headless-shell", "Chromium"]
        : ["chrome", "chrome-headless-shell"];

  // First, check directly in playwright directory (bundled builds)
  for (const exeName of exeNames) {
    const directPath = path.join(playwrightDir, exeName);
    if (fs.existsSync(directPath) && isExecutable(directPath)) {
      return directPath;
    }
  }

  // Fall back to cache structure: look for chromium-* or chromium_headless_shell* directories
  try {
    const entries = fs.readdirSync(playwrightDir, { withFileTypes: true });
    for (const entry of entries) {
      if (
        entry.isDirectory() &&
        (entry.name.startsWith("chromium-") || entry.name.startsWith("chromium_headless_shell"))
      ) {
        const cacheDir = path.join(playwrightDir, entry.name);
        // Recursively search in cache directory (max depth 2)
        function search(dir: string, depth: number = 0): string | null {
          if (depth > 2) return null;
          try {
            const dirEntries = fs.readdirSync(dir, { withFileTypes: true });
            for (const dirEntry of dirEntries) {
              const fullPath = path.join(dir, dirEntry.name);
              if (dirEntry.isFile() && exeNames.includes(dirEntry.name) && isExecutable(fullPath)) {
                return fullPath;
              } else if (dirEntry.isDirectory() && !dirEntry.name.startsWith(".")) {
                const found = search(fullPath, depth + 1);
                if (found) return found;
              }
            }
          } catch {
            // Ignore errors
          }
          return null;
        }
        const found = search(cacheDir);
        if (found) return found;
      }
    }
  } catch {
    // Ignore errors
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

  // Fall back to Playwright cache directory (development mode)
  const cacheDir = path.join(os.homedir(), ".cache", "ms-playwright");
  const cacheExecutable = findChromiumInDirectory(cacheDir);
  if (cacheExecutable) {
    return cacheExecutable;
  }

  throw new Error(
    `Chromium executable not found. Tried bundled directory: ${bundledPlaywrightDir} and cache directory: ${cacheDir}`,
  );
}
