import puppeteer from "puppeteer";
import type { ScreenshotOptions, LaunchOptions } from "puppeteer";

export interface HtmlToImageOptions {
  html: string;
  output?: string;
  transparent?: boolean;
  type?: "png" | "jpeg" | "webp";
  quality?: number;
  waitUntil?: "load" | "domcontentloaded" | "networkidle0" | "networkidle2";
  executablePath?: string | null;
}

/**
 * Converts HTML to an image using Puppeteer.
 * @param options - Configuration options for the image generation
 * @returns Buffer containing the image data
 */
export async function htmlToImage(
  options: HtmlToImageOptions,
): Promise<Buffer> {
  const {
    html,
    output,
    transparent = false,
    type = "png",
    quality = 90,
    waitUntil = "networkidle2",
    executablePath,
  } = options;

  // Launch browser with appropriate settings
  const launchOptions: LaunchOptions = {
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
    ],
  };

  // If executable path is provided, use it explicitly
  if (executablePath) {
    launchOptions.executablePath = executablePath;
  }

  const browser = await puppeteer.launch(launchOptions);

  try {
    const page = await browser.newPage();

    // Set content with HTML
    await page.setContent(html, {
      waitUntil: waitUntil,
    });

    // Configure screenshot options
    const screenshotOptions: ScreenshotOptions = {
      type: type,
      fullPage: true,
      omitBackground: transparent,
    };

    // Add quality for JPEG/WebP
    if (type === "jpeg" || type === "webp") {
      screenshotOptions.quality = quality;
    }

    // Take screenshot - get buffer directly for efficiency
    const screenshotBuffer = await page.screenshot({
      ...screenshotOptions,
      ...(output && { path: output }),
    });

    // Convert to Buffer if needed
    const buffer =
      screenshotBuffer instanceof Buffer
        ? screenshotBuffer
        : Buffer.from(screenshotBuffer);

    return buffer;
  } finally {
    await browser.close();
  }
}
