<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { base } from '$app/paths';
  import * as fflate from 'fflate';

  let playlistTitle = 'Shared Playlist';
  let playlistDescription = '';
  let playlistArt = '';
  let tracks = [];
  let shortId = '';
  let isLoading = true;
  let isInvalid = false;
  let errorMessage = '';
  let appLink = 'orvia://p';
  let showFallbackNote = false;
  let isMobile = false;

  // Configurable short-link API resolver endpoint
  // When an external backend (e.g. Cloudflare Worker KV or Supabase) is configured, this endpoint is queried.
  const API_RESOLVER_BASE = typeof window !== 'undefined' && window.__ORVIA_RESOLVER_URL
    ? window.__ORVIA_RESOLVER_URL
    : '';

  function decompressData(base64UrlStr) {
    if (!base64UrlStr || typeof base64UrlStr !== 'string') return null;

    let clean = base64UrlStr.trim().replace(/[\s\r\n]+/g, '');
    clean = clean.replace(/^[`'"]+/, '').replace(/[`'"]+$/, '');
    if (clean.startsWith('<') && clean.endsWith('>')) {
      clean = clean.substring(1, clean.length - 1);
    }
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

    if (bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b) {
      try {
        const decompressed = fflate.gunzipSync(bytes);
        const text = new TextDecoder().decode(decompressed);
        return JSON.parse(text);
      } catch (e) {
        console.warn('gunzipSync error:', e);
      }
    }

    try {
      return JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      return null;
    }
  }

  function parseTracksFromPayload(rawTracks, art) {
    return (rawTracks || []).map((item, index) => {
      if (Array.isArray(item)) {
        const id = item[0] || '';
        const parts = id.split('::');
        const rawLocalId = parts.length > 1 ? parts[parts.length - 1] : id;
        const src = item[5] || '';
        let thumb = item[4] || '';
        if (thumb.startsWith('~')) {
          thumb = 'https://c.saavncdn.com/' + thumb.slice(1);
        } else if (thumb.startsWith('^')) {
          thumb = 'https://i.ytimg.com/vi/' + thumb.slice(1);
        }
        if (thumb.endsWith('@')) {
          thumb = thumb.slice(0, -1) + '-500x500.webp';
        } else if (thumb.endsWith('$')) {
          thumb = thumb.slice(0, -1) + '-500x500.jpg';
        }
        if (!thumb && (rawLocalId.length === 11 || src === 'youtube' || src === 'ytmusic')) {
          thumb = `https://i.ytimg.com/vi/${rawLocalId}/hqdefault.jpg`;
        }
        return {
          id,
          title: item[1] || `Track ${index + 1}`,
          artist: item[2] || '',
          album: item[3] || '',
          thumb: thumb || art || '',
          src,
          providerUrl: item[6] || ''
        };
      } else {
        const id = item.id || '';
        const src = item.src || '';
        return {
          id,
          title: item.title || item.t || `Track ${index + 1}`,
          artist: item.artist || item.a || '',
          album: item.album || item.al || '',
          thumb: item.thumb || item.th || art || '',
          src,
          providerUrl: item.providerUrl || item.u || ''
        };
      }
    });
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
      const url = $page.url;
      const params = url.searchParams;

      // Extract short ID from query (?id=...), path (/p/abc1234), or hash (#abc1234)
      shortId = params.get('id') || '';
      if (!shortId) {
        const segments = url.pathname.split('/').filter(Boolean);
        const pIdx = segments.indexOf('p');
        if (pIdx !== -1 && pIdx + 1 < segments.length) {
          shortId = segments[pIdx + 1];
        }
      }
      if (!shortId && url.hash && url.hash.length > 1) {
        shortId = url.hash.slice(1);
      }

      // Check for inline data payload fallback
      const dataParam = params.get('data') || params.get('d');
      if (dataParam) {
        const decoded = decompressData(dataParam);
        if (decoded) {
          playlistTitle = decoded.t || decoded.title || 'Shared Playlist';
          playlistDescription = decoded.d || decoded.description || '';
          playlistArt = decoded.art || decoded.thumbnail || '';
          tracks = parseTracksFromPayload(decoded.tr || decoded.tracks, playlistArt);
          if (!playlistArt && tracks.length > 0 && tracks[0].thumb) {
            playlistArt = tracks[0].thumb;
          }
          appLink = `orvia://playlist?data=${encodeURIComponent(dataParam)}`;
          isLoading = false;
          return;
        }
      }

      if (!shortId || !/^[a-zA-Z0-9_-]{4,32}$/.test(shortId)) {
        isInvalid = true;
        errorMessage = 'No valid playlist short ID was found in this link.';
        isLoading = false;
        return;
      }

      appLink = `orvia://p/${shortId}`;

      // Resolve from remote API if configured
      if (API_RESOLVER_BASE) {
        try {
          const resp = await fetch(`${API_RESOLVER_BASE}/${shortId}`, {
            headers: { 'Accept': 'application/json' }
          });

          if (resp.ok) {
            const data = await resp.json();
            playlistTitle = data.title || data.t || 'Shared Playlist';
            playlistDescription = data.description || data.d || '';
            playlistArt = data.artworkUrl || data.art || '';
            tracks = parseTracksFromPayload(data.tracks || data.tr, playlistArt);
            if (!playlistArt && tracks.length > 0 && tracks[0].thumb) {
              playlistArt = tracks[0].thumb;
            }
            isLoading = false;
            return;
          } else if (resp.status === 404 || resp.status === 410) {
            isInvalid = true;
            errorMessage = 'This playlist link has expired or was removed by the sender.';
            isLoading = false;
            return;
          }
        } catch (fetchErr) {
          console.warn('Short-link resolver request failed:', fetchErr);
        }
      }

      // If no remote backend responded or is configured yet, display clear professional guidance
      isInvalid = true;
      errorMessage = 'This short link requires an active resolver endpoint or has expired. You can open Orvia directly or ask the sender to share the self-contained playlist link.';
    } catch (err) {
      console.error('Error resolving short playlist:', err);
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
    const el = document.getElementById('shortlink-track-list');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  }
</script>

<svelte:head>
  <title>{tracks.length > 0 ? `${playlistTitle} (${tracks.length} tracks) | Orvia` : (playlistTitle && playlistTitle !== 'Shared Playlist' ? `${playlistTitle} | Orvia` : 'Shared Playlist | Orvia')}</title>
  <meta name="description" content={tracks.length > 0 ? `Listen to "${playlistTitle}" (${tracks.length} tracks) on Orvia - Free, Private, Beautiful Music Player.` : `Listen to "${playlistTitle}" on Orvia - Free, Private, Beautiful Music Player.`} />
  <meta property="og:type" content="music.playlist" />
  <meta property="og:site_name" content="Orvia" />
  <meta property="og:title" content={`${playlistTitle} | Orvia`} />
  <meta property="og:description" content={`Explore "${playlistTitle}" on Orvia.`} />
  {#if playlistArt}
    <meta property="og:image" content={playlistArt} />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:image" content={playlistArt} />
  {/if}
  <meta name="twitter:title" content={`${playlistTitle} | Orvia`} />
</svelte:head>

<div class="playlist-container">
  <div class="card">
    {#if isLoading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>Resolving shared playlist...</p>
      </div>
    {:else if isInvalid}
      <div class="error-state">
        <div class="error-icon">
          <svg viewBox="0 0 24 24" width="48" height="48" fill="currentColor">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
          </svg>
        </div>
        <h1 class="title">Playlist Unavailable</h1>
        <p class="error-text">{errorMessage}</p>
        <div class="actions">
          <a href={appLink} class="btn btn-primary" on:click={handleOpenInApp} id="shortlink-open-orvia">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
              <path d="M8 5v14l11-7z"/>
            </svg>
            Try Opening in Orvia App
          </a>
          <a href="https://ankitcodes30.github.io/Orvia/" class="btn btn-outline" id="shortlink-error-back-home">
            Get Orvia Music Player
          </a>
        </div>
        {#if showFallbackNote}
          <div class="fallback-note">
            <p>App didn't open? Orvia might not be installed yet.</p>
            <a href="https://ankitcodes30.github.io/Orvia/" class="fallback-link">Download Orvia Free</a>
          </div>
        {/if}
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

      <!-- Action Buttons -->
      <div class="actions">
        <a href={appLink} class="btn btn-primary" on:click={handleOpenInApp} id="shortlink-open-orvia">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M8 5v14l11-7z"/>
          </svg>
          Open in Orvia App
        </a>

        {#if tracks.length > 0}
          <button type="button" class="btn btn-secondary" on:click={scrollToTracks} id="shortlink-listen-playlist">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
              <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
            </svg>
            Listen to Playlist ({tracks.length})
          </button>
        {/if}

        <a href="https://ankitcodes30.github.io/Orvia/" class="btn btn-outline" id="shortlink-get-app">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/>
          </svg>
          Get Orvia Android / Desktop
        </a>

        {#if showFallbackNote}
          <div class="fallback-note">
            <p>App didn't open? Orvia might not be installed yet.</p>
            <a href="https://ankitcodes30.github.io/Orvia/" class="fallback-link">Download Orvia Free</a>
          </div>
        {/if}
      </div>

      <!-- Track List Section -->
      {#if tracks.length > 0}
        <div class="tracks-section" id="shortlink-track-list">
          <div class="tracks-header">
            <h3>Track List ({tracks.length})</h3>
            <span class="source-hint">Tap source to listen online</span>
          </div>

          <div class="tracks-list">
            {#each tracks as track, index}
              <div class="track-item">
                <span class="track-num">{index + 1}</span>
                <div class="track-art">
                  {#if track.thumb}
                    <img src={track.thumb} alt={track.title} loading="lazy" />
                  {:else}
                    <div class="track-placeholder">🎵</div>
                  {/if}
                </div>
                <div class="track-info">
                  <div class="track-title">{track.title}</div>
                  <div class="track-artist">{track.artist || 'Unknown Artist'}{#if track.album} • {track.album}{/if}</div>
                </div>
                {#if getOriginalSourceUrl(track)}
                  <a
                    href={getOriginalSourceUrl(track)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="source-link"
                    title="Listen on {track.src === 'youtube' || track.src === 'ytmusic' ? 'YouTube' : 'JioSaavn'}"
                  >
                    {#if track.src === 'youtube' || track.src === 'ytmusic' || (track.id && track.id.length === 11)}
                      ▶ YouTube
                    {:else}
                      ▶ JioSaavn
                    {/if}
                  </a>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/if}
    {/if}

    <p class="footnote">
      Orvia is free and open-source. Listen ad-free on Android & Windows.
    </p>
  </div>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    background-color: #0b0f19;
    color: #f3f4f6;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    min-height: 100vh;
  }

  .playlist-container {
    min-height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 24px 16px;
    box-sizing: border-box;
    background: radial-gradient(circle at 50% 20%, rgba(99, 102, 241, 0.15), transparent 70%),
                radial-gradient(circle at 80% 80%, rgba(168, 85, 247, 0.1), transparent 50%),
                #0b0f19;
  }

  .card {
    background: rgba(17, 24, 39, 0.85);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 24px;
    padding: 32px 24px;
    width: 100%;
    max-width: 520px;
    box-shadow: 0 20px 40px -15px rgba(0, 0, 0, 0.5),
                0 0 50px -10px rgba(99, 102, 241, 0.2);
    text-align: center;
    box-sizing: border-box;
  }

  .artwork-wrapper {
    width: 180px;
    height: 180px;
    margin: 0 auto 24px;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 12px 24px -6px rgba(0, 0, 0, 0.6),
                0 0 20px rgba(99, 102, 241, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.15);
    background: #1e1b4b;
  }

  .artwork {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .placeholder-art {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(255, 255, 255, 0.4);
    background: linear-gradient(135deg, #1e1b4b, #312e81);
  }

  .badge {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 20px;
    background: rgba(99, 102, 241, 0.2);
    border: 1px solid rgba(99, 102, 241, 0.4);
    color: #a5b4fc;
    font-size: 0.72rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    margin-bottom: 12px;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0 0 8px;
    color: #ffffff;
    line-height: 1.25;
  }

  .subtitle {
    font-size: 0.92rem;
    color: #9ca3af;
    margin: 0 0 24px;
    line-height: 1.4;
  }

  .actions {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 24px;
  }

  .btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    padding: 14px 20px;
    border-radius: 14px;
    font-size: 0.95rem;
    font-weight: 600;
    text-decoration: none;
    cursor: pointer;
    transition: all 0.2s ease;
    border: none;
    box-sizing: border-box;
    width: 100%;
  }

  .btn-primary {
    background: linear-gradient(135deg, #6366f1, #8b5cf6);
    color: #ffffff;
    box-shadow: 0 4px 14px rgba(99, 102, 241, 0.4);
  }

  .btn-primary:hover {
    background: linear-gradient(135deg, #4f46e5, #7c3aed);
    box-shadow: 0 6px 20px rgba(99, 102, 241, 0.6);
    transform: translateY(-1px);
  }

  .btn-secondary {
    background: rgba(255, 255, 255, 0.08);
    color: #e0e7ff;
    border: 1px solid rgba(255, 255, 255, 0.15);
  }

  .btn-secondary:hover {
    background: rgba(255, 255, 255, 0.14);
    transform: translateY(-1px);
  }

  .btn-outline {
    background: transparent;
    color: #c7d2fe;
    border: 1px solid rgba(99, 102, 241, 0.35);
  }

  .btn-outline:hover {
    background: rgba(99, 102, 241, 0.1);
    border-color: rgba(99, 102, 241, 0.6);
  }

  .fallback-note {
    background: rgba(99, 102, 241, 0.1);
    border: 1px solid rgba(99, 102, 241, 0.25);
    border-radius: 12px;
    padding: 12px 16px;
    margin-top: 4px;
  }

  .fallback-note p {
    margin: 0 0 6px;
    font-size: 0.85rem;
    color: #c7d2fe;
  }

  .fallback-link {
    color: #a5b4fc;
    font-weight: 600;
    font-size: 0.85rem;
    text-decoration: underline;
  }

  .tracks-section {
    text-align: left;
    margin-top: 8px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    padding-top: 20px;
  }

  .tracks-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }

  .tracks-header h3 {
    margin: 0;
    font-size: 1rem;
    font-weight: 700;
    color: #e0e7ff;
  }

  .source-hint {
    font-size: 0.72rem;
    color: rgba(255, 255, 255, 0.4);
  }

  .tracks-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    max-height: 380px;
    overflow-y: auto;
    padding-right: 4px;
  }

  .track-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 10px;
    border-radius: 10px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: background 0.15s ease;
  }

  .track-item:hover {
    background: rgba(255, 255, 255, 0.07);
  }

  .track-num {
    font-size: 0.75rem;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.4);
    min-width: 20px;
    text-align: center;
  }

  .track-art {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    overflow: hidden;
    flex-shrink: 0;
    background: #1e1b4b;
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
    line-height: 1.5;
  }

  .footnote {
    font-size: 0.78rem;
    color: rgba(255, 255, 255, 0.35);
    margin: 20px 0 0;
    line-height: 1.4;
  }
</style>
