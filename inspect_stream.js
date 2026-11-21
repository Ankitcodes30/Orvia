const fs = require('fs');
const zlib = require('zlib');

let urlStr = fs.readFileSync('full_url.txt', 'utf8').trim();
urlStr = urlStr.replace(/[`'"]+$/, '');
const url = new URL(urlStr);
let data = url.searchParams.get('data');
data = data.replace(/[`'"]+$/, '');
let b64 = data.replace(/-/g, '+').replace(/_/g, '/');
while (b64.length % 4 !== 0) b64 += '=';
const buf = Buffer.from(b64, 'base64');

const gunzip = zlib.createGunzip();
let chunks = [];
gunzip.on('data', c => chunks.push(c));
gunzip.on('end', () => {
  console.log('End reached cleanly!');
  const out = Buffer.concat(chunks).toString('utf8');
  console.log('Total decompressed:', out.length);
});
gunzip.on('error', err => {
  console.log('Gunzip error:', err.message);
  const out = Buffer.concat(chunks).toString('utf8');
  console.log('Decompressed partial bytes:', out.length);
  console.log('Last 200 chars:', out.slice(-200));
  const tracks = (out.match(/"id":/g) || []).length;
  console.log('Tracks started in partial output:', tracks);
});
gunzip.end(buf);
