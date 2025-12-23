/** @type { import("eslint").Linter.Config } */
module.exports = {
  root: true,
  extends: ['eslint:recommended', 'plugin:svelte/recommended', 'prettier'],
  parserOptions: {
    sourceType: 'module',
    ecmaVersion: 2020,
    extraFileExtensions: ['.svelte']
  },
  env: {
    browser: true,
    es2017: true,
    node: true
  },
  ignores: [
    '.DS_Store',
    'node_modules',
    '/build',
    '/.svelte-kit',
    '/package',
    '.env',
    '.env.*',
    '!.env.example',
    'pnpm-lock.yaml',
    'package-lock.json',
    'yarn.lock'
  ]
};
