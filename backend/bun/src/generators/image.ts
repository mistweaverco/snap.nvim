import type {
  JSONObjectHTMLSuccessRequest,
  JSONObjectImageSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./../types";
import { HTMLGenerator } from ".";
import { getFullOutputPath } from "../utils/file";
import { setupPlaywright } from "../utils/playwright";
import { htmlToImage } from "../utils/htmlToImage";

export const ImageGenerator = async (
  json: JSONObjectImageSuccessRequest,
): Promise<[NodeHTMLToImageBuffer, string]> => {
  // Setup Playwright and ensure browser is available
  // This must be done before generating the image
  // Returns the executable path if browser was found
  const executablePath = await setupPlaywright();

  // HTMLGenerator already handles font size conversion and generates the HTML
  const [code] = await HTMLGenerator(
    json as unknown as JSONObjectHTMLSuccessRequest,
  );

  const outputFilepath = await getFullOutputPath(
    json.data.outputDir,
    json.data.filename,
    json.data.filenamePattern,
  );

  const filepath = outputFilepath + "." + json.data.outputImageFormat;
  // Convert HTML to image using our custom Playwright implementation
  // Pass the executable path explicitly to ensure Playwright uses the bundled browser
  const buffer = await htmlToImage({
    output: filepath,
    html: code,
    transparent: json.data.transparent,
    type: json.data.outputImageFormat,
    executablePath: executablePath,
  });

  return [buffer, filepath];
};
