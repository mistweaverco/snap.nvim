import prettier from 'eslint-config-prettier';
import svelte from 'eslint-plugin-svelte';
import type { Linter } from 'eslint';

const config: Linter.Config[] = [
  prettier,
  ...svelte.configs['flat/prettier'],
  {
    ignores: ['node_modules/**', 'build/**', '.svelte-kit/**']
  }
];

export default config;
