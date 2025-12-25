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
 * @param playwrightDir - Directory containing chromium-* folders
 * @returns The path to the Chromium executable, or null if not found
 */
function findChromiumInDirectory(playwrightDir: string): string | null {
  if (!fs.existsSync(playwrightDir)) {
    return null;
  }

  const chromiumDirs = fs.readdirSync(playwrightDir).filter((d) => d.startsWith("chromium-"));

  if (chromiumDirs.length === 0) {
    return null;
  }

  for (const dir of chromiumDirs) {
    const full = path.join(playwrightDir, dir);

    const candidates =
      process.platform === "win32"
        ? [path.join(full, "chrome.exe")]
        : process.platform === "darwin"
          ? [path.join(full, "chrome-mac", "Chromium.app", "Contents", "MacOS", "Chromium")]
          : [
              path.join(full, "chrome-linux64", "chrome"),
              path.join(full, "chrome-linux", "chrome"),
              path.join(full, "chrome"),
            ];

    for (const candidate of candidates) {
      if (fs.existsSync(candidate) && isExecutable(candidate)) {
        return candidate;
      }
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
