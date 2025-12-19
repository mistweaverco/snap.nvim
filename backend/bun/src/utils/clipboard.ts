import { Buffer } from "buffer";
import { spawn } from "bun";
import { unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

type MimeType =
  | "text/plain"
  | "text/html"
  | "image/png"
  | "image/jpeg"
  | "application/json";

const getLinuxTool = (): string | null => {
  const isWayland = !!process.env.WAYLAND_DISPLAY;
  if (isWayland && Bun.which("wl-copy")) return "wayland";
  if (Bun.which("xsel")) return "xsel";
  if (Bun.which("xclip")) return "xclip";
  return null;
};

export const Clipboard = {
  /**
   * Reads from the clipboard.
   * Returns a Buffer for binary data or a string for text-based types.
   */
  async read(mimeType: MimeType = "text/plain"): Promise<Buffer | string> {
    const platform = process.platform;
    let cmd: string[] = [];

    if (platform === "darwin") {
      // macOS uses 'osascript' or 'pbpaste'. pbpaste is limited,
      // so for images we use a small AppleScript snippet.
      if (mimeType.startsWith("image/")) {
        cmd = ["osascript", "-e", `get the clipboard as «class PNGf»`];
      } else {
        cmd = ["pbpaste"];
      }
    } else if (platform === "win32") {
      if (mimeType.startsWith("image/")) {
        cmd = [
          "powershell.exe",
          "-NoProfile",
          "-Command",
          "$img = Get-Clipboard -Image; if($img) { $ms = New-Object System.IO.MemoryStream; $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $ms.ToArray() }",
        ];
      } else {
        cmd = [
          "powershell.exe",
          "-NoProfile",
          "-Command",
          "Get-Clipboard -Raw",
        ];
      }
    } else if (platform === "linux") {
      const tool = await getLinuxTool();
      if (tool === "wayland") {
        cmd = ["wl-paste", "--type", mimeType, "--no-newline"];
      } else if (tool === "xclip") {
        cmd = ["xclip", "-selection", "clipboard", "-t", mimeType, "-out"];
      } else {
        // xsel doesn't handle non-text targets well
        cmd = ["xsel", "--clipboard", "--output"];
      }
    }

    const proc = spawn(cmd);
    const buffer = await new Response(proc.stdout).arrayBuffer();
    const result = Buffer.from(buffer);

    return mimeType.startsWith("image/") ? result : result.toString("utf-8");
  },

  async write(
    data: string | Buffer | (string | Buffer)[],
    mimeType: MimeType = "text/plain",
  ): Promise<void> {
    const platform = process.platform;
    const input =
      typeof data === "string"
        ? Buffer.from(data, "utf-8")
        : Buffer.concat(
            Array.isArray(data)
              ? data.map((item) =>
                  typeof item === "string" ? Buffer.from(item, "utf-8") : item,
                )
              : [data],
          );

    // --- macOS Implementation ---
    if (platform === "darwin") {
      if (mimeType.startsWith("image/")) {
        const tempFile = join(tmpdir(), `clip_${Date.now()}.png`);
        try {
          writeFileSync(tempFile, input);
          const script = `set the clipboard to (read (POSIX file "${tempFile}") as «class PNGf»)`;
          const proc = spawn(["osascript", "-e", script]);
          await proc.exited;
        } finally {
          try {
            unlinkSync(tempFile);
          } catch {
            // Ignore cleanup errors
          }
        }
        return;
      }

      const proc = spawn(["pbcopy"], { stdin: input });
      await proc.exited;
      return;
    }

    // --- Windows Implementation ---
    if (platform === "win32") {
      if (mimeType.startsWith("image/")) {
        // We pass the bytes via Base64 to PowerShell to avoid encoding issues with raw STDIN
        const b64 = input.toString("base64");
        const psCommand = `
          Add-Type -AssemblyName System.Windows.Forms, System.Drawing;
          $bytes = [System.Convert]::FromBase64String('${b64}');
          $ms = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length);
          $img = [System.Drawing.Image]::FromStream($ms);
          [System.Windows.Forms.Clipboard]::SetImage($img);
        `;
        const proc = spawn([
          "powershell.exe",
          "-NoProfile",
          "-Command",
          psCommand,
        ]);
        await proc.exited;
        return;
      }

      const proc = spawn(
        ["powershell.exe", "-NoProfile", "-Command", "$input | Set-Clipboard"],
        { stdin: input },
      );
      await proc.exited;
      return;
    }

    // --- Linux Implementation ---
    if (platform === "linux") {
      const tool = getLinuxTool();
      if (tool === "wayland") {
        // We do NOT await .exited here. wl-copy must remain running
        // in the background to serve the clipboard content.
        spawn(["wl-copy", "--type", mimeType], {
          stdin: input,
          stdout: "ignore",
          stderr: "ignore",
          // Unref allows the parent process to exit while wl-copy stays alive
        }).unref();
        return;
      }

      const cmd =
        tool === "xclip"
          ? ["xclip", "-selection", "clipboard", "-t", mimeType, "-in"]
          : ["xsel", "--clipboard", "--input"];

      await spawn(cmd, { stdin: input }).exited;
    }
  },
};
