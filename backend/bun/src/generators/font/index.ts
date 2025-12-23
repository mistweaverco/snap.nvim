import fs from "fs";
import path from "path";
import { fileTypeFromBuffer, type FileTypeResult } from "file-type";

import { promiseMap, readAllFiles, readFileAsync } from "./helpers";
import {
  FontSettingsFonts,
  type JSONObjectHTMLSuccessRequest,
  type JSONObjectImageSuccessRequest,
} from "../../types";

const fontMap: { [key: string]: { mediaType: string; format: string } } = {
  ".svg": {
    mediaType: "image/svg+xml",
    format: "svg",
  },
  ".ttf": {
    mediaType: "font/truetype",
    format: "truetype",
  },
  ".otf": {
    mediaType: "font/opentype",
    format: "opentype",
  },
  ".eot": {
    mediaType: "application/vnd.ms-fontobject",
    format: "embedded-opentype",
  },
  ".woff2": {
    mediaType: "font/woff2",
    format: "woff2",
  },
  ".woff": {
    mediaType: "font/woff",
    format: "woff",
  },
};

type FileTypeMeta = FileTypeResult & { base64: string };

const buffToBase64 = (buff: Buffer) => buff.toString("base64");

const readBuffer = async (buff: Buffer) => {
  const base64 = buffToBase64(buff);
  const data = await fileTypeFromBuffer(buff);
  (data as FileTypeMeta).base64 = base64;
  return data as FileTypeMeta;
};

/**
 * INFO:
 * A data URI consists of data:[<media type>][;base64],<data>
 * https://en.wikipedia.org/wiki/Data_URI_scheme
 *
 * INFO:
 * # Font formats
 * svg   = svn:mime-type=image/svg+xml
 * ttf   = svn:mime-type=application/x-font-ttf
 * otf   = svn:mime-type=application/x-font-opentype
 * woff  = svn:mime-type=application/font-woff
 * woff2 = svn:mime-type=application/font-woff2
 * eot   = svn:mime-type=application/vnd.ms-fontobject
 * sfnt  = svn:mime-type=application/font-sfnt
 */
const _toDataUrl = (mediaType: string, base64: string) =>
  `data:${mediaType};charset=utf-8;base64,${base64}`;

const _toDataSrc = (dataUrl: string, format: string) =>
  `url(${dataUrl}) format('${format}')`;

const _getMeta = (fpath: string, ext: string) => {
  const naive = path.parse(fpath).ext;

  // INFO:
  // Seems unsupported by 'file-type' package
  // https://www.npmjs.com/package/file-type#supported-file-types
  if (naive === ".svg") return fontMap[naive];
  const type = (ext && `.${ext}`) || naive;
  return fontMap[type as string];
};

const toDataUrl = (fpath: string, { ext, base64 }: FileTypeMeta): string => {
  const meta = _getMeta(fpath, ext);
  const mediaType = meta ? meta.mediaType : "application/octet-stream";
  return _toDataUrl(mediaType, base64);
};

const toDataSrc = (
  fpath: string,
  { ext, base64 }: FileTypeMeta,
): string | null => {
  const meta = _getMeta(fpath, ext);
  if (!meta) return null;

  const mediaType = meta.mediaType;
  const format = meta.format;

  const dataUrl = _toDataUrl(mediaType, base64);
  return _toDataSrc(dataUrl, format);
};

export async function encodeToDataUrl(fpath: string): Promise<string>;
export async function encodeToDataUrl(fpath: string[]): Promise<string[]>;
export async function encodeToDataUrl(fpath: null): Promise<null>;
export async function encodeToDataUrl(
  fpath: string | string[] | null,
): Promise<string | string[] | null>;

export async function encodeToDataUrl(
  fpath: string | string[] | null,
): Promise<string | string[] | null> {
  if (!fpath) return null;
  if (Array.isArray(fpath)) {
    const results = await Promise.all(fpath.map((p) => encodeToDataUrl(p)));
    return results as string[];
  }
  const buff = fs.readFileSync(fpath);
  const data = await readBuffer(buff);
  return toDataSrc(fpath, data);
}

