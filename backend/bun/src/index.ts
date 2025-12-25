import { Clipboard, getJSONFromStdin, writeJSONToStdout } from "./utils";

import { HTMLGenerator, ImageGenerator, RTFGenerator } from "./generators";

import { JSONRequestType } from "./types";

import type {
  JSONObjectHTMLSuccessRequest,
  JSONObjectImageSuccessRequest,
  JSONObjectRTFSuccessRequest,
  NodeHTMLToImageBuffer,
} from "./types";

import {
  checkPlaywrightInstalled,
  installPlaywright,
} from "./utils/playwright";
import path from "node:path";
import os from "node:os";

/**
 * Handles the health check command
 * Returns JSON with information about whether Playwright browser is available
 */
const handleHealth = async () => {
  const { isInstalled, executablePath } = checkPlaywrightInstalled();

  writeJSONToStdout({
    success: true,
    debug: false,
    data: {
      isInstalled,
      executablePath,
    },
  });
};

/**
 * Handles the install command
 * Since we bundle Chromium, this just resolves the executable path
 * and sends progress updates as JSON (one line per update)
 */
const handleInstall = async () => {
  const cacheDir = path.join(os.homedir(), ".cache", "playwright");

  const progressCallback = (progress: {
    status: string;
    message: string;
    progress?: number;
  }) => {
    // Send progress update as JSON on a single line
    // Write directly - process.stdout.write is non-blocking by default
    const progressJson = JSON.stringify({
      success: true,
      debug: false,
      data: {
        type: JSONRequestType.Install,
        status: progress.status,
        message: progress.message,
        progress: progress.progress,
      },
    });
    process.stdout.write(progressJson + "\n");
  };

  const executablePath = await installPlaywright(cacheDir, progressCallback);

  if (executablePath) {
    writeJSONToStdout({
      success: true,
      debug: false,
      data: {
        type: JSONRequestType.Install,
        status: "completed",
        message: "Browser ready.",
        executablePath,
      },
    });
  } else {
    writeJSONToStdout({
      success: false,
      error: "Failed to resolve browser executable",
    });
  }
};

const main = async () => {
  // Check for command line arguments
  const args = process.argv.slice(2);
  if (args.length > 0) {
    const command = args[0];
    if (command === "health") {
      await handleHealth();
      return;
    } else if (command === "install") {
      await handleInstall();
      return;
    }
  }

  // Default behavior: read from stdin
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
