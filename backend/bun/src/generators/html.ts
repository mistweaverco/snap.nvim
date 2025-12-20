import fs from "fs";
import Handlebars from "handlebars";
import type { JSONObjectHTMLSuccessRequest } from "./../types";
import { Template } from "../templates";

export const HandlebarsGenerator = (
  html: string,
  data: unknown,
  writeFile: false | string = false,
): string | null => {
  const hb = Handlebars.compile(html);
  if (writeFile === false) {
    return hb(data);
  } else {
    fs.writeFileSync(writeFile, hb(data), { encoding: "utf-8" });
    return null;
  }
};

/**
 * Escapes HTML special characters in a string
 * @param str - Input string
 * @returns Escaped string
 */
const escapeHTML = (str: string): string => {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/{/g, "&#123;")
    .replace(/}/g, "&#125;");
};

const unescapeHTML = (str: string): string => {
  return str.replace(/&#123;/g, "{").replace(/&#125;/g, "}");
};

/**
 * Generates HTML from JSON representation of code snippet
 * and writes it to specified filepath.
 * @param json - JSON payload from the request
 * @returns Generated HTML as a string
 */
export const HTMLGenerator = async (
  json: JSONObjectHTMLSuccessRequest,
): Promise<string> => {
  const html = json.data.code
    .map((line) => {
      return line
        .map((segment) => {
          let segmentHTML = escapeHTML(segment.text);
          if (segment.bold) {
            segmentHTML = `<b>${segmentHTML}</b>`;
          }
          if (segment.italic) {
            segmentHTML = `<i>${segmentHTML}</i>`;
          }
          if (segment.underline) {
            segmentHTML = `<u>${segmentHTML}</u>`;
          }
          return `<span style="color: ${segment.fg}; background-color: ${segment.bg};" data-hl="${segment.hl_name}">${segmentHTML}</span>`;
        })
        .join("");
    })
    .map((line) =>
      line.trim() === ""
        ? `<div class="code-line">&nbsp;</div>`
        : `<div class="code-line">${line}</div>`,
    )
    .join("\n");
  const template = await Template(unescapeHTML(html), json);
  fs.writeFileSync(json.data.filepath, template, {
    encoding: "utf-8",
  });

  return template;
};
