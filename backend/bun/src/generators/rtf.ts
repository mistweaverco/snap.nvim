import fs from "fs";
import type {
  JSONObjectCodeLine,
  JSONObjectRTFSuccessRequest,
} from "./../types";
import { getFullOutputPath } from "../utils/file";

let colorTable: string[] = [];

const buildColorTable = (json: JSONObjectRTFSuccessRequest): string[] => {
  const colors = new Set<string>();
  // Always include defaults in the table
  colors.add(json.data.theme.fgColor);
  colors.add(json.data.theme.bgColor);

  json.data.code.flat().forEach((seg) => {
    if (seg.fg) colors.add(seg.fg);
    if (seg.bg) colors.add(seg.bg);
  });
  return Array.from(colors);
};

const generateFontTable = (json: JSONObjectRTFSuccessRequest): string => {
  return `{\\fonttbl{\\f0 ${json.data.fontSettings.fonts.default.name};}{\\f1 ${json.data.fontSettings.fonts.italic.name};}{\\f2 ${json.data.fontSettings.fonts.bold.name};}{\\f3 ${json.data.fontSettings.fonts.bold_italic.name};}}`;
};

const generateColorTable = (): string => {
  let table = "{\\colortbl ;";
  colorTable.forEach((hex) => {
    const { r, g, b } = hexToRgb(hex);
    table += `\\red${r}\\green${g}\\blue${b};`;
  });
  table += "}";
  return table;
};

const processLine = (line: JSONObjectCodeLine[]): string => {
  return line
    .map((seg) => {
      const fgIdx = colorTable.indexOf(seg.fg) + 1;
      const bgIdx = colorTable.indexOf(seg.bg) + 1;

      let rtfSeg = "{";

      if (seg.bold && seg.italic) rtfSeg += "\\f3";
      else if (seg.italic) rtfSeg += "\\f1";
      else rtfSeg += "\\f0";

      if (fgIdx > 0) rtfSeg += `\\cf${fgIdx}`;
      if (bgIdx > 0) rtfSeg += `\\highlight${bgIdx}`;

      // Apply text styles
      if (seg.bold) rtfSeg += "\\b";
      if (seg.italic) rtfSeg += "\\i";
      if (seg.underline) rtfSeg += "\\ul";

      const escapedText = seg.text
        .replace(/\\/g, "\\\\")
        .replace(/{/g, "\\{")
        .replace(/}/g, "\\}");

      rtfSeg += ` ${escapedText}`;

      // Reset styles
      if (seg.underline) rtfSeg += "\\ul0";
      if (seg.italic) rtfSeg += "\\i0";
      if (seg.bold) rtfSeg += "\\b0";

      rtfSeg += "}";

      return rtfSeg;
    })
    .join("");
};

const hexToRgb = (hex: string): { r: number; g: number; b: number } => {
  const cleanHex = hex.replace("#", "");
  const bigint = parseInt(cleanHex, 16);
  return {
    r: (bigint >> 16) & 255,
    g: (bigint >> 8) & 255,
    b: bigint & 255,
  };
};

/**
 * Converts pixels to points based on standard 96 DPI.
 * Formula: pt = px * (72 / 96)
 */
function pxToPt(px: number): number {
  return px * 0.75;
}

/**
 * Converts pixels to twips assuming 96 DPI.
 * @param px The value in pixels.
 * @returns The value in twips.
 */
function pxToTwips(px: number): number {
  const TWIPS_PER_PIXEL = 15; // (1440 twips per inch / 96 pixels per inch)
  return px * TWIPS_PER_PIXEL;
}

export const RTFGenerator = async (
  json: JSONObjectRTFSuccessRequest,
): Promise<[string, string]> => {
  colorTable = buildColorTable(json);

  // Global document settings: font size (\fs), line height (\sl),
  // and default colors (\cf / \highlight)
  const fgIdx = colorTable.indexOf(json.data.theme.fgColor) + 1;
  const bgIdx = colorTable.indexOf(json.data.theme.bgColor) + 1;
  const margin = 0;
  // \paperw: Paper width in twips
  // \margl / \margr: Left and Right margins
  const headerSettings = `\\paperw${pxToTwips(
    json.data.minWidth,
  )}\\margl${margin}\\margr${margin}\\viewkind4`;
  const docDefaults = `\\f0\\fs${pxToPt(json.data.fontSettings.size) * 2}\\sl${pxToTwips(
    json.data.fontSettings.line_height,
  )}\\slmult1\\cf${fgIdx}\\highlight${bgIdx}\\cbpat${bgIdx}`;

  const body = json.data.code.map((line) => processLine(line)).join("\\line\n");
  // Using  for standard page view and adding a trailing \par
  const doc = `{\\rtf1\\ansi\\deff0\n${headerSettings}\n${generateFontTable(
    json,
  )}\n${generateColorTable()}\n${docDefaults}\n${body}\\par\n}`;

  const outputFilepath = await getFullOutputPath(
    json.data.outputDir,
    json.data.filename,
    json.data.filenamePattern,
  );

  const filepath = outputFilepath + ".rtf";

  fs.writeFileSync(filepath, doc, { encoding: "utf-8" });
  return [doc, filepath];
};
