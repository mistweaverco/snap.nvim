import type { JSONObjectRequest, JSONObjectResponse } from "./../types";

export const readAllFromStdin = async () => {
  let data = "";
  for await (const chunk of process.stdin) {
    data += chunk;
  }
  return data;
};

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
    process.stdout.write(JSON.stringify({ success: false, error: error.message, context: obj }));
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
