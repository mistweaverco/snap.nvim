import { Clipboard, getJSONFromStdin, writeJSONToStdout } from "./utils";

import { HTMLGenerator, ImageGenerator, RTFGenerator } from "./generators";

import { JSONRequestType } from "./types";

import type {
  JSONObjectHTMLSuccessRequest,
  JSONObjectImageSuccessRequest,
  JSONObjectRTFSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./types";

const main = async () => {
  const jsonPayload = await getJSONFromStdin();

  if ("error" in jsonPayload) {
    writeJSONToStdout({
      success: false,
      error: jsonPayload.error,
    });
    return;
  }

  let json:
    | JSONObjectImageSuccessRequest
    | JSONObjectHTMLSuccessRequest
    | JSONObjectRTFSuccessRequest;

  let bufstr: NodeHTMLToImageBuffer | Buffer | string | null = null;

  switch (jsonPayload.data.type) {
    case JSONRequestType.CodeImageGeneration:
      json = jsonPayload as JSONObjectImageSuccessRequest;
      bufstr = await ImageGenerator(json);
      break;
    case JSONRequestType.CodeHTMLGeneration:
      json = jsonPayload as JSONObjectHTMLSuccessRequest;
      bufstr = await HTMLGenerator(json);
      break;
    case JSONRequestType.CodeRTFGeneration:
      json = jsonPayload as JSONObjectRTFSuccessRequest;
      bufstr = RTFGenerator(json);
      break;
    default:
      writeJSONToStdout({
        success: false,
        error: `Unknown request type: ${jsonPayload.data.type}`,
      });
      return;
  }

  if (bufstr && json.data.toClipboard) {
    Clipboard.write(bufstr, "image/png");
  }

  writeJSONToStdout({
    success: true,
    debug: json.debug,
    data: json.data,
  });
};

main();
