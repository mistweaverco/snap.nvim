import fs from "fs";
import path from "path";
import nodeHtmlToImage from "node-html-to-image";
import {
  copyBufferToClipboard,
  getJSONFromStdin,
  isSystemClipboardCommandAvailable,
  JSONRequestType,
  type NodeHTMLToImageBuffer,
  writeJSONToStdout,
} from "./utils";

const main = async () => {
  const jsonPayload = await getJSONFromStdin();
  if ("error" in jsonPayload) {
    writeJSONToStdout({
      success: false,
      error: jsonPayload.error,
    });
    return;
  }

  const clipboardCheck = isSystemClipboardCommandAvailable(
    jsonPayload.data.type,
  );
  if (!clipboardCheck.success) {
    console.error(
      clipboardCheck.errorMessage,
    );
    return;
  }

  const template = fs.readFileSync(
    path.resolve(__dirname, "..", "..", "..", "templates", "default.html"),
    "utf-8",
  );

  const html = template.replace(
    "{{ CODE }}",
    jsonPayload.data.code,
  ).replace(
    "{{ CODE_CONTAINER_CSS }}",
    jsonPayload.data.codeContainerCSS,
  );

  let buffer: NodeHTMLToImageBuffer;

  switch (jsonPayload.data.type) {
    case JSONRequestType.CodeImageGeneration:
      buffer = await nodeHtmlToImage({
        output: jsonPayload.data.filepath,
        html: html,
        transparent: jsonPayload.data.transparent,
        type: jsonPayload.data.outputImageFormat,
      });
      break;
    default:
      writeJSONToStdout({
        success: false,
        error: `Unsupported request type: ${jsonPayload.data.type}`,
      });
      // TODO: Implement HTML generation logic
      buffer = Buffer.from("");
  }

  if (buffer && jsonPayload.data.toClipboard) {
    copyBufferToClipboard(buffer, jsonPayload.data.type);
  }

  writeJSONToStdout({
    success: true,
    data: jsonPayload.data,
    context: jsonPayload.context,
  });
};

main();
