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
 * Progress callback type for install operations
 */
export type InstallProgressCallback = (progress: {
  status: string;
  message: string;
  progress?: number;
}) => void;

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
 * @returns The executable path of the installed browser, or null if not found
 */
export const setupPuppeteer = async (): Promise<string | null> => {
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

/**
 * Checks if Puppeteer browser is installed
 * @param cacheDir - The cache directory where browsers are stored
 * @returns Object with isInstalled boolean and executablePath if installed
 */
export const checkPuppeteerInstalled = (
  cacheDir: string,
): { isInstalled: boolean; executablePath: string | null } => {
  try {
    const executablePath = getInstalledBrowserPath(cacheDir);
    if (executablePath && existsSync(executablePath)) {
      return { isInstalled: true, executablePath };
    }

    try {
      const puppeteerPath = puppeteer.executablePath();
      if (puppeteerPath && existsSync(puppeteerPath)) {
        return { isInstalled: true, executablePath: puppeteerPath };
      }
    } catch (/* eslint-disable-line */ error) {
      // Browser is not installed
    }

    return { isInstalled: false, executablePath: null };
  } catch (/* eslint-disable-line */ error) {
    return { isInstalled: false, executablePath: null };
  }
};

/**
 * Installs Puppeteer browser with progress updates
 * @param cacheDir - The cache directory where browsers are stored
 * @param progressCallback - Callback function to report progress
 * @returns The executable path of the installed browser, or null if installation failed
 */
export const installPuppeteer = async (
  cacheDir: string,
  progressCallback?: InstallProgressCallback,
): Promise<string | null> => {
  try {
    await mkdir(cacheDir, { recursive: true });

    const platformMap: Record<string, BrowserPlatform> = {
      win32: BrowserPlatform.WIN32,
      darwin: BrowserPlatform.MAC,
      linux: BrowserPlatform.LINUX,
    };

    const currentPlatform = process.platform;
    const browserPlatform =
      platformMap[currentPlatform] || BrowserPlatform.LINUX;

    if (progressCallback) {
      progressCallback({
        status: "resolving",
        message: "Resolving requirements ...",
      });
    }

    const buildId = await resolveBuildId(
      Browser.CHROME,
      browserPlatform,
      BrowserTag.LATEST,
    );

    if (progressCallback) {
      progressCallback({
        status: "installing",
        message: `Installing requirements ...`,
        progress: 0,
      });
    }

    const installStartTime = Date.now();
    let periodicUpdateInterval: NodeJS.Timeout | null = null;
    let isInstalling = true;

    if (progressCallback) {
      periodicUpdateInterval = setInterval(() => {
        if (!isInstalling || !progressCallback) {
          return;
        }

        const elapsedSeconds = Math.floor(
          (Date.now() - installStartTime) / 1000,
        );

        progressCallback({
          status: "installing",
          message: `Still installing ... (${elapsedSeconds}s elapsed)`,
          progress: undefined,
        });
      }, 5000);
    }

    try {
      await install({
        browser: Browser.CHROME,
        buildId: buildId,
        cacheDir: cacheDir,
      });

      isInstalling = false;
      if (periodicUpdateInterval) {
        clearInterval(periodicUpdateInterval);
        periodicUpdateInterval = null;
      }
    } catch (installErr) {
      isInstalling = false;
      if (periodicUpdateInterval) {
        clearInterval(periodicUpdateInterval);
        periodicUpdateInterval = null;
      }
      throw installErr;
    }

    if (progressCallback) {
      progressCallback({
        status: "completed",
        message: "Requirements installed successfully.",
        progress: 100,
      });
    }

    const executablePath = computeExecutablePath({
      cacheDir: cacheDir,
      browser: Browser.CHROME,
      platform: browserPlatform,
      buildId: buildId,
    });

    return executablePath;
  } catch (installError) {
    if (progressCallback) {
      progressCallback({
        status: "error",
        message:
          installError instanceof Error
            ? installError.message
            : String(installError),
      });
    }
    return null;
  }
};
