import fs from "fs";
import Handlebars from "handlebars";
import type { JSONObjectCodeLine } from "./../types";

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

export const HTMLGenerator = (rows: Array<JSONObjectCodeLine[]>): string => {
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
          return `<span style="color: ${segment.fg}; background-color: ${segment.bg};">${segmentHTML}</span>`;
        })
        .join("");
    })
    .map((line) =>
      line.trim() === ""
        ? `<div class="code-line">&nbsp;</div>`
        : `<div class="code-line">${line}</div>`,
    )
    .join("\n");
};
