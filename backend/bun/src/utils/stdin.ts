export const readAllFromStdin = async () => {
  let data = "";
  for await (const chunk of process.stdin) {
    data += chunk;
  }
  return data;
};

export const enum JSONRequestType {
  CodeImageGeneration = "image",
  CodeHTMLGeneration = "html",
}

export interface JSONObjectImageSuccessRequest {
  success: true;
  data: {
    type: JSONRequestType.CodeImageGeneration;
    outputImageFormat: "png" | "jpeg";
    outputImageWidth: number;
    outputImageHeight: number;
    filepath: string;
  };
}

export interface JSONObjectHTMLSuccessRequest {
  success: true;
  data: {
    type: JSONRequestType.CodeHTMLGeneration;
    toClipboard: boolean;
    transparent: boolean;
    code: string;
    codeContainerCSS: string;
  };
}

// Image needs all fields from both interfaces, but HTML only needs its own fields
export type JSONObjectSuccessRequest =
  | (JSONObjectImageSuccessRequest & JSONObjectHTMLSuccessRequest)
  | JSONObjectHTMLSuccessRequest;

export interface JSONObjectErrorRequest {
  success: false;
  data?: JSONObjectSuccessRequest["data"];
  context?: { [key: string]: unknown };
  error: string;
}

export type JSONObjectRequest =
  | JSONObjectSuccessRequest
  | JSONObjectErrorRequest;

export interface JSONObjectSuccessResponse {
  success: true;
  data: {
    transparent: boolean;
    code: string;
    codeContainerCSS: string;
    outputImageFormat: "png" | "jpeg";
    outputImageWidth: number;
    outputImageHeight: number;
    filepath: string;
  };
}

export interface JSONObjectErrorResponse {
  success: false;
  data?: JSONObjectSuccessResponse["data"];
  context?: { [key: string]: unknown };
  error: string;
}

export type JSONObjectResponse =
  | JSONObjectSuccessResponse
  | JSONObjectErrorResponse;

/**
 * Writes a JSON object to stdout. If the object contains an error, exits the process with code 1.
 * @param JSONObjectResponse - The JSON object to write to stdout.
 */
export const writeJSONToStdout = (obj: JSONObjectResponse): void => {
  try {
    process.stdout.write(JSON.stringify(obj));
    if ("error" in obj) {
      process.exit(1);
    }
  } catch (err) {
    const error = err as Error;
    process.stdout.write(
      JSON.stringify({ success: false, error: error.message }),
    );
    process.exit(1);
  }
};

export const getJSONFromStdin = async (): Promise<JSONObjectRequest> => {
  const data = await readAllFromStdin();
  try {
    return JSON.parse(data);
  } catch (err) {
    const error = err as Error;
    return { success: false, error: error.message };
  }
};
