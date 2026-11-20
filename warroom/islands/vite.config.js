import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
	plugins: [svelte({ compilerOptions: { customElement: true } })],
	build: {
		lib: { entry: 'main.js', formats: ['es'], fileName: () => 'islands.js' },
		outDir: '../internal/web/static',
		// The static folder holds the rest of the site; only islands.js is ours.
		emptyOutDir: false,
		minify: true,
		// Library mode keeps whitespace in an ES bundle for other bundlers; this one goes straight to the browser.
		rolldownOptions: { output: { minify: true } },
	},
});
