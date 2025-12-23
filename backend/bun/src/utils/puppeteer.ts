import { mkdir } from "node:fs/promises";
import path from "node:path";
import puppeteer from "puppeteer";
import os from "node:os";
import { existsSync } from "node:fs";
import {
  Browser,
  BrowserPlatform,
  BrowserTag,
  Cache,
  computeExecutablePath,
  install,
  resolveBuildId,
} from "@puppeteer/browsers";
import { writeJSONToStdout } from "./stdin";

/**
 * Gets the executable path for the installed Chrome browser.
 * @param cacheDir - The cache directory where browsers are stored
 * @returns The executable path, or null if not found
 */
const getInstalledBrowserPath = (cacheDir: string): string | null => {
  try {
    const platformMap: Record<string, BrowserPlatform> = {
      win32: BrowserPlatform.WIN32,
      darwin: BrowserPlatform.MAC,
      linux: BrowserPlatform.LINUX,
    };

    const currentPlatform = process.platform;
    const browserPlatform =
      platformMap[currentPlatform] || BrowserPlatform.LINUX;

    // Try to get the latest installed browser
    const cache = new Cache(cacheDir);
    const installedBrowsers = cache.getInstalledBrowsers();
    const chromeBrowser = installedBrowsers.find(
      (b) => b.browser === Browser.CHROME && b.platform === browserPlatform,
    );

    if (chromeBrowser) {
      return computeExecutablePath({
        cacheDir: cacheDir,
        browser: Browser.CHROME,
        platform: browserPlatform,
        buildId: chromeBrowser.buildId,
      });
    }

    return null;
  } catch (/* eslint-disable-line */ error) {
    return null;
  }
};

/**
 * Sets up Puppeteer cache directory and ensures browser is installed.
 * This is necessary when running in a bundled binary where the default
 * cache path might not be accessible.
 * Uses platform-specific default cache directories:
 * - Windows: %LOCALAPPDATA%\puppeteer
 * - macOS: ~/Library/Caches/puppeteer
 * - Linux: ~/.cache/puppeteer
 * @returns The executable path of the installed browser, or null if not found
 */
export const setupPuppeteer = async (): Promise<string | null> => {
  // Use platform-specific default cache directory
  const cacheDir = path.join(os.homedir(), ".cache", "puppeteer");

  // Ensure the cache directory exists
  await mkdir(cacheDir, { recursive: true });

  // Check if browser is installed
  let executablePath: string | null = null;
  let needsInstall = false;

  // First, try to get the executable path from installed browsers
  executablePath = getInstalledBrowserPath(cacheDir);

  // If not found, try Puppeteer's method
  if (!executablePath) {
    try {
      executablePath = puppeteer.executablePath();
      // Check if the executable actually exists
      if (!executablePath || !existsSync(executablePath)) {
        needsInstall = true;
      }
    } catch (/* eslint-disable-line */ error: unknown) {
      // Browser is not installed, we'll try to install it below
      needsInstall = true;
    }
  }

  if (needsInstall) {
    try {
      const platformMap: Record<string, BrowserPlatform> = {
        win32: BrowserPlatform.WIN32,
        darwin: BrowserPlatform.MAC,
        linux: BrowserPlatform.LINUX,
      };

      const currentPlatform = process.platform;
      const browserPlatform =
        platformMap[currentPlatform] || BrowserPlatform.LINUX;

      const buildId = await resolveBuildId(
        Browser.CHROME,
        browserPlatform,
        BrowserTag.LATEST,
      );

      // Install the browser with the correct buildId
      // This may take 30-60 seconds, so ensure timeout is set appropriately
      await install({
        browser: Browser.CHROME,
        buildId: buildId,
        cacheDir: cacheDir,
      });

      // After installation, get the executable path
      executablePath = computeExecutablePath({
        cacheDir: cacheDir,
        browser: Browser.CHROME,
        platform: browserPlatform,
        buildId: buildId,
      });
    } catch (installError) {
      writeJSONToStdout({
        success: false,
        error: "Error installing Chrome browser",
        context:
          installError instanceof Error
            ? installError.message
            : String(installError),
      });
    }
  }

  return executablePath;
};
