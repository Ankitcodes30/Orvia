<script>
	let isPlaying = false;
	let isLiked = false;
	let progress = 42;
	let activeIndex = 0;

	const demoPlaylist = [
		{
			title: 'Navratri Special Garba',
			artist: 'Traditional Folk Ensemble',
			category: 'Festival Spotlight',
			duration: '3:45',
			accent: '#e52e71'
		},
		{
			title: 'A.K. World Melodies',
			artist: 'A.K. MUSIC WORLD',
			category: 'Piano Instrumental',
			duration: '4:12',
			accent: '#ff8a00'
		},
		{
			title: 'Morning Bhakti Chants',
			artist: 'Spiritual Heritage',
			category: 'Devotional',
			duration: '5:20',
			accent: '#ffd48e'
		},
		{
			title: 'Midnight Lo-Fi Calm',
			artist: 'Orvia Ambient Labs',
			category: 'Chillout',
			duration: '2:58',
			accent: '#8a2be2'
		}
	];

	function togglePlay() {
		isPlaying = !isPlaying;
	}

	function toggleLike() {
		isLiked = !isLiked;
	}

	function selectTrack(index) {
		activeIndex = index;
		progress = 15;
		isPlaying = true;
	}

	function nextTrack() {
		activeIndex = (activeIndex + 1) % demoPlaylist.length;
		progress = 0;
	}

	function prevTrack() {
		activeIndex = (activeIndex - 1 + demoPlaylist.length) % demoPlaylist.length;
		progress = 0;
	}
</script>

