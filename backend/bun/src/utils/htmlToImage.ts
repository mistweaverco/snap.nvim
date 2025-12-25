// Use dynamic import for playwright-core to avoid bundling issues
// This allows playwright-core to be loaded at runtime from node_modules
import type { Page } from "playwright-core";

export interface HtmlToImageOptions {
  html: string;
  output?: string;
  transparent?: boolean;
  type?: "png" | "jpeg";
  quality?: number;
  waitUntil?: "load" | "domcontentloaded" | "networkidle" | "commit";
  executablePath?: string | null;
}

/**
 * Dynamically loads playwright-core at runtime
 * due to dynamic imports and native dependencies
 */
async function loadPlaywright() {
  const path = await import("node:path");
  const fs = await import("node:fs");

  // For compiled binaries, playwright-core should be in node_modules relative to the executable
  // Try bundled location first (for production builds)
  if (process.execPath) {
    const execDir = path.dirname(process.execPath);
    const bundledPath = path.join(execDir, "node_modules", "playwright-core");

    if (fs.existsSync(bundledPath)) {
      try {
        // Use file:// URL for absolute path import
        const playwright = await import(path.resolve(bundledPath));
        return playwright.chromium;
      } catch (error) {
        // Fall through to standard import
      }
    }
  }

  // Try standard import (works for development and if node_modules is in module resolution path)
  try {
    const playwright = await import("playwright-core");
    return playwright.chromium;
  } catch (error) {
    throw new Error(
      `Failed to load playwright-core: ${error instanceof Error ? error.message : String(error)}. ` +
        "Make sure playwright-core is installed or bundled with the application in node_modules/playwright-core.",
    );
  }
}

/**
 * Converts HTML to an image using Playwright.
 * @param options - Configuration options for the image generation
 * @returns Buffer containing the image data
 */
export async function htmlToImage(options: HtmlToImageOptions): Promise<Buffer> {
  const {
    html,
    output,
    transparent = false,
    type = "png",
    quality = 90,
    waitUntil = "networkidle",
    executablePath,
  } = options;

  // Dynamically load playwright-core
  const chromium = await loadPlaywright();

  // Launch browser with appropriate settings
  const launchOptions: Parameters<typeof chromium.launch>[0] = {
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage", "--disable-gpu"],
  };

  // If executable path is provided, use it explicitly
  if (executablePath) {
    launchOptions.executablePath = executablePath;
  }

  const browser = await chromium.launch(launchOptions);

  try {
    const page = await browser.newPage();

    // Set content with HTML
    await page.setContent(html, {
      waitUntil: waitUntil as "load" | "domcontentloaded" | "networkidle" | "commit",
    });

    // Measure the actual rendered content width to respect max-width constraints
    // This ensures we capture only the content width, not the full viewport
    // The max-width is set on the body container, so we measure that
    const contentDimensions = await page.evaluate(() => {
      const body = document.body;

      // Get the actual rendered dimensions of the body
      // Use getBoundingClientRect() which respects CSS max-width
      const bodyRect = body.getBoundingClientRect();

      // Use body dimensions which respect max-width constraints
      const width = bodyRect.width;
      const height = bodyRect.top + bodyRect.height;

      return {
        width: Math.ceil(width),
        height: Math.ceil(height),
      };
    });

    // Set viewport to match the actual content dimensions
    // Add a small buffer to ensure we capture everything
    await page.setViewportSize({
      width: contentDimensions.width + 1,
      height: contentDimensions.height + 1,
    });

    // Wait a bit for the viewport change to settle
    await page.waitForTimeout(100);

    // Configure screenshot options using the correct type from Page.screenshot
    type ScreenshotOptions = Parameters<Page["screenshot"]>[0];
    const screenshotOptions: ScreenshotOptions = {
      type: type,
      fullPage: true,
      omitBackground: transparent,
    };

    // Add quality for JPEG
    if (type === "jpeg") {
      screenshotOptions.quality = quality;
    }

    // Take screenshot - get buffer directly for efficiency
    const screenshotBuffer = await page.screenshot({
      ...screenshotOptions,
      ...(output && { path: output }),
    });

    // Convert to Buffer if needed
    const buffer = screenshotBuffer instanceof Buffer ? screenshotBuffer : Buffer.from(screenshotBuffer);

    return buffer;
  } finally {
    await browser.close();
  }
}
