import fs from "fs";
import path from "path";
import Handlebars from "handlebars";
import nodeHtmlToImage from "node-html-to-image";
import {
  copyBufferToClipboard,
  getJSONFromStdin,
  isSystemClipboardCommandAvailable,
  type JSONObjectHTMLSuccessRequest,
  type JSONObjectImageSuccessRequest,
  JSONRequestType,
  type NodeHTMLToImageBuffer,
  writeJSONToStdout,
} from "./utils";

const main = async () => {
  const jsonPayload = await getJSONFromStdin();
  if ("error" in jsonPayload) {
    writeJSONToStdout({
      success: false,
      error: jsonPayload.error,
    });
    return;
  }

  const clipboardCheck = isSystemClipboardCommandAvailable(
    jsonPayload.data.type,
  );
  if (!clipboardCheck.success) {
    console.error(clipboardCheck.errorMessage);
    return;
  }

  let templateFilepath = path.resolve(
    __dirname,
    "..",
    "..",
    "..",
    "templates",
    "default.hbs",
  );

  if (jsonPayload.data.templateFilepath) {
    templateFilepath = path.resolve(jsonPayload.data.templateFilepath);
  }

  const html = fs.readFileSync(templateFilepath, "utf-8");
  let json: JSONObjectImageSuccessRequest | JSONObjectHTMLSuccessRequest;

  let buffer: NodeHTMLToImageBuffer;
  const code = jsonPayload.data.code.map((line) => {
    if (line.trim() === "") {
      return `<div class="snap-code-line">&nbsp;</div>`;
    }
    return `<div class="snap-code-line">${line}</div>`;
  }).join("\n");

  switch (jsonPayload.data.type) {
    case JSONRequestType.CodeImageGeneration:
      json = jsonPayload as JSONObjectImageSuccessRequest;
      buffer = await nodeHtmlToImage({
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
      break;
    default:
      json = jsonPayload as JSONObjectHTMLSuccessRequest;
      writeJSONToStdout({
        success: false,
        error: `Unsupported request type: ${json.data.type}`,
      });
      // TODO: Implement HTML generation logic
      buffer = Buffer.from("");
  }

  if (buffer && json.data.toClipboard) {
    copyBufferToClipboard(buffer, json.data.type);
  }

  if (
    json.debug &&
    buffer &&
    json.data.type === JSONRequestType.CodeImageGeneration
  ) {
    const re = new RegExp(`.${json.data.outputImageFormat}$`);
    const hb = Handlebars.compile(html);
    fs.writeFileSync(
      json.data.filepath.replace(re, `_debug.html`),
      hb({
        code: code,
        fontSettings: json.data.fontSettings,
        theme: json.data.theme,
        minWidth: json.data.minWidth,
        data: { ...json.data.additionalTemplateData },
      }),
      { encoding: "utf-8" },
    );
  }

  writeJSONToStdout({
    success: true,
    debug: json.debug,
    data: json.data,
  });
};

main();
