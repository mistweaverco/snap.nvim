import { type BrowserOptions } from "./types";
import puppeteer from "puppeteer";

export async function Browser(options: BrowserOptions) {
  const { puppeteerArgs = {}, timeout = 30000, callback } = options;
  const browser = await puppeteer.launch({
    headless: false,
    timeout,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
    ...puppeteerArgs,
  });
  const context = browser.defaultBrowserContext();

  await context.overridePermissions("https://mistweaverco.com", [
    "clipboard-read",
    "clipboard-write",
    "clipboard-sanitized-write",
  ]);
  const page = await browser.newPage();
  page.setDefaultTimeout(300000);
  page.setDefaultNavigationTimeout(300000);
  await page.waitForNetworkIdle();
  await page.goto("https://mistweaverco.com");
  await page.bringToFront();
  await page.evaluate(callback);
  await page.waitForSelector("#app23");
  await browser.close();
}
