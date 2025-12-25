import { existsSync } from "node:fs";
import { resolveChromiumExecutable } from "./browser";
import { writeJSONToStdout } from "./stdin";

/**
 * Progress callback type for install operations
 */
export type InstallProgressCallback = (progress: {
  status: string;
  message: string;
  progress?: number;
}) => void;

/**
 * Checks if Playwright browser is available (bundled or in cache)
 * @returns Object with isInstalled boolean and executablePath if installed
 */
export const checkPlaywrightInstalled = (): {
  isInstalled: boolean;
  executablePath: string | null;
} => {
  try {
    const executablePath = resolveChromiumExecutable();
    if (executablePath && existsSync(executablePath)) {
      return { isInstalled: true, executablePath };
    }
    return { isInstalled: false, executablePath: null };
  } catch {
    return { isInstalled: false, executablePath: null };
  }
};

/**
 * Sets up Playwright and ensures browser is available.
 * Tries to resolve the executable path from bundled directory or cache.
 * @returns The executable path of the browser, or null if not found
 */
export const setupPlaywright = async (): Promise<string | null> => {
  try {
    const executablePath = resolveChromiumExecutable();
    if (executablePath && existsSync(executablePath)) {
      return executablePath;
    }
    return null;
  } catch (error) {
    writeJSONToStdout({
      success: false,
      error: "Error resolving Chromium executable",
      context: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
};

/**
 * Resolves Playwright browser executable path
 * Chromium is automatically installed via postinstall script during development.
 * In production, this resolves the bundled browser.
 * @param progressCallback - Optional callback function to report progress
 * @returns The executable path of the browser, or null if not found
 */
export const installPlaywright = async (
  _cacheDir: string,
  progressCallback?: InstallProgressCallback,
): Promise<string | null> => {
  try {
    if (progressCallback) {
      progressCallback({
        status: "resolving",
        message: "Resolving browser ...",
      });
    }

    const executablePath = resolveChromiumExecutable();
    if (executablePath && existsSync(executablePath)) {
      if (progressCallback) {
        progressCallback({
          status: "completed",
          message: "Browser ready.",
          progress: 100,
        });
      }
      return executablePath;
    }

    // Browser not found
    if (progressCallback) {
      progressCallback({
        status: "error",
        message:
          "Chromium not found. If you're in development mode, run 'bun install --frozen-lockfile' to install dependencies, otherwise, someone messed things up.",
      });
    }
    return null;
  } catch (error) {
    if (progressCallback) {
      progressCallback({
        status: "error",
        message: error instanceof Error ? error.message : String(error),
      });
    }
    return null;
  }
};
