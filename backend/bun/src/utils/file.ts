import { mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const replaceProcessEnv = (input: string): string => {
  return input.replace(/\$([A-Z_]+)/g, (_, varName) => {
    return process.env[varName] || "";
  });
};

export const getOutputDir = async (userConfigOutDir?: string): Promise<string> => {
  if (userConfigOutDir) {
    if (userConfigOutDir.startsWith("~")) {
      const homeDir = homedir();
      if (!homeDir) {
        throw new Error("Could not determine the user's home directory.");
      }
      userConfigOutDir = userConfigOutDir.replace("~", homeDir);
    }
    return replaceProcessEnv(userConfigOutDir);
  }
  const homeDir = homedir();
  if (!homeDir) {
    throw new Error("Could not determine the user's home directory.");
  }

  // Platform-specific default screenshot directories
  let screenshotsDir: string;
  switch (process.platform) {
    case "darwin": // macOS
      screenshotsDir = join(homeDir, "Desktop");
      break;
    case "win32": // Windows
      screenshotsDir = join(homeDir, "Pictures", "Screenshots");
      break;
    default: // Linux and other Unix-like systems
      screenshotsDir = join(homeDir, "Pictures", "Screenshots");
      break;
  }

  await mkdir(screenshotsDir, { recursive: true });
  return screenshotsDir;
};

export const getFilenameWithoutExtension = (filename: string): string => {
  return filename.replace(/\.[^/.]+$/, "");
};

export const getFullOutputPath = async (
  outputDir: string | undefined,
  filename: string,
  filenamePattern: string,
): Promise<string> => {
  outputDir = await getOutputDir(outputDir);
  return `${outputDir.replace(/\/+$/, "")}/${generateFilename(filenamePattern, filename)}`;
};

export const generateFilename = (pattern: string, originalFilename: string): string => {
  const now = new Date();
  const pad = (num: number, size: number) => {
    let s = num.toString();
    while (s.length < size) s = "0" + s;
    return s;
  };
  const replacements: { [key: string]: string } = {
    "%t": `${now.getFullYear()}${pad(now.getMonth() + 1, 2)}${pad(
      now.getDate(),
      2,
    )}_${pad(now.getHours(), 2)}${pad(now.getMinutes(), 2)}${pad(now.getSeconds(), 2)}`,
    "%time": `${pad(now.getHours(), 2)}${pad(now.getMinutes(), 2)}${pad(now.getSeconds(), 2)}`,
    "%date": `${now.getFullYear()}${pad(now.getMonth() + 1, 2)}${pad(now.getDate(), 2)}`,
    "%file_name": originalFilename.replace(/\.[^/.]+$/, ""),
    "%file_extension": originalFilename.split(".").pop() || "",
    "%unixtime": Math.floor(now.getTime() / 1000).toString(),
  };

  let filename = pattern;
  for (const [key, value] of Object.entries(replacements)) {
    filename = filename.replace(new RegExp(key, "g"), value);
  }
  return filename;
};
