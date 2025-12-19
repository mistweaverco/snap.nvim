import fs from "fs";
import path from "path";
import Handlebars from "handlebars";
import nodeHtmlToImage from "node-html-to-image";
import defaultTemplatePath from "../../../templates/default.hbs" with { type: "file" };
import linuxTemplatePath from "../../../templates/linux.hbs" with { type: "file" };
import macOSTemplatePath from "../../../templates/macos.hbs" with { type: "file" };
import {
  Clipboard,
  getJSONFromStdin,
  type JSONObjectCodeLine,
  type JSONObjectHTMLSuccessRequest,
  type JSONObjectImageSuccessRequest,
  JSONRequestTemplate,
  JSONRequestType,
  type NodeHTMLToImageBuffer,
  writeJSONToStdout,
} from "./utils";

const assembleCodeLines = (rows: Array<JSONObjectCodeLine[]>): string[] => {
  return rows
    .map((line) => {
      return line
        .map((segment) => {
          let segmentHTML = segment.text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
          if (segment.bold) {
            segmentHTML = `<b>${segmentHTML}</b>`;
          }
          if (segment.italic) {
            segmentHTML = `<i>${segmentHTML}</i>`;
          }
          if (segment.underline) {
            segmentHTML = `<u>${segmentHTML}</u>`;
          }
          return segmentHTML;
        })
        .join("");
    })
    .map((line) => (line.trim() === "" ? "&nbsp;" : line))
    .map((line) => `<div class="code-line">${line}</div>`);
};

const main = async () => {
  const jsonPayload = await getJSONFromStdin();

  if ("error" in jsonPayload) {
    writeJSONToStdout({
      success: false,
      error: jsonPayload.error,
    });
    return;
  }

  let html: string;

  if (jsonPayload.data.templateFilepath) {
    // User provided a custom template path
    const templateFilepath = path.resolve(jsonPayload.data.templateFilepath);
    html = fs.readFileSync(templateFilepath, "utf-8");
  } else {
    // Use the embedded default template
    switch (jsonPayload.data.template) {
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
  let json: JSONObjectImageSuccessRequest | JSONObjectHTMLSuccessRequest;

  let buffer: NodeHTMLToImageBuffer;
  const code = assembleCodeLines(jsonPayload.data.code);

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
    Clipboard.write(buffer, "image/png");
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
