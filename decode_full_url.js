const fs = require('fs');
const zlib = require('zlib');

try {
  const urlStr = fs.readFileSync('full_url.txt', 'utf8').trim();
  const url = new URL(urlStr);
  const data = url.searchParams.get('data');
  console.log('Query param name:', url.searchParams.get('name'));
  console.log('data param length:', data ? data.length : 0);
  let b64 = data.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4 !== 0) b64 += '=';
  const buf = Buffer.from(b64, 'base64');
  console.log('Buffer len:', buf.length, 'Magic bytes:', buf[0].toString(16), buf[1].toString(16));
  const decomp = zlib.gunzipSync(buf);
  console.log('Decompressed length:', decomp.length);
  const json = JSON.parse(decomp.toString('utf8'));
  console.log('JSON keys:', Object.keys(json));
  console.log('Title (t):', json.t);
  console.log('Description (d):', json.d);
  console.log('Track count:', (json.tr || []).length);
  console.log('Track 0:', json.tr[0]);
  console.log('Track 46:', json.tr[json.tr.length - 1]);
} catch (e) {
  console.error('Error:', e);
}
