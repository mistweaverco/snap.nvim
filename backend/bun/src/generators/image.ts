import type {
  JSONObjectHTMLSuccessRequest,
  JSONObjectImageSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./../types";
import { HTMLGenerator } from ".";
import { getFullOutputPath } from "../utils/file";
import { setupPuppeteer } from "../utils/puppeteer";
import { htmlToImage } from "../utils/htmlToImage";

export const ImageGenerator = async (
  json: JSONObjectImageSuccessRequest,
): Promise<[NodeHTMLToImageBuffer, string]> => {
  // Setup Puppeteer cache directory and ensure browser is installed
  // This must be done before generating the image
  // Returns the executable path if browser was installed
  const executablePath = await setupPuppeteer();

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
  // Convert HTML to image using our custom Puppeteer implementation
  // Pass the executable path explicitly to ensure Puppeteer uses the installed browser
  const buffer = await htmlToImage({
    output: filepath,
    html: code,
    transparent: json.data.transparent,
    type: json.data.outputImageFormat,
    executablePath: executablePath,
  });

  return [buffer, filepath];
};
