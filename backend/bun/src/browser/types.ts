export interface BrowserOptions {
  puppeteerArgs?: Record<string, unknown>;
  timeout?: number;
  callback: (...args: unknown[]) => Promise<void>;
}

export interface BrowserScreenshotOptions {
  html?: string;
  encoding?: string;
  transparent?: boolean;
  content: Record<string, unknown> | Array<Record<string, unknown>>;
  output?: string;
  selector?: string;
  type?: "png" | "jpeg" | "webp";
  quality?: number;
  puppeteerArgs?: Record<string, unknown>;
  timeout?: number;
}
