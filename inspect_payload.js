const zlib = require('zlib');
const fs = require('fs');

const rawFile = fs.readFileSync('test_decode.js', 'utf8');
const match = rawFile.match(/const rawData = '([^']+)';/);
const b64 = match[1];

let base64 = b64.replace(/-/g, '+').replace(/_/g, '/');
while (base64.length % 4 !== 0) base64 += '=';
const buf = Buffer.from(base64, 'base64');

const gunzip = zlib.createGunzip();
let chunks = [];
gunzip.on('data', chunk => chunks.push(chunk));
gunzip.on('error', err => {
  const total = Buffer.concat(chunks).toString('utf8');
  // Match tracks {"id":...}
  const idMatches = total.match(/"id":/g);
  console.log('Number of tracks started in decompressed stream:', idMatches ? idMatches.length : 0);
  // Let's print the track titles
  const titleMatches = [...total.matchAll(/"t":"([^"]+)"/g)].map(m => m[1]);
  console.log('Total titles found:', titleMatches.length);
  console.log('Titles found so far:');
  titleMatches.forEach((t, i) => console.log(`${i}: ${t}`));
});
gunzip.end(buf);
