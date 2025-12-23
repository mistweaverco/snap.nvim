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
  let filepath: string = "";

  switch (jsonPayload.data.type) {
    case JSONRequestType.CodeImageGeneration:
      json = jsonPayload as JSONObjectImageSuccessRequest;
      [bufstr, filepath] = await ImageGenerator(json);
      if (bufstr && json.data.toClipboard.image) {
        Clipboard.write(bufstr, "image/png");
      }
      break;
    case JSONRequestType.CodeHTMLGeneration:
      json = jsonPayload as JSONObjectHTMLSuccessRequest;
      [bufstr, filepath] = await HTMLGenerator(json, true);
      if (bufstr && json.data.toClipboard.html) {
        Clipboard.write(bufstr, "text/html");
      }
      break;
    case JSONRequestType.CodeRTFGeneration:
      json = jsonPayload as JSONObjectRTFSuccessRequest;
      [bufstr, filepath] = await RTFGenerator(json);
      if (bufstr && json.data.toClipboard.rtf) {
        Clipboard.write(bufstr, "text/rtf");
      }
      break;
    default:
      writeJSONToStdout({
        success: false,
        error: "Unknown request type",
        context: jsonPayload,
      });
      return;
  }

  writeJSONToStdout({
    success: true,
    debug: json.debug,
    data: {
      ...json.data,
      filepath,
    },
  });
};

main();
