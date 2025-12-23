import fs from "fs";
import nodeHtmlToImage from "node-html-to-image";

import type {
  JSONObjectHTMLSuccessRequest,
  JSONObjectImageSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./../types";
import { HTMLGenerator } from ".";

export const ImageGenerator = async (
  json: JSONObjectImageSuccessRequest,
): Promise<NodeHTMLToImageBuffer> => {
  // HTMLGenerator already handles font size conversion and generates the HTML
  const code = await HTMLGenerator(
    json as unknown as JSONObjectHTMLSuccessRequest,
  );

  // NOTE:
  // For debugging purposes, we write the generated HTML to a file
  // so that developers can inspect it if needed.
  if (json.debug) {
    fs.writeFileSync(
      json.data.filepath.replace(/\.(png|jpeg|jpg)$/, "_debug.html"),
      code,
      { encoding: "utf-8" },
    );
  }

  // The HTML is already fully generated with correct font sizes, so we just pass it to nodeHtmlToImage
  return await nodeHtmlToImage({
    output: json.data.filepath,
    html: code,
    transparent: json.data.transparent,
    type: json.data.outputImageFormat,
  });
};
