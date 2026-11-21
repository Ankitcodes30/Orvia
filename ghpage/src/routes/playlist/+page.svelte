<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import * as fflate from 'fflate';

  let playlistTitle = 'Orvia Playlist';
  let playlistDescription = '';
  let playlistArt = '';
  let tracks = [];
  let isLoading = true;
  let isInvalid = false;
  let errorMessage = '';
  let appLink = 'orvia://playlist';
  let showFallbackNote = false;
  let isMobile = false;
  let isPartiallyRecovered = false;

  function decompressData(base64UrlStr) {
    if (!base64UrlStr || typeof base64UrlStr !== 'string') return null;

    let clean = base64UrlStr.trim().replace(/[\s\r\n]+/g, '');
    clean = clean.replace(/^[`'"]+/, '').replace(/[`'"]+$/, '');
    if (clean.startsWith('<') && clean.endsWith('>')) {
      clean = clean.substring(1, clean.length - 1);
    }

    // Incomplete base64 check: A valid base64 stream never ends with length % 4 === 1.
    // If cut off mid-character by a URL length limit or messenger, drop the 1 orphan char.
    if (clean.length % 4 === 1) {
      clean = clean.slice(0, -1);
    }

    let base64 = clean.replace(/-/g, '+').replace(/_/g, '/');
    while (base64.length % 4 !== 0) {
      base64 += '=';
    }

    let binaryStr;
    try {
      binaryStr = atob(base64);
    } catch {
      return null;
    }

    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    // 1. Try fflate gunzipSync (pure-JS, works in all environments and WebViews)
    if (bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b) {
      try {
        const decompressed = fflate.gunzipSync(bytes);
        const text = new TextDecoder().decode(decompressed);
        return JSON.parse(text);
      } catch (e) {
        console.warn('fflate gunzipSync error, attempting streaming recovery:', e);
      }

      // 1b. Fallback: Streaming gunzip recovery for truncated payloads
      try {
        const chunks = [];
        const gunzip = new fflate.Gunzip((chunk) => {
          chunks.push(chunk);
        });
        try {
          gunzip.push(bytes, false);
        } catch (_) {}

        const totalLen = chunks.reduce((acc, c) => acc + c.length, 0);
        if (totalLen > 0) {
          const merged = new Uint8Array(totalLen);
          let offset = 0;
          for (const c of chunks) {
            merged.set(c, offset);
            offset += c.length;
          }
          const text = new TextDecoder().decode(merged);
          const lastObjIndex = text.lastIndexOf('},');
          const lastArrIndex = text.lastIndexOf('],');
          const lastValidIndex = Math.max(lastObjIndex, lastArrIndex);
          if (lastValidIndex !== -1) {
            const recoveredJsonStr = text.slice(0, lastValidIndex + 1) + ']}';
            const parsed = JSON.parse(recoveredJsonStr);
            if (parsed && (parsed.tr || parsed.tracks)) {
              isPartiallyRecovered = true;
              return parsed;
            }
          }
        }
      } catch (streamErr) {
        console.warn('Streaming gunzip recovery error:', streamErr);
      }
    }

    // 2. Fallback: UTF-8 plain JSON
    try {
      const textDecoder = new TextDecoder();
      const text = textDecoder.decode(bytes);
      return JSON.parse(text);
    } catch {
      return null;
    }
  }

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

  function getOriginalSourceUrl(track) {
    if (track.providerUrl && track.providerUrl.startsWith('http')) {
      return track.providerUrl;
    }
    const id = track.id || '';
    const src = track.src || '';
    const parts = id.split('::');
    const rawLocalId = parts.length > 1 ? parts[parts.length - 1] : id;

    if (rawLocalId.length === 11 || src === 'youtube' || src === 'ytmusic') {
      return `https://www.youtube.com/watch?v=${rawLocalId}`;
    }
    if (src === 'saavn' || id.includes('saavn')) {
      return `https://www.jiosaavn.com/song/${rawLocalId}`;
    }
    return '';
  }

  onMount(async () => {
    isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);

    try {
      const params = $page.url.searchParams;
      const dataParam = params.get('data');
      const nameParam = params.get('name') || params.get('title') || '';
      const idParam = params.get('id') || '';

      if (nameParam) {
        playlistTitle = nameParam;
      }

      if (dataParam) {
        try {
          const decoded = await decompressData(dataParam);
          if (decoded) {
            playlistTitle = decoded.t || decoded.title || nameParam || 'Shared Playlist';
            playlistDescription = decoded.d || decoded.desc || decoded.description || '';
            playlistArt = decoded.art || decoded.thumbnail || '';
            
            const rawTracks = decoded.tr || decoded.tracks || [];
            tracks = rawTracks.map((item, index) => {
              if (Array.isArray(item)) {
                // v2 tuple: [id, title, artist, album, thumb, src, url]
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
                // v1 legacy map
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

            if (!playlistArt && tracks.length > 0 && tracks[0].thumb) {
              playlistArt = tracks[0].thumb;
            }
          } else {
            throw new Error('Could not parse playlist data.');
          }
        } catch (e) {
          console.warn('Playlist data decompression error:', e);
          playlistTitle = nameParam || playlistTitle || 'Shared Playlist';
          if (tracks.length === 0) {
            isInvalid = true;
            errorMessage = 'The playlist track data appears incomplete or corrupted. You can still open it in the Orvia app if already saved, or ask the sender to share it again.';
          }
        }
      } else if (nameParam) {
        playlistTitle = nameParam;
      } else if (idParam) {
        playlistTitle = `Playlist #${idParam}`;
      } else {
        isInvalid = true;
        errorMessage = 'No playlist data was found in this link.';
      }

      // Build app deep link
      const appUrl = new URL('orvia://playlist');
      $page.url.searchParams.forEach((value, key) => {
        appUrl.searchParams.append(key, value);
      });

      // If we recovered tracks from a truncated link, re-encode into a valid gzip payload
      // so opening in Orvia App receives a clean, complete payload without decoding errors!
      if (isPartiallyRecovered && tracks.length > 0) {
        try {
          const recPayload = {
            v: 2,
            t: playlistTitle,
            d: playlistDescription ? `${playlistDescription} (Partially recovered)` : 'Partially recovered from link',
            art: playlistArt,
            tr: tracks.map((t) => {
              const tuple = [
                t.id,
                t.title,
                t.artist,
                t.album,
                compressThumb(t.thumb, playlistArt),
                t.src,
                t.providerUrl
              ];
              while (tuple.length > 2 && tuple[tuple.length - 1] === '') {
                tuple.pop();
              }
              return tuple;
            })
          };
          const jsonBytes = new TextEncoder().encode(JSON.stringify(recPayload));
          const gz = fflate.gzipSync(jsonBytes, { level: 9 });
          let binary = '';
          for (let i = 0; i < gz.length; i++) {
            binary += String.fromCharCode(gz[i]);
          }
          const recB64 = btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
          appUrl.searchParams.set('data', recB64);
        } catch (reErr) {
          console.warn('Could not re-encode recovered payload for appLink:', reErr);
        }
      }

      appLink = appUrl.toString();
    } catch (err) {
      console.error('Error loading playlist:', err);
      isInvalid = true;
      errorMessage = 'Failed to load shared playlist.';
    } finally {
      isLoading = false;
    }
  });

  function handleOpenInApp() {
    setTimeout(() => {
      if (typeof document !== 'undefined' && !document.hidden) {
        showFallbackNote = true;
      }
    }, 2500);
  }

  function scrollToTracks() {
    const el = document.getElementById('playlist-track-list');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  }
</script>

<svelte:head>
  <title>{tracks.length > 0 ? `${playlistTitle} (${tracks.length} tracks) | Orvia` : (playlistTitle && playlistTitle !== 'Orvia Playlist' ? `${playlistTitle} | Orvia Playlist` : 'Orvia Playlist | Free Music Player')}</title>
  <meta name="description" content={tracks.length > 0 ? `Listen to "${playlistTitle}" (${tracks.length} songs) on Orvia - Free, Private, Beautiful Music Player.` : `Listen to "${playlistTitle}" on Orvia - Free, Private, Beautiful Music Player.`} />
  <meta property="og:type" content="music.playlist" />
  <meta property="og:site_name" content="Orvia" />
  <meta property="og:title" content={tracks.length > 0 ? `${playlistTitle} (${tracks.length} songs) | Orvia` : `${playlistTitle} | Orvia`} />
  <meta property="og:description" content={tracks.length > 0 ? `Explore ${tracks.length} songs in "${playlistTitle}" on Orvia.` : `Explore "${playlistTitle}" on Orvia.`} />
  {#if playlistArt}
    <meta property="og:image" content={playlistArt} />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:image" content={playlistArt} />
  {/if}
  <meta name="twitter:title" content={tracks.length > 0 ? `${playlistTitle} (${tracks.length} songs) | Orvia` : `${playlistTitle} | Orvia`} />
  <meta name="twitter:description" content={tracks.length > 0 ? `Explore ${tracks.length} songs in "${playlistTitle}" on Orvia.` : `Explore "${playlistTitle}" on Orvia.`} />
</svelte:head>

<div class="playlist-container">
  <div class="card">
    {#if isLoading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>Loading shared playlist...</p>
      </div>
    {:else if isInvalid}
      <div class="error-state">
        <div class="error-icon">
          <svg viewBox="0 0 24 24" width="48" height="48" fill="currentColor">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
          </svg>
        </div>
        <h1 class="title">{playlistTitle && playlistTitle !== 'Orvia Playlist' ? playlistTitle : 'Playlist Unavailable'}</h1>
        <p class="error-text">{errorMessage || 'The requested playlist link is incomplete or invalid.'}</p>
        <div class="actions">
          <a href="https://ankitcodes30.github.io/Orvia/" class="btn btn-primary">
            Get Orvia Music Player
          </a>
        </div>
      </div>
    {:else}
      <!-- Header with Playlist Info -->
      <div class="artwork-wrapper">
        {#if playlistArt}
          <img src={playlistArt} alt={playlistTitle} class="artwork" />
        {:else}
          <div class="placeholder-art">
            <svg viewBox="0 0 24 24" width="56" height="56" fill="currentColor">
              <path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z"/>
            </svg>
          </div>
        {/if}
      </div>

      <div class="meta">
        <span class="badge">SHARED PLAYLIST</span>
        <h1 class="title">{playlistTitle}</h1>
        <p class="subtitle">
          {tracks.length} {tracks.length === 1 ? 'song' : 'songs'}
          {#if playlistDescription} • {playlistDescription}{/if}
        </p>
      </div>

      {#if isPartiallyRecovered}
        <div class="partial-recovery-banner" id="partial-recovery-banner">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>
          </svg>
          <div class="partial-recovery-text">
            <strong>Partial Playlist Recovery</strong>
            <span>This shared link was truncated during transfer. {tracks.length} tracks were safely recovered.</span>
          </div>
        </div>
      {/if}

      <!-- Action Buttons -->
      <div class="actions">
        <!-- Button 1: Open in Orvia App -->
        <a href={appLink} class="btn btn-primary" on:click={handleOpenInApp} id="btn-open-in-orvia">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M8 5v14l11-7z"/>
          </svg>
          Open in Orvia App
        </a>

        <!-- Button 2: Listen to Playlist -->
        {#if tracks.length > 0}
          <button type="button" class="btn btn-secondary" on:click={scrollToTracks} id="btn-listen-playlist">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
              <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
            </svg>
            Listen to Playlist ({tracks.length})
          </button>
        {/if}

        <!-- Button 3: Get Orvia Android/Desktop -->
        <a href="https://ankitcodes30.github.io/Orvia/" class="btn btn-outline" id="btn-get-orvia">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/>
          </svg>
          Get Orvia Android / Desktop
        </a>

        <!-- Save This Playlist Info Box -->
        <div class="save-box">
          <div class="save-icon">
            <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
              <path d="M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2zm0 15l-5-2.18L7 18V5h10v13z"/>
            </svg>
          </div>
          <div class="save-text">
            <strong>Save This Playlist</strong>
            <p>Open this playlist in the Orvia app to save a local, editable copy directly to your library.</p>
          </div>
        </div>

        {#if showFallbackNote}
          <div class="fallback-note">
            <p>App didn't open? Orvia might not be installed yet.</p>
            <a href="https://ankitcodes30.github.io/Orvia/" class="fallback-link">Download Orvia Free</a>
          </div>
        {/if}
      </div>

      <!-- Track List Section -->
      {#if tracks.length > 0}
        <div class="tracks-section" id="playlist-track-list">
          <div class="tracks-header">
            <h3>Track List ({tracks.length})</h3>
            <span class="source-hint">Tap source to listen online</span>
          </div>

          <div class="tracks-list">
            {#each tracks as track, index}
              {@const sourceUrl = getOriginalSourceUrl(track)}
              <div class="track-item">
                <span class="track-number">{index + 1}</span>
                <div class="track-art">
                  {#if track.thumb}
                    <img src={track.thumb} alt={track.title} loading="lazy" />
                  {:else}
                    <div class="track-placeholder">🎵</div>
                  {/if}
                </div>
                <div class="track-info">
                  <div class="track-title">{track.title}</div>
                  {#if track.artist}
                    <div class="track-artist">{track.artist}</div>
                  {/if}
                </div>
                {#if sourceUrl}
                  <a href={sourceUrl} target="_blank" rel="noopener noreferrer" class="source-link" title="Listen on Original Source">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                      <path d="M10 6v12l10-6z"/>
                    </svg>
                    <span>Play</span>
                  </a>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {:else}
        <p class="empty-note">This playlist does not contain any tracks yet.</p>
      {/if}

      <p class="footnote">
        Orvia is a modern, privacy-focused open source music client for high fidelity streaming.
      </p>
    {/if}
  </div>
</div>

<style>
  .playlist-container {
    min-height: 85vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 32px 16px;
  }

  .card {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 24px;
    padding: 36px 28px;
    max-width: 580px;
    width: 100%;
    text-align: center;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5);
  }

  .artwork-wrapper {
    width: 180px;
    height: 180px;
    margin: 0 auto 20px;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 12px 28px rgba(0, 0, 0, 0.5);
    background: #1a1a24;
  }

  .artwork {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  .placeholder-art {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #818cf8;
    background: rgba(99, 102, 241, 0.15);
  }

  .badge {
    display: inline-block;
    padding: 4px 10px;
    border-radius: 12px;
    background: rgba(99, 102, 241, 0.15);
    color: #a5b4fc;
    font-size: 0.72rem;
    font-weight: 700;
    letter-spacing: 1px;
    margin-bottom: 8px;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0 0 6px;
    color: #ffffff;
    line-height: 1.3;
  }

  .subtitle {
    font-size: 0.95rem;
    color: #a5b4fc;
    margin: 0 0 24px;
    font-weight: 500;
  }

  .partial-recovery-banner {
    display: flex;
    align-items: center;
    gap: 12px;
    background: rgba(234, 179, 8, 0.12);
    border: 1px solid rgba(234, 179, 8, 0.4);
    color: #fef08a;
    border-radius: 14px;
    padding: 12px 16px;
    margin: 16px 0 20px;
    text-align: left;
    font-size: 0.88rem;
    line-height: 1.4;
  }

  .partial-recovery-banner svg {
    flex-shrink: 0;
    color: #facc15;
  }

  .partial-recovery-text strong {
    display: block;
    color: #fef08a;
    font-weight: 600;
    margin-bottom: 2px;
  }

  .partial-recovery-text span {
    color: rgba(254, 240, 138, 0.85);
  }

  .actions {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 24px;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 14px 20px;
    border-radius: 14px;
    font-weight: 600;
    font-size: 0.95rem;
    text-decoration: none;
    transition: all 0.2s ease;
    cursor: pointer;
    border: none;
  }

  .btn-primary {
    background: #6366f1;
    color: #ffffff;
    box-shadow: 0 4px 16px rgba(99, 102, 241, 0.4);
  }

  .btn-primary:hover {
    background: #4f46e5;
    transform: translateY(-1px);
  }

  .btn-secondary {
    background: rgba(255, 255, 255, 0.08);
    color: #ffffff;
    border: 1px solid rgba(255, 255, 255, 0.15);
  }

  .btn-secondary:hover {
    background: rgba(255, 255, 255, 0.14);
  }

  .btn-outline {
    background: transparent;
    color: #a5b4fc;
    border: 1px solid rgba(165, 180, 252, 0.3);
  }

  .btn-outline:hover {
    background: rgba(99, 102, 241, 0.08);
    border-color: #6366f1;
  }

  .save-box {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    border-radius: 14px;
    background: rgba(99, 102, 241, 0.08);
    border: 1px solid rgba(99, 102, 241, 0.2);
    text-align: left;
  }

  .save-icon {
    color: #818cf8;
    flex-shrink: 0;
  }

  .save-text strong {
    display: block;
    font-size: 0.88rem;
    color: #ffffff;
    margin-bottom: 2px;
  }

  .save-text p {
    font-size: 0.78rem;
    color: #cbd5e1;
    margin: 0;
    line-height: 1.35;
  }

  .fallback-note {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 10px 14px;
    font-size: 0.85rem;
    color: #e0e7ff;
    display: flex;
    flex-direction: column;
    gap: 6px;
    align-items: center;
  }

  .fallback-note p {
    margin: 0;
  }

  .fallback-link {
    color: #818cf8;
    font-weight: 600;
    text-decoration: underline;
    text-underline-offset: 3px;
  }

  .tracks-section {
    margin-top: 28px;
    text-align: left;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    padding-top: 20px;
  }

  .tracks-header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-bottom: 12px;
  }

  .tracks-header h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #ffffff;
    font-weight: 700;
  }

  .source-hint {
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.45);
  }

  .tracks-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    max-height: 380px;
    overflow-y: auto;
    padding-right: 4px;
  }

  .tracks-list::-webkit-scrollbar {
    width: 6px;
  }
  .tracks-list::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.15);
    border-radius: 3px;
  }

  .track-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 10px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: background 0.2s ease;
  }

  .track-item:hover {
    background: rgba(255, 255, 255, 0.07);
  }

  .track-number {
    width: 22px;
    text-align: center;
    font-size: 0.8rem;
    color: rgba(255, 255, 255, 0.4);
    font-weight: 600;
    flex-shrink: 0;
  }

  .track-art {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    overflow: hidden;
    flex-shrink: 0;
    background: #111;
  }

  .track-art img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .track-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.9rem;
  }

  .track-info {
    flex: 1;
    min-width: 0;
  }

  .track-title {
    font-size: 0.88rem;
    font-weight: 600;
    color: #ffffff;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .track-artist {
    font-size: 0.78rem;
    color: #a5b4fc;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .source-link {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 6px 10px;
    border-radius: 8px;
    background: rgba(99, 102, 241, 0.15);
    color: #c7d2fe;
    font-size: 0.75rem;
    font-weight: 600;
    text-decoration: none;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .source-link:hover {
    background: #6366f1;
    color: #ffffff;
  }

  .empty-note {
    font-size: 0.88rem;
    color: rgba(255, 255, 255, 0.5);
    margin: 20px 0;
  }

  .loading-state, .error-state {
    padding: 30px 10px;
  }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid rgba(99, 102, 241, 0.2);
    border-top-color: #6366f1;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 0 auto 16px;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .error-icon {
    color: #f87171;
    margin-bottom: 16px;
  }

  .error-text {
    color: rgba(255, 255, 255, 0.6);
    font-size: 0.9rem;
    margin-bottom: 20px;
  }

  .footnote {
    font-size: 0.78rem;
    color: rgba(255, 255, 255, 0.35);
    margin: 20px 0 0;
    line-height: 1.4;
  }
</style>
