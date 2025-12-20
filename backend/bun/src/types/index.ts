export type NodeHTMLToImageBuffer =
  | string
  | (string | Buffer<ArrayBufferLike>)[]
  | Buffer<ArrayBufferLike>;

export const enum JSONRequestType {
  CodeImageGeneration = "image",
  CodeHTMLGeneration = "html",
  CodeRTFGeneration = "rtf",
}

interface FontSettingsFont {
  name: string;
  file?: string;
}

interface FontSettings {
  size: number;
  line_height: number;
  fonts: {
    default: FontSettingsFont;
    bold: FontSettingsFont;
    italic: FontSettingsFont;
    bold_italic: FontSettingsFont;
  };
}

export enum JSONRequestTemplate {
  Default = "default",
  Linux = "linux",
  MacOS = "macos",
}

export interface JSONObjectCodeLine {
  fg: string;
  bg: string;
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  hl_name: string;
}

export interface JSONObjectHTMLSuccessRequest {
  success: true;
  debug: boolean;
  data: {
    type: JSONRequestType.CodeHTMLGeneration;
    theme: {
      fgColor: string;
      bgColor: string;
    };
    template?: JSONRequestTemplate;
    templateFilepath?: string;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: boolean;
    transparent: boolean;
    code: Array<JSONObjectCodeLine[]>;
    filepath: string;
    minWidth: number;
  };
}

export interface JSONObjectRTFSuccessRequest {
  success: true;
  debug: boolean;
  data: {
    type: JSONRequestType.CodeRTFGeneration;
    theme: {
      fgColor: string;
      bgColor: string;
    };
    template?: JSONRequestTemplate;
    templateFilepath?: string;
    fontSettings: FontSettings;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: boolean;
    transparent: boolean;
    code: Array<JSONObjectCodeLine[]>;
    filepath: string;
    minWidth: number;
  };
}

export interface JSONObjectImageSuccessRequest {
  success: true;
  debug: boolean;
  data: {
    type: JSONRequestType.CodeImageGeneration;
    theme: {
      fgColor: string;
      bgColor: string;
    };
    template?: JSONRequestTemplate;
    outputImageFormat: "png" | "jpeg";
    fontSettings: FontSettings;
    templateFilepath?: string;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: boolean;
    transparent: boolean;
    code: Array<JSONObjectCodeLine[]>;
    filepath: string;
    minWidth: number;
  };
}

// Image needs all fields from both interfaces, but HTML only needs its own fields
export type JSONObjectSuccessRequest =
  | JSONObjectImageSuccessRequest
  | JSONObjectHTMLSuccessRequest
  | JSONObjectRTFSuccessRequest;

export interface JSONObjectErrorRequest {
  success: false;
  data?: JSONObjectSuccessRequest["data"];
  context?: unknown;
  error: string;
}

export type JSONObjectRequest =
  | JSONObjectSuccessRequest
  | JSONObjectErrorRequest;

export interface JSONObjectSuccessResponse {
  success: true;
  debug: boolean;
  context?: unknown;
  data:
    | JSONObjectImageSuccessRequest["data"]
    | JSONObjectHTMLSuccessRequest["data"];
}

export interface JSONObjectErrorResponse {
  success: false;
  data?: JSONObjectSuccessResponse["data"];
  context?: unknown;
  error: string;
}

export type JSONObjectResponse =
  | JSONObjectSuccessResponse
  | JSONObjectErrorResponse;
