import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

const dev = process.env.NODE_ENV === 'development';
const basePath = process.env.BASE_PATH !== undefined
	? (process.env.BASE_PATH ? `${process.env.BASE_PATH}/` : '/')
	: (dev ? '/' : '/Orvia/');

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
	base: basePath,
	envPrefix: ['VITE_', 'PUBLIC_'],
	build: {
		outDir: 'build', // Ensure this matches your output directory
	},
});
