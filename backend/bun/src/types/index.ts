export type NodeHTMLToImageBuffer = string | (string | Buffer<ArrayBufferLike>)[] | Buffer<ArrayBufferLike>;

export const enum JSONRequestType {
  CodeImageGeneration = "image",
  CodeHTMLGeneration = "html",
  CodeRTFGeneration = "rtf",
  Health = "health",
  Install = "install",
}

interface FontSettingsFont {
  name: string;
  file?: string;
}

export enum FontSettingsFonts {
  default = "default",
  bold = "bold",
  italic = "italic",
  bold_italic = "bold_italic",
}

export interface FontSettings {
  size: number;
  line_height: number;
  fonts: {
    [FontSettingsFonts.default]: FontSettingsFont;
    [FontSettingsFonts.bold]: FontSettingsFont;
    [FontSettingsFonts.italic]: FontSettingsFont;
    [FontSettingsFonts.bold_italic]: FontSettingsFont;
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

export interface CSSFontFaceDeclarations {
  "font-family": string;
  src: string;
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
    fontFaceDeclarations: CSSFontFaceDeclarations[];
    template?: JSONRequestTemplate;
    templateFilepath?: string;
    fontSettings: FontSettings;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: {
      image: boolean;
      html: boolean;
      css: boolean;
      rtf: boolean;
    };
    outputDir?: string;
    filename: string;
    filenamePattern: string;
    transparent: boolean;
    code: Array<JSONObjectCodeLine[]>;
    minWidth: number;
    dpi?: number;
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
    toClipboard: {
      image: boolean;
      html: boolean;
      css: boolean;
      rtf: boolean;
    };
    outputDir?: string;
    filename: string;
    filenamePattern: string;
    transparent: boolean;
    code: Array<JSONObjectCodeLine[]>;
    minWidth: number;
    dpi?: number;
    tabstop?: number;
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
    fontFaceDeclarations: CSSFontFaceDeclarations[];
    template?: JSONRequestTemplate;
    outputImageFormat: "png" | "jpeg";
    fontSettings: FontSettings;
    templateFilepath?: string;
    additionalTemplateData?: { [key: string]: unknown };
    toClipboard: {
      image: boolean;
      html: boolean;
      css: boolean;
      rtf: boolean;
    };
    outputDir?: string;
    filename: string;
    filenamePattern: string;
    transparent: boolean;
    code: Array<JSONObjectCodeLine[]>;
    minWidth: number;
    dpi?: number;
    tabstop?: number;
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

export type JSONObjectRequest = JSONObjectSuccessRequest | JSONObjectErrorRequest;

export interface JSONObjectHealthResponse {
  success: true;
  debug: boolean;
  data: {
    isInstalled: boolean;
    executablePath: string | null;
  };
}

export interface JSONObjectInstallResponse {
  success: true;
  debug: boolean;
  data: {
    type: JSONRequestType.Install;
    status: string;
    message: string;
    progress?: number;
    executablePath?: string;
  };
}

export interface JSONObjectSuccessResponse {
  success: true;
  debug: boolean;
  context?: unknown;
  data:
    | (JSONObjectImageSuccessRequest["data"] & { filepath: string })
    | (JSONObjectRTFSuccessRequest["data"] & { filepath: string })
    | (JSONObjectHTMLSuccessRequest["data"] & { filepath: string });
}

export interface JSONObjectErrorResponse {
  success: false;
  data?: JSONObjectSuccessResponse["data"];
  context?: unknown;
  error: string;
}

export type JSONObjectResponse =
  | JSONObjectSuccessResponse
  | JSONObjectHealthResponse
  | JSONObjectInstallResponse
  | JSONObjectErrorResponse;
