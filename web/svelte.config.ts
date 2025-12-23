import tailwindcss from '@tailwindcss/vite';
import type { Config } from '@sveltejs/kit';
import adapter from '@sveltejs/adapter-static';

const config: Config = {
  kit: {
    adapter: adapter()
  },
  extensions: ['.svelte'],
  plugins: [tailwindcss()]
};

export default config;
