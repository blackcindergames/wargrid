import js from '@eslint/js';
import { defineConfig } from 'eslint/config';
import prettier from 'eslint-config-prettier';
import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig(
	{ ignores: ['node_modules/'] },
	js.configs.recommended,
	tseslint.configs.strictTypeChecked,
	svelte.configs.recommended,
	prettier,
	svelte.configs.prettier,
	{
		languageOptions: {
			globals: globals.browser,
			parserOptions: {
				project: './tsconfig.json',
				extraFileExtensions: ['.svelte'],
			},
		},
		linterOptions: { reportUnusedDisableDirectives: 'error' },
	},
	{
		files: ['**/*.svelte'],
		languageOptions: { parserOptions: { parser: tseslint.parser } },
	},
);
