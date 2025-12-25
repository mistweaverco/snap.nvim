import { defineConfig, globalIgnores } from "eslint/config";
import ts from "typescript-eslint";
import svelte from "eslint-plugin-svelte";
import svelteParser from "svelte-eslint-parser";
import markdown from "@eslint/markdown";
import css from "@eslint/css";
import { tailwind4 } from "tailwind-csstree";
import prettier from "eslint-config-prettier";

export default defineConfig(
  globalIgnores([".DS_Store", "dist/", "node_modules/", "web/build/", "web/.svelte-kit/", ".direnv/"]),
  ...ts.configs.recommended,
  {
    files: ["backend/bun/**.ts", "eslint.config.ts"],
    plugins: {
      "@typescript-eslint": ts.plugin,
    },
    languageOptions: {
      parser: ts.parser,
      parserOptions: {
        projectService: true,
      },
    },
  },
  {
    files: ["web/**/*.svelte"],
    plugins: { svelte },
    languageOptions: {
      parser: svelteParser,
      parserOptions: {
        parser: ts.parser,
        extraFileExtensions: [".svelte"],
      },
    },
    rules: {
      ...svelte.configs["flat/recommended"][0].rules,
    },
  },
  {
    files: ["**/*.css"],
    plugins: { css },
    language: "css/css",
    languageOptions: { customSyntax: tailwind4 },
    rules: { "css/no-invalid-at-rules": "off" },
  },
  {
    files: ["**/*.md"],
    plugins: { markdown },
    language: "markdown/gfm",
    rules: {
      "markdown/no-missing-label-refs": [
        "error",
        {
          allowLabels: ["!NOTE", "!TIP", "!IMPORTANT", "!WARNING", "!CAUTION"],
        },
      ],
    },
  },
  prettier,
);
