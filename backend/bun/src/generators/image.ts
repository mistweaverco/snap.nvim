import fs from "fs";
import path from "path";
import nodeHtmlToImage from "node-html-to-image";
import defaultTemplatePath from "../../../../templates/default.hbs" with { type: "file" };
import linuxTemplatePath from "../../../../templates/linux.hbs" with { type: "file" };
import macOSTemplatePath from "../../../../templates/macos.hbs" with { type: "file" };

import type {
  JSONObjectImageSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./../types";
import { JSONRequestTemplate } from "./../types";
import { HandlebarsGenerator, HTMLGenerator } from ".";

export const ImageGenerator = async (
  json: JSONObjectImageSuccessRequest,
): Promise<NodeHTMLToImageBuffer> => {
  let html: string;
  if (json.data.templateFilepath) {
    // User provided a custom template path
    const templateFilepath = path.resolve(json.data.templateFilepath);
    html = fs.readFileSync(templateFilepath, "utf-8");
  } else {
    // Use the embedded default template
    switch (json.data.template) {
      case JSONRequestTemplate.Linux:
        html = await Bun.file(linuxTemplatePath).text();
        break;
      case JSONRequestTemplate.MacOS:
        html = await Bun.file(macOSTemplatePath).text();
        break;
      default:
        html = await Bun.file(defaultTemplatePath).text();
        break;
    }
  }

  const code = HTMLGenerator(json.data.code);

  if (json.debug) {
    HandlebarsGenerator(
      html,
      {
        code: code,
        fontSettings: json.data.fontSettings,
        theme: json.data.theme,
        minWidth: json.data.minWidth,
        data: { ...json.data.additionalTemplateData },
      },
      json.data.filepath.replace(
        new RegExp(`.${json.data.outputImageFormat}$`),
        `_debug.html`,
      ),
    );
  }

  return await nodeHtmlToImage({
    output: json.data.filepath,
    html: html,
    content: {
      code,
      fontSettings: json.data.fontSettings,
      theme: json.data.theme,
      minWidth: json.data.minWidth,
      data: { ...json.data.additionalTemplateData },
    },
    transparent: json.data.transparent,
    type: json.data.outputImageFormat,
  });
};
