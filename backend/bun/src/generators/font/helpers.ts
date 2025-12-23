import { readdir, readFile, stat, Stats, writeFile } from "fs";
import { extname, join } from "path";

export const isString = (value: unknown) => typeof value === "string";

export const isFunction = (value: unknown) => typeof value === "function";

export const isPlainObject = (obj: unknown) =>
  Object.prototype.toString.call(obj) === "[object Object]";

export const isArray = Array.isArray;

export const isNil = (value: unknown) => value === undefined || value === null;

export const castArray = (value: unknown) => {
  if (isNil(value)) return [];
  return isArray(value) ? value : [value];
};

export const each = <T>(
  items: T[],
  fn: (item: T, index: number, items: T[]) => void | undefined | boolean,
  startOffset = 0,
  endOffset = 0,
) => {
  for (let x = startOffset; x < items.length - endOffset; x++) {
    if (fn(items[x], x, items) === false) break;
  }
};

export const eachArray = <T>(
  items: T[] | T | null | undefined,
  fn: (item: T, index: number, items: T[]) => void | undefined | boolean,
  startOffset = 0,
  endOffset = 0,
) => {
  items = castArray(items);
  each<T>(items, fn, startOffset, endOffset);
};

export const eachAsync = async <T>(
  items: T[],
  fn: (item: T, index: number, items: T[]) => Promise<undefined | boolean>,
  startOffset = 0,
  endOffset = 0,
) => {
  for (let x = startOffset; x < items.length - endOffset; x++) {
    const ret = await fn(items[x], x, items);
    if (ret === false) break;
  }
};

export const promiseMap = <T>(
  items: T[] | T | null | undefined,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  fn: (item: T, index: number, items: T[]) => Promise<any>,
) => {
  items = castArray(items);

  // @FIXME: Properly type this
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const promises: Promise<any>[] = [];
  for (let x = 0; x < items.length; x++) {
    promises.push(fn(items[x], x, items));
  }
  return Promise.all(promises);
};

export const promisify =
  <T>(fn: typeof readFile | typeof writeFile | typeof stat | typeof readdir) =>
  (...args: unknown[]) =>
    new Promise((resolve, reject) => {
      // @FIXME: Properly type this
      // @ts-expect-error -- I don't want to deal with this atm, definitely need to fix later though
      fn(...args, (err: Error | null, result: T) => {
        if (err) {
          reject(err);
        } else {
          resolve(result);
        }
      });
    }) as Promise<T>;

export const readFileAsync = promisify<string | Buffer>(readFile);

export const writeFileAsync = promisify<void>(writeFile);

export const statAsync = promisify<Stats>(stat);

export const readdirAsync = promisify<string[] | Buffer[]>(readdir);

export const readAllFiles = async (
  fileOrPath: string | string[],
  allowedExts: string[] = [],
) => {
  const files: string[] = [];
  await promiseMap(fileOrPath, async (fp) => {
    try {
      const stat = await statAsync(fp);
      if (stat.isDirectory()) {
        const subs = (await readdirAsync(fp)) as string[];
        const subPaths = subs.map((s) => join(fp, s));
        const subFiles = await readAllFiles(subPaths, allowedExts);
        files.push(...subFiles);
      } else {
        if (allowedExts.includes(extname(fp))) files.push(fp);
      }
    } catch (e) {
      // thing not exists - we just skip it
      if ((e as NodeJS.ErrnoException).code === "ENOENT") return;
      console.error(`Path does not exist: ${fp}`, e);
    }
  });

  return files;
};
