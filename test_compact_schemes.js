const fs = require('fs');
const zlib = require('zlib');

const raw = JSON.parse(fs.readFileSync('creators_choice_fixture.json', 'utf8'));

function toB64Url(buf) {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// 1. Current format v1
const v1Json = JSON.stringify(raw);
const v1Gzip = zlib.gzipSync(Buffer.from(v1Json, 'utf8'), { level: 9 });
const v1B64 = toB64Url(v1Gzip);
console.log('--- FORMAT V1 ---');
console.log('JSON size:', v1Json.length);
console.log('Gzip size:', v1Gzip.length);
console.log('Base64url size:', v1B64.length);
console.log('Full URL size:', ('https://ankitcodes30.github.io/Orvia/playlist?name=Creator%27s+Choice&data=' + v1B64).length);

// 2. Compact Scheme A: Array of arrays (no key repetition)
// [id, title, artist, album, thumb, src]
const v2A = {
  v: 2,
  t: raw.t,
  d: raw.d,
  art: raw.art,
  tr: raw.tr.map(t => [
    t.id,
    t.t,
    t.a || '',
    t.al || '',
    t.th || '',
    t.src || ''
  ])
};
const v2AJson = JSON.stringify(v2A);
const v2AGzip = zlib.gzipSync(Buffer.from(v2AJson, 'utf8'), { level: 9 });
const v2AB64 = toB64Url(v2AGzip);
console.log('\n--- FORMAT V2-A (Tuple Arrays) ---');
console.log('JSON size:', v2AJson.length);
console.log('Gzip size:', v2AGzip.length);
console.log('Base64url size:', v2AB64.length);
console.log('Full URL size:', ('https://ankitcodes30.github.io/Orvia/playlist?name=Creator%27s+Choice&data=' + v2AB64).length);

// 3. Compact Scheme B: CDN Prefix dictionary / deduplication
// Notice: 'https://c.saavncdn.com/' appears in almost all tracks.
// Also: '-500x500.webp' or '-500x500.jpg' appears in almost all tracks.
const CDN_PREFIX = 'https://c.saavncdn.com/';
const v2B = {
  v: 2,
  t: raw.t,
  d: raw.d,
  art: raw.art,
  tr: raw.tr.map(t => {
    let th = t.th || '';
    if (th.startsWith(CDN_PREFIX)) {
      th = '~' + th.slice(CDN_PREFIX.length);
    }
    return [
      t.id,
      t.t,
      t.a || '',
      t.al || '',
      th,
      t.src || ''
    ];
  })
};
const v2BJson = JSON.stringify(v2B);
const v2BGzip = zlib.gzipSync(Buffer.from(v2BJson, 'utf8'), { level: 9 });
const v2BB64 = toB64Url(v2BGzip);
console.log('\n--- FORMAT V2-B (CDN Prefix Compression) ---');
console.log('JSON size:', v2BJson.length);
console.log('Gzip size:', v2BGzip.length);
console.log('Base64url size:', v2BB64.length);
console.log('Full URL size:', ('https://ankitcodes30.github.io/Orvia/playlist?name=Creator%27s+Choice&data=' + v2BB64).length);

// 4. Compact Scheme C: If thumb is empty or equals playlist art or can be omitted when identical
// What if thumb is only stored when it differs from playlistArt?
// Wait, for 47 tracks, every song has its own song artwork.
// What if thumb is stripped of common domain prefix, and trailing empty fields are popped?
const v2C = {
  v: 2,
  t: raw.t,
  d: raw.d,
  art: raw.art,
  tr: raw.tr.map(t => {
    let th = t.th || '';
    if (th.startsWith('https://c.saavncdn.com/')) {
      th = '1:' + th.slice(23);
    } else if (th.startsWith('https://i.ytimg.com/vi/')) {
      th = '2:' + th.slice(23);
    }
    const arr = [t.id, t.t, t.a || '', t.al || '', th, t.src || ''];
    while (arr.length > 2 && arr[arr.length - 1] === '') {
      arr.pop();
    }
    return arr;
  })
};
const v2CJson = JSON.stringify(v2C);
const v2CGzip = zlib.gzipSync(Buffer.from(v2CJson, 'utf8'), { level: 9 });
const v2CB64 = toB64Url(v2CGzip);
console.log('\n--- FORMAT V2-C (Domain index + trimmed tuples) ---');
console.log('JSON size:', v2CJson.length);
console.log('Gzip size:', v2CGzip.length);
console.log('Base64url size:', v2CB64.length);
console.log('Full URL size:', ('https://ankitcodes30.github.io/Orvia/playlist?name=Creator%27s+Choice&data=' + v2CB64).length);
