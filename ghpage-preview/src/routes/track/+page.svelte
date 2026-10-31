<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';

  let title = 'Orvia Track';
  let artist = '';
  let album = '';
  let thumb = '';
  let providerUrl = '';
  let shareDescription = 'Listen to this track on Orvia - Free, Private, Beautiful Music Player.';
  let appLink = 'orvia://track';
  let isMobile = false;

  onMount(() => {
    const params = $page.url.searchParams;
    const trackId = params.get('id') || '';
    if (!trackId || trackId.trim() === '') {
      title = 'Song Unavailable';
      artist = 'The requested track link is incomplete or unavailable.';
      shareDescription = 'Track unavailable. Download Orvia to explore and stream millions of songs.';
    } else {
      title = params.get('title') || 'Shared Song';
      artist = params.get('artist') || '';
      album = params.get('album') || '';
      thumb = params.get('thumb') || '';
      providerUrl = params.get('providerUrl') || '';
      const src = params.get('src') || '';
      if (!providerUrl && ((trackId.length === 11 && !trackId.includes(':')) || src === 'youtube' || src === 'ytmusic')) {
        providerUrl = `https://www.youtube.com/watch?v=${trackId}`;
      } else if (!providerUrl && (src === 'saavn' || trackId.includes('saavn'))) {
        const parts = trackId.split('::');
        const rawId = parts.length > 1 ? parts[parts.length - 1] : trackId;
        providerUrl = `https://www.jiosaavn.com/song/${rawId}`;
      }
      shareDescription = `Listen to ${title}${artist ? ` by ${artist}` : ''} on Orvia - Free, Private, Beautiful Music Player.`;

      // If thumbnail is a channel avatar (or missing) and ID is an 11-char YouTube ID, use actual video artwork
      if (
        (!thumb ||
          thumb.includes('yt3.ggpht.com') ||
          thumb.includes('yt3.googleusercontent.com')) &&
        trackId.length === 11 &&
        !trackId.includes(':')
      ) {
        thumb = `https://i.ytimg.com/vi/${trackId}/hqdefault.jpg`;
      }
    }

    // Rebuild the link from decoded parameters so each value is encoded once.
    const appUrl = new URL('orvia://track');
    $page.url.searchParams.forEach((value, key) => {
      appUrl.searchParams.append(key, value);
    });
    appLink = appUrl.toString();

    isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
  });

  let showFallbackNote = false;
  function handleOpenInApp() {
    setTimeout(() => {
      if (typeof document !== 'undefined' && !document.hidden) {
        showFallbackNote = true;
      }
    }, 2500);
  }
</script>

<svelte:head>
  <title>{title} {artist ? `by ${artist}` : ''} | Orvia</title>
  <meta name="description" content={shareDescription} />
  <meta property="og:type" content="music.song" />
  <meta property="og:site_name" content="Orvia" />
  <meta property="og:title" content={`${title}${artist ? ` by ${artist}` : ''} | Orvia`} />
  <meta property="og:description" content={shareDescription} />
  {#if thumb}
    <meta property="og:image" content={thumb} />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:image" content={thumb} />
  {/if}
  <meta name="twitter:title" content={`${title}${artist ? ` by ${artist}` : ''} | Orvia`} />
  <meta name="twitter:description" content={shareDescription} />
</svelte:head>

<div class="track-container">
  <div class="card">
    <div class="artwork-wrapper">
      {#if thumb}
        <img src={thumb} alt={title} class="artwork" />
      {:else}
        <div class="placeholder-art">
          <svg viewBox="0 0 24 24" width="48" height="48" fill="currentColor">
            <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
          </svg>
        </div>
      {/if}
    </div>

    <div class="meta">
      <h1 class="title">{title}</h1>
      {#if artist}
        <p class="artist">{artist}</p>
      {/if}
      {#if album}
        <p class="album">{album}</p>
      {/if}
    </div>

    <div class="actions">
      <a href={appLink} class="btn btn-primary" on:click={handleOpenInApp}>
        <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
          <path d="M8 5v14l11-7z"/>
        </svg>
        Open in Orvia App
      </a>

      {#if providerUrl}
        <a href={providerUrl} target="_blank" rel="noopener noreferrer" class="btn btn-secondary">
          Listen on Original Source
        </a>
      {/if}

      <a href="https://ankitcodes30.github.io/Orvia/" class="btn btn-outline">
        Get Orvia Android / Desktop
      </a>

      {#if showFallbackNote}
        <div class="fallback-note">
          <p>App didn't open? Orvia might not be installed yet.</p>
          <a href="https://ankitcodes30.github.io/Orvia/" class="fallback-link">Download Orvia</a>
        </div>
      {/if}
    </div>

    <p class="footnote">
      Orvia is a modern, privacy-focused open source music client for high fidelity streaming.
    </p>
  </div>
</div>

<style>
  .track-container {
    min-height: 85vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px 16px;
  }

  .card {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 24px;
    padding: 36px 28px;
    max-width: 440px;
    width: 100%;
    text-align: center;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
  }

  .artwork-wrapper {
    width: 180px;
    height: 180px;
    margin: 0 auto 24px;
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
    color: #6366f1;
    background: rgba(99, 102, 241, 0.1);
  }

  .title {
    font-size: 1.4rem;
    font-weight: 700;
    margin: 0 0 6px;
    color: #ffffff;
    line-height: 1.3;
  }

  .artist {
    font-size: 1.05rem;
    color: #a5b4fc;
    margin: 0 0 4px;
    font-weight: 500;
  }

  .album {
    font-size: 0.9rem;
    color: rgba(255, 255, 255, 0.5);
    margin: 0 0 24px;
  }

  .actions {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 20px;
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
  }

  .btn-primary {
    background: #6366f1;
    color: #ffffff;
    border: none;
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

  .fallback-link:hover {
    color: #a5b4fc;
  }

  .footnote {
    font-size: 0.8rem;
    color: rgba(255, 255, 255, 0.4);
    margin: 0;
    line-height: 1.4;
  }
</style>
