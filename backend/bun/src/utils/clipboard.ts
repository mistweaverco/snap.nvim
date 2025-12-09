import { Buffer } from "buffer";
import { execSync } from "child_process";
import { JSONRequestType, type NodeHTMLToImageBuffer } from ".";

/**
 * Returns the appropriate system clipboard command for copying image/png data
 * based on the operating system.
 * NOTE ON EXTERNAL TOOLS:
 * - macOS: This uses 'pngpaste'.
 *   Install via Homebrew:
 *   https://github.com/jcsalterego/pngpaste
 * - Windows: This uses 'nircmd' with the 'clipboard setimagefromstdin' command.
 *   Download the utility here:
 *   https://www.nirsoft.net/utils/nircmd.html
 * - Linux (X11): This uses 'xclip', which is a standard Linux utility.
 * * @returns {string | null} The clipboard command or null if unsupported OS.
 */
const getSystemClipboardCommand = (type: JSONRequestType): string | null => {
  const isLinux = process.platform === "linux";
  const isX11 = process.env.DISPLAY !== undefined;
  const isWayland = process.env.WAYLAND_DISPLAY !== undefined;
  const isMac = process.platform === "darwin";
  const isWindows = process.platform === "win32";

  let targetType = "image/png";

  switch (type) {
    case JSONRequestType.CodeImageGeneration:
      targetType = "image/png";
      break;
    case JSONRequestType.CodeHTMLGeneration:
      targetType = "text/html";
      break;
    default:
      targetType = "image/png";
      break;
  }

  if (isLinux) {
    if (isX11) {
      // xclip -t image/png registers the raw buffer as a PNG image,
      // not text.
      return "xclip -selection clipboard -t " + targetType;
    }
    if (isWayland) {
      // Wayland support would typically require
      // 'wl-copy --type image/png'
      // but wl-copy clears the clipboard when the process exits,
      // so it's not suitable for this use case.
      return "xclip -selection clipboard -t " + targetType;
    }
  }
  if (isMac) {
    // pngpaste reads the PNG data from stdin ('-').
    if (targetType === "text/html") {
      return "pbcopy";
    }
    return "pngpaste -";
  }
  if (isWindows) {
    if (targetType === "text/html") {
      return "clip";
    }
    // nircmd copies the image data from stdin and sets it on the clipboard.
    // The path to nircmd.exe needs to be in the system PATH.
    return "nircmd clipboard setimagefromstdin";
  }
  return null;
};

export const isSystemClipboardCommandAvailable = (type: JSONRequestType): {
  success: boolean;
  errorMessage?: string;
} => {
  const command = getSystemClipboardCommand(type);
  if (!command) {
    return {
      success: false,
      errorMessage: `Unsupported OS for copying images.\n` +
        `Detected OS: " + ${process.platform}`,
    };
  }
  const commandName = command.split(" ")[0];
  try {
    execSync(
      process.platform === "win32"
        ? `where ${commandName}`
        : `which ${commandName}`,
    );
    return { success: true };
  } catch {
    return {
      success: false,
      errorMessage:
        `Required clipboard command-line tool not found: ${commandName}`,
    };
  }
};

const convertToBuffer = (
  input: NodeHTMLToImageBuffer,
): Buffer<ArrayBufferLike> => {
  if (typeof input === "string") {
    return Buffer.from(input);
  }
  if (Array.isArray(input)) {
    return Buffer.concat(
      input.map((item) => typeof item === "string" ? Buffer.from(item) : item),
    );
  }
  return input;
};

/**
 * Copies the given input as image/png to the system clipboard using the
 * appropriate external command-line tool.
 * @param {string | (string | Buffer<ArrayBufferLike>)[] | Buffer<ArrayBufferLike>
 * } input - The input (assumed to be PNG byte data) to copy to the clipboard.
 * @returns {boolean} True if the operation was successful, false otherwise.
 */
export const copyBufferToClipboard = (
  input: NodeHTMLToImageBuffer,
  type: JSONRequestType,
): { success: boolean; errorMessage?: string } => {
  const command = getSystemClipboardCommand(type);
  if (!command) {
    return {
      success: false,
      errorMessage: `Unsupported OS for copying images.\n` +
        `Detected OS: " + ${process.platform}`,
    };
  }
  try {
    const inputBuffer = convertToBuffer(input);
    // Use execSync with the 'input' option to
    // pipe the Buffer to the command's stdin
    execSync(command, {
      input: inputBuffer,
      // hide the command's output
      stdio: "inherit",
    });
    return { success: true };
  } catch (error) {
    return {
      success: false,
      errorMessage: (error as Error).message || String(error),
    };
  }
};
