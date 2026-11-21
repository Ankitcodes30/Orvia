const https = require('https');

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return resolve(get(res.headers.location));
      }
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve(data));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function check() {
  const node3Url = 'https://ankitcodes30.github.io/Orvia/_app/immutable/nodes/3.CDGKkM7A.js';
  console.log('Fetching live Svelte playlist chunk:', node3Url);
  const jsContent = await get(node3Url);
  console.log('Live playlist chunk length:', jsContent.length);

  console.log('Verification checks:');
  console.log('1. Contains Saavn CDN prefix decode (~):', jsContent.includes('c.saavncdn.com/'));
  console.log('2. Contains .webp suffix decode (@):', jsContent.includes('-500x500.webp'));
  console.log('3. Contains .jpg suffix decode ($):', jsContent.includes('-500x500.jpg'));
  console.log('4. Contains Array.isArray for v2 tuples:', jsContent.includes('Array.isArray'));
  console.log('5. Contains Gunzip streaming recovery:', jsContent.includes('Gunzip') || jsContent.includes('gunzip'));
  console.log('6. Contains partial recovery warning:', jsContent.includes('Partial playlist recovery') || jsContent.includes('Partially recovered'));
}

check().catch(console.error);
