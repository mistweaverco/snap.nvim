export type NodeHTMLToImageBuffer =
  | string
  | (string | Buffer<ArrayBufferLike>)[]
  | Buffer<ArrayBufferLike>;

export const enum JSONRequestType {
  CodeImageGeneration = "image",
  CodeHTMLGeneration = "html",
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
    bold?: FontSettingsFont;
    italic?: FontSettingsFont;
    bold_italic?: FontSettingsFont;
  };
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
    templateFilepath?: string;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: boolean;
    transparent: boolean;
    code: string[];
    filepath: string;
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
    outputImageFormat: "png" | "jpeg";
    fontSettings: FontSettings;
    templateFilepath?: string;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: boolean;
    transparent: boolean;
    code: string[];
    filepath: string;
  };
}

// Image needs all fields from both interfaces, but HTML only needs its own fields
export type JSONObjectSuccessRequest =
  | JSONObjectImageSuccessRequest
  | JSONObjectHTMLSuccessRequest;

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
