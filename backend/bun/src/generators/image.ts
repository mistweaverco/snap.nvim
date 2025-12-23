import fs from "fs";
import nodeHtmlToImage from "node-html-to-image";

import type {
  JSONObjectHTMLSuccessRequest,
  JSONObjectImageSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./../types";
import { HTMLGenerator } from ".";
import { getFullOutputPath } from "../utils/file";

export const ImageGenerator = async (
  json: JSONObjectImageSuccessRequest,
): Promise<[NodeHTMLToImageBuffer, string]> => {
  // HTMLGenerator already handles font size conversion and generates the HTML
  const code = await HTMLGenerator(
    json as unknown as JSONObjectHTMLSuccessRequest,
  );

  const outputFilepath = await getFullOutputPath(
    json.data.outputDir,
    json.data.filename,
    json.data.filenamePattern,
  );

  const filepath = outputFilepath + "." + json.data.outputImageFormat;
  // The HTML is already fully generated with correct font sizes, so we just pass it to nodeHtmlToImage
  return [
    await nodeHtmlToImage({
      output: filepath,
      html: code,
      transparent: json.data.transparent,
      type: json.data.outputImageFormat,
    }),
    filepath,
  ];
};
