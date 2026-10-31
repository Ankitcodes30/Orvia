import adapter from '@sveltejs/adapter-static';


/** @type {import('@sveltejs/kit').Config} */
const dev = process.env.NODE_ENV === 'development';

// Support explicit BASE_PATH environment variable:
// - For GitHub project pages (https://ankitcodes30.github.io/Orvia): BASE_PATH="/Orvia"
// - Default in development: ""
const basePath = process.env.BASE_PATH !== undefined
  ? process.env.BASE_PATH
  : (dev ? '' : '/Orvia');

const config = {
  kit: {
    adapter: adapter({
      // SPA fallback for GitHub Pages
      fallback: '404.html',
    }),
    paths: {
      base: basePath,
      relative: false,
    },
    prerender: {
      entries: ['*', '/playlist', '/track', '/p', '/privacy', '/terms', '/licenses', '/help'],
      handleHttpError: 'warn'
    }
  }
};

export default config;
