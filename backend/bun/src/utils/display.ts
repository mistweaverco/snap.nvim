import type { JSONObjectSuccessRequest } from "../types";

/**
 * Converts points (pt) to pixels (px)
 * @param pt - The value in points
 * @param dpi - Dots per inch (default: 96)
 * @returns The value in pixels
 */
export const ptToPx = (pt: number, dpi: number = 96): number => {
  return pt * (dpi / 72);
};

/**
 * Converts pixels (px) to points (pt)
 * @param px - The value in pixels
 * @param dpi - Dots per inch (default: 96)
 * @returns The value in points
 */
export const pxToPt = (px: number, dpi: number = 96): number => {
  return px * (72 / dpi);
};

/**
 * Converts font settings (size and line_height) from pixels to points
 * @param json - JSON payload containing fontSettings
 * @param dpi - Dots per inch (default: 96)
 * @returns Object with size and line_height converted to points
 */
export const fontSettingsToPt = (
  json: JSONObjectSuccessRequest,
  dpi: number = 96,
): { size: number; line_height: number } => {
  return {
    size: pxToPt(json.data.fontSettings.size, dpi),
    line_height: pxToPt(json.data.fontSettings.line_height, dpi),
  };
};

/**
 * Converts font settings (size and line_height) from points to pixels
 * @param json - JSON payload containing fontSettings
 * @param dpi - Dots per inch (default: 96)
 * @returns Object with size and line_height converted to pixels
 */
export const fontSettingsToPx = (
  json: JSONObjectSuccessRequest,
  dpi: number = 96,
): { size: number; line_height: number } => {
  return {
    size: ptToPx(json.data.fontSettings.size, dpi),
    line_height: ptToPx(json.data.fontSettings.line_height, dpi),
  };
};