export async function encodeToDataSrc(fpath: string): Promise<string>;
export async function encodeToDataSrc(fpath: string[]): Promise<string[]>;

export async function encodeToDataSrc(
  fpath: string | string[],
): Promise<string | string[]> {
  if (Array.isArray(fpath)) {
    return Promise.all(fpath.map((path) => encodeToDataSrc(path)));
  }
  const buff = await readFileAsync(fpath);
  const data = await readBuffer(buff as Buffer);
  const dataSrc = toDataSrc(fpath, data);
  if (dataSrc === null) {
    return [];
  }
  return dataSrc;
}

export interface FontGeneratorFontFaceDeclaration {
  name: string;
  src: string;
}

export interface FontGeneratorFontFaceOptions {
  fonts: {
    name: string;
    file: string;
  }[];
}

const allowedFontExtensions = Object.keys(fontMap);

/**
 * Splits a long string into chunks and joins them with CSS line continuation (\ + newline)
 * @param str - The string to split
 * @param chunkSize - Size of each chunk (default: 76, common base64 line length)
 * @returns The string with line continuations inserted
 */
const splitWithLineContinuation = (
  str: string,
  chunkSize: number = 76,
): string => {
  const chunks: string[] = [];
  for (let i = 0; i < str.length; i += chunkSize) {
    chunks.push(str.slice(i, i + chunkSize));
  }
  return chunks.join("\\\n");
};

/**
 * Returns an array of objects representing CSS font-face declarations
 * {
 *   font-family: 'testFont';
 *   src: url("{{{_data}}}") format('woff2');
 * }
 * @param fontPaths - Array of absolute paths to font files
 * @returns Array of objects with font-face declarations
 */
const getCSSFontFaces = async (
  opts: FontGeneratorFontFaceOptions,
): Promise<FontGeneratorFontFaceDeclaration[]> => {
  const paths = opts.fonts.map((f) => f.file);
  const names = opts.fonts.map((f) => f.name);
  const results: FontGeneratorFontFaceDeclaration[] = [];
  try {
    await promiseMap(
      await readAllFiles(paths, allowedFontExtensions),
      async (cp) => {
        const content = fs.readFileSync(cp);
        const nameIndex = paths.indexOf(cp);
        const fontName = names[nameIndex] || path.basename(cp);
        const base64Content = content.toString("base64");
        const mapped = fontMap[path.parse(cp).ext] || {
          mediaType: "application/octet-stream",
          format: "unknown",
        };
        // Split the base64 content across multiple lines using CSS line continuation
        const splitBase64 = splitWithLineContinuation(base64Content);
        results.push({
          name: fontName,
          src: `url("data:${mapped.mediaType};base64,${splitBase64}") format("${mapped.format}")`,
        });
      },
    );
  } catch (err) {
    console.error(err);
  }
  return results;
};

const getFontFaceDeclarationsFromJSONPayload = async (
  json: JSONObjectHTMLSuccessRequest | JSONObjectImageSuccessRequest,
): Promise<FontGeneratorFontFaceDeclaration[]> => {
  const fontSettingsFontsAsArrayKeys: string[] = Object.keys(
    json.data.fontSettings.fonts,
  );
  const fontGeneratorFontFaceFonts: FontGeneratorFontFaceOptions["fonts"] = (
    fontSettingsFontsAsArrayKeys as Array<keyof typeof FontSettingsFonts>
  ).flatMap((key) => {
    const fontSetting = FontSettingsFonts[key];
    const value = json.data.fontSettings.fonts[fontSetting];
    if (!value || !value.file) {
      return [];
    }
    return [
      {
        name: value.name,
        file: value.file,
      } as FontGeneratorFontFaceOptions["fonts"][0],
    ];
  });
  const fontFaceDeclarations: FontGeneratorFontFaceDeclaration[] =
    await getCSSFontFaces({
      fonts: fontGeneratorFontFaceFonts,
    });
  return fontFaceDeclarations;
};

export const FontGenerator = {
  getFontFaceDeclarationsFromJSONPayload,
  getCSSFontFaces,
  encodeToDataUrl,
  encodeToDataSrc,
  toDataUrl,
  toDataSrc,
};
