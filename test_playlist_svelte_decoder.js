const fs = require('fs');
const zlib = require('zlib');

// Mirror functions from +page.svelte
function decompressThumb(raw, art, localId, src) {
  if (!raw) {
    if (localId && (localId.length === 11 || src === 'youtube' || src === 'ytmusic')) {
      return `https://i.ytimg.com/vi/${localId}/hqdefault.jpg`;
    }
    return art || '';
  }
  if (raw === '=') return art || '';
  let s = raw;
  if (s.startsWith('~')) {
    s = 'https://c.saavncdn.com/' + s.slice(1);
  } else if (s.startsWith('^')) {
    s = 'https://i.ytimg.com/vi/' + s.slice(1);
  }
  if (s.endsWith('@')) {
    s = s.slice(0, -1) + '-500x500.webp';
  } else if (s.endsWith('$')) {
    s = s.slice(0, -1) + '-500x500.jpg';
  }
  return s;
}

function compressThumb(url, art) {
  if (!url) return '';
  if (art && url === art) return '=';
  let s = url;
  if (s.startsWith('https://c.saavncdn.com/')) {
    s = '~' + s.slice(23);
  } else if (s.startsWith('https://i.ytimg.com/vi/')) {
    s = '^' + s.slice(23);
  }
  if (s.endsWith('-500x500.webp')) {
    s = s.slice(0, -13) + '@';
  } else if (s.endsWith('$') || s.endsWith('-500x500.jpg')) {
    s = s.slice(0, -12) + '$';
  }
  return s;
}

function parseTracksFromPayload(decoded) {
  const playlistArt = decoded.art || decoded.thumbnail || '';
  const rawTracks = decoded.tr || decoded.tracks || [];
  return rawTracks.map((item, index) => {
    if (Array.isArray(item)) {
      const id = item[0] || '';
      const parts = id.split('::');
      const rawLocalId = parts.length > 1 ? parts[parts.length - 1] : id;
      const src = item[5] || '';
      const thumb = decompressThumb(item[4], playlistArt, rawLocalId, src);
      return {
        id: id,
        title: item[1] || `Track ${index + 1}`,
        artist: item[2] || '',
        album: item[3] || '',
        thumb: thumb,
        src: src,
        providerUrl: item[6] || ''
      };
    } else {
      const id = item.id || '';
      const parts = id.split('::');
      const rawLocalId = parts.length > 1 ? parts[parts.length - 1] : id;
      let thumb = item.th || item.thumb || item.thumbnail || '';
      if (!thumb && (rawLocalId.length === 11 || item.src === 'youtube' || item.src === 'ytmusic')) {
        thumb = `https://i.ytimg.com/vi/${rawLocalId}/hqdefault.jpg`;
      }
      if (!thumb && playlistArt) {
        thumb = playlistArt;
      }
      return {
        id: id,
        title: item.t || item.title || `Track ${index + 1}`,
        artist: item.a || item.artist || '',
        album: item.al || item.album || '',
        thumb: thumb,
        src: item.src || '',
        providerUrl: item.u || item.providerUrl || ''
      };
    }
  });
}

// 1. Test legacy v1 fixture parsing
const fixtureV1 = JSON.parse(fs.readFileSync('creators_choice_fixture.json', 'utf8'));
const tracksV1 = parseTracksFromPayload(fixtureV1);
console.log('V1 parsed track count:', tracksV1.length);
if (tracksV1.length !== 47) throw new Error('V1 track count mismatch');
if (!tracksV1[0].thumb.startsWith('https://c.saavncdn.com/')) throw new Error('V1 thumb missing');

// 2. Test v2 round-trip
const v2Payload = {
  v: 2,
  t: fixtureV1.t,
  d: fixtureV1.d,
  art: fixtureV1.art,
  tr: fixtureV1.tr.map(t => {
    const tuple = [
      t.id,
      t.t,
      t.a || '',
      t.al || '',
      compressThumb(t.th, fixtureV1.art),
      t.src || ''
    ];
    while (tuple.length > 2 && tuple[tuple.length - 1] === '') tuple.pop();
    return tuple;
  })
};

const tracksV2 = parseTracksFromPayload(v2Payload);
console.log('V2 parsed track count:', tracksV2.length);
if (tracksV2.length !== 47) throw new Error('V2 track count mismatch');

// Verify all fields identical between v1 and v2
for (let i = 0; i < 47; i++) {
  if (tracksV1[i].id !== tracksV2[i].id) throw new Error(`ID mismatch at ${i}`);
  if (tracksV1[i].title !== tracksV2[i].title) throw new Error(`Title mismatch at ${i}`);
  if (tracksV1[i].artist !== tracksV2[i].artist) throw new Error(`Artist mismatch at ${i}`);
  if (tracksV1[i].thumb !== tracksV2[i].thumb) throw new Error(`Thumb mismatch at ${i}: ${tracksV1[i].thumb} vs ${tracksV2[i].thumb}`);
}
console.log('PASS: All 47 tracks, IDs, titles, artists, and thumbnails match 100% between v1 and v2!');