<div class="showcase-container">
	<!-- Top Demo Disclaimer Badge -->
	<div class="demo-badge">
		<i class="fa-solid fa-wand-magic-sparkles"></i>
		<span>Interactive Showcase Demo · Visual Preview (Not Connected to Audio Playback)</span>
	</div>

	<div class="player-mockup-wrapper">
		<!-- Phone Chassis -->
		<div class="phone-frame">
			<div class="notch" aria-hidden="true"></div>

			<div class="screen-content">
				<!-- Header Bar -->
				<div class="screen-header">
					<span class="header-tag">{demoPlaylist[activeIndex].category}</span>
					<span class="app-brand">Orvia Player</span>
				</div>

				<!-- Artwork / Vinyl Display -->
				<div class="artwork-card" style="--track-accent: {demoPlaylist[activeIndex].accent}">
					<div class="vinyl-disc" class:spinning={isPlaying}>
						<div class="vinyl-groove">
							<div class="vinyl-center">
								<i class="fa-solid fa-music"></i>
							</div>
						</div>
					</div>
					<div class="artwork-glow" aria-hidden="true"></div>
				</div>

				<!-- Track Metadata -->
				<div class="track-info">
					<div class="text-group">
						<h3 class="track-title">{demoPlaylist[activeIndex].title}</h3>
						<p class="track-artist">{demoPlaylist[activeIndex].artist}</p>
					</div>
					<button 
						class="like-btn" 
						class:liked={isLiked} 
						on:click={toggleLike}
						aria-label={isLiked ? 'Unlike track demo' : 'Like track demo'}
					>
						<i class="fa-solid fa-heart"></i>
					</button>
				</div>

				<!-- Progress Bar -->
				<div class="progress-container">
					<div class="progress-bar">
						<div class="progress-fill" style="width: {progress}%;"></div>
					</div>
					<div class="progress-times">
						<span>1:34</span>
						<span>{demoPlaylist[activeIndex].duration}</span>
					</div>
				</div>

				<!-- Controls -->
				<div class="controls-row">
					<button class="ctrl-btn secondary" on:click={prevTrack} aria-label="Previous track demo">
						<i class="fa-solid fa-backward-step"></i>
					</button>
					<button class="ctrl-btn primary" on:click={togglePlay} aria-label={isPlaying ? 'Pause demo' : 'Play demo'}>
						<i class="fa-solid {isPlaying ? 'fa-pause' : 'fa-play'}"></i>
					</button>
					<button class="ctrl-btn secondary" on:click={nextTrack} aria-label="Next track demo">
						<i class="fa-solid fa-forward-step"></i>
					</button>
				</div>

				<!-- Playlist Queue -->
				<div class="queue-section">
					<span class="queue-heading">Up Next in Orvia</span>
					<ul class="queue-list">
						{#each demoPlaylist as track, i}
							<li>
								<button 
									class="queue-item" 
									class:active={i === activeIndex} 
									on:click={() => selectTrack(i)}
								>
									<span class="track-number">{i + 1}</span>
									<div class="track-meta">
										<span class="q-title">{track.title}</span>
										<span class="q-artist">{track.artist}</span>
									</div>
									{#if i === activeIndex && isPlaying}
										<span class="equalizer-bars" aria-hidden="true">
											<span class="bar"></span>
											<span class="bar"></span>
											<span class="bar"></span>
										</span>
									{:else}
										<span class="q-duration">{track.duration}</span>
									{/if}
								</button>
							</li>
						{/each}
					</ul>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.showcase-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		padding: 1rem 0;
	}

	.demo-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.4rem 0.9rem;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 20px;
		font-size: 0.75rem;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.85);
		margin-bottom: 1.2rem;
		text-align: center;
		backdrop-filter: blur(10px);
	}

	.demo-badge i {
		color: #ff8a00;
	}

	.player-mockup-wrapper {
		perspective: 1200px;
		width: 100%;
		display: flex;
		justify-content: center;
	}

	.phone-frame {
		position: relative;
		width: 100%;
		max-width: 320px;
		border-radius: 36px;
		border: 5px solid rgba(255, 255, 255, 0.18);
		background: #0d0a1a;
		box-shadow: 
			0 20px 50px rgba(0, 0, 0, 0.7),
			0 0 40px rgba(229, 46, 113, 0.15);
		padding: 12px;
		overflow: hidden;
		transition: transform 0.4s ease, box-shadow 0.4s ease;
	}

	.phone-frame:hover {
		transform: translateY(-4px);
		box-shadow: 
			0 25px 60px rgba(0, 0, 0, 0.8),
			0 0 50px rgba(229, 46, 113, 0.25);
	}

	.notch {
		width: 80px;
		height: 16px;
		background: #000;
		border-radius: 0 0 12px 12px;
		margin: -12px auto 8px auto;
	}

	.screen-content {
		display: flex;
		flex-direction: column;
		gap: 0.8rem;
	}

	.screen-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.6);
		padding: 0 4px;
	}

	.header-tag {
		color: #ff8a00;
	}

	.artwork-card {
		position: relative;
		width: 100%;
		aspect-ratio: 16 / 10;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.08), rgba(0, 0, 0, 0.4));
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		border: 1px solid rgba(255, 255, 255, 0.1);
	}

	.artwork-glow {
		position: absolute;
		inset: 0;
		background: radial-gradient(circle at center, var(--track-accent), transparent 70%);
		opacity: 0.35;
		filter: blur(20px);
		pointer-events: none;
	}

	.vinyl-disc {
		position: relative;
		z-index: 2;
		width: 110px;
		height: 110px;
		border-radius: 50%;
		background: #111;
		box-shadow: 0 4px 15px rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		border: 2px solid rgba(255, 255, 255, 0.2);
	}

	.vinyl-disc.spinning {
		animation: spin 6s linear infinite;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	@media (prefers-reduced-motion: reduce) {
		.vinyl-disc.spinning {
			animation: none;
		}
	}

	.vinyl-groove {
		width: 75px;
		height: 75px;
		border-radius: 50%;
		border: 1px dashed rgba(255, 255, 255, 0.2);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.vinyl-center {
		width: 38px;
		height: 38px;
		border-radius: 50%;
		background: linear-gradient(45deg, #ff8a00, #e52e71);
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-size: 0.8rem;
	}

	.track-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0 4px;
	}

	.text-group {
		min-width: 0;
		flex: 1;
	}

	.track-title {
		font-size: 0.95rem;
		font-weight: 700;
		color: #fff;
		margin: 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.track-artist {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.65);
		margin: 2px 0 0 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.like-btn {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.4);
		font-size: 1.1rem;
		cursor: pointer;
		padding: 6px;
		transition: color 0.2s, transform 0.2s;
	}

	.like-btn.liked {
		color: #e52e71;
		transform: scale(1.15);
	}

	.progress-container {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.progress-bar {
		width: 100%;
		height: 4px;
		background: rgba(255, 255, 255, 0.15);
		border-radius: 2px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #ff8a00, #e52e71);
		border-radius: 2px;
	}

	.progress-times {
		display: flex;
		justify-content: space-between;
		font-size: 0.65rem;
		color: rgba(255, 255, 255, 0.5);
	}

	.controls-row {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 1.2rem;
		padding: 4px 0;
	}

	.ctrl-btn {
		background: none;
		border: none;
		color: #fff;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.2s;
	}

	.ctrl-btn.secondary {
		font-size: 1.1rem;
		color: rgba(255, 255, 255, 0.7);
	}

	.ctrl-btn.primary {
		width: 44px;
		height: 44px;
		border-radius: 50%;
		background: linear-gradient(45deg, #ff8a00, #e52e71);
		font-size: 1.1rem;
		box-shadow: 0 4px 15px rgba(229, 46, 113, 0.4);
	}

	.ctrl-btn:hover {
		transform: scale(1.08);
	}

	.queue-section {
		background: rgba(255, 255, 255, 0.04);
		border-radius: 16px;
		padding: 8px 10px;
		border: 1px solid rgba(255, 255, 255, 0.08);
	}

	.queue-heading {
		font-size: 0.65rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.5);
		margin-bottom: 6px;
		display: block;
	}

	.queue-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.queue-item {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 6px;
		border-radius: 8px;
		background: transparent;
		border: none;
		color: #fff;
		text-align: left;
		cursor: pointer;
		transition: background 0.2s;
	}

	.queue-item:hover, .queue-item.active {
		background: rgba(255, 255, 255, 0.08);
	}

	.track-number {
		font-size: 0.7rem;
		color: rgba(255, 255, 255, 0.4);
		width: 12px;
	}

	.track-meta {
		flex: 1;
		min-width: 0;
	}

	.q-title {
		display: block;
		font-size: 0.75rem;
		font-weight: 600;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.q-artist {
		display: block;
		font-size: 0.65rem;
		color: rgba(255, 255, 255, 0.5);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.q-duration {
		font-size: 0.65rem;
		color: rgba(255, 255, 255, 0.4);
	}

	/* Equalizer Animation */
	.equalizer-bars {
		display: flex;
		align-items: flex-end;
		gap: 2px;
		height: 12px;
	}

	.bar {
		width: 2px;
		background: #e52e71;
		border-radius: 1px;
		animation: pulse-eq 0.8s ease-in-out infinite alternate;
	}

	.bar:nth-child(1) { height: 6px; animation-delay: 0.1s; }
	.bar:nth-child(2) { height: 12px; animation-delay: 0.3s; }
	.bar:nth-child(3) { height: 8px; animation-delay: 0.2s; }

	@keyframes pulse-eq {
		0% { height: 3px; }
		100% { height: 12px; }
	}

	@media (prefers-reduced-motion: reduce) {
		.bar {
			animation: none;
			height: 8px;
		}
	}
</style>
