import fs from "fs";
import path from "path";
import defaultTemplatePath from "../../../../templates/default.hbs" with { type: "file" };
import linuxTemplatePath from "../../../../templates/linux.hbs" with { type: "file" };
import macOSTemplatePath from "../../../../templates/macos.hbs" with { type: "file" };

import type { JSONObjectHTMLSuccessRequest } from "./../types";
import { JSONRequestTemplate } from "./../types";
import { HandlebarsGenerator } from "./../generators";

export const Template = async (
  html: string,
  json: JSONObjectHTMLSuccessRequest,
): Promise<string> => {
  let tpl: string;
  if (json.data.templateFilepath) {
    // User provided a custom template path
    const templateFilepath = path.resolve(json.data.templateFilepath);
    tpl = fs.readFileSync(templateFilepath, "utf-8");
  } else {
    // Use the embedded default template
    switch (json.data.template) {
      case JSONRequestTemplate.Linux:
        tpl = await Bun.file(linuxTemplatePath).text();
        break;
      case JSONRequestTemplate.MacOS:
        tpl = await Bun.file(macOSTemplatePath).text();
        break;
      default:
        tpl = await Bun.file(defaultTemplatePath).text();
        break;
    }
  }

  return (
    HandlebarsGenerator(tpl, {
      code: html,
      fontSettings: json.data.fontSettings,
      theme: json.data.theme,
      minWidth: json.data.minWidth,
      data: { ...json.data.additionalTemplateData },
    }) ?? ""
  );
};
