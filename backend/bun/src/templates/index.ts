import fs from "fs";
import path from "path";
import defaultTemplatePath from "../../../../templates/default.hbs" with { type: "file" };
import linuxTemplatePath from "../../../../templates/linux.hbs" with { type: "file" };
import macOSTemplatePath from "../../../../templates/macos.hbs" with { type: "file" };
import logoPath from "../../../../assets/logo.svg" with { type: "file" };

import type { JSONObjectHTMLSuccessRequest } from "./../types";
import { JSONRequestTemplate } from "./../types";
import { HandlebarsGenerator } from "./../generators";
import { FontGenerator } from "../generators/font";
import { ptToPx } from "../utils/display";

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

  const data = {
    ...json.data.additionalTemplateData,
  };

  const dpi = json.data.dpi ?? 96;

  // Font size is in points (matching terminal configs like wezterm)
  // Keep it in points - CSS will handle the rendering
  const fontSizePt = json.data.fontSettings.size;
  // No conversion needed - keep in points

  // Line-height: pass through as-is, templates will add 'pt' suffix

  const fontFaceDeclarations =
    await FontGenerator.getFontFaceDeclarationsFromJSONPayload(json);

  // minWidth calculation: minWidth is calculated in Lua assuming font_size is in pixels,
  // but font_size is in points. We need to scale minWidth by pt-to-px ratio.
  // The Lua calculation uses: minWidth = longest_line_len * font_size * 0.6 + padding
  // If font_size is 14pt but treated as 14px, we need to scale by ptToPx(14pt, dpi) / 14
  const fontSizePx = ptToPx(fontSizePt, dpi);
  const ptToPxRatio = fontSizePx / fontSizePt; // This equals dpi / 72
  const adjustedMinWidth = json.data.minWidth * ptToPxRatio;

  // Load logo SVG
  const logo = await Bun.file(logoPath).text();

  return (
    HandlebarsGenerator(tpl, {
      code: html,
      fontSettings: json.data.fontSettings,
      fontFaceDeclarations,
      theme: json.data.theme,
      minWidth: adjustedMinWidth,
      tabstop: json.data.tabstop ?? 4,
      logo,
      data,
    }) ?? ""
  );
};
