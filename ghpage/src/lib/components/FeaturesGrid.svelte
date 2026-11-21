<script>
	const features = [
		{
			icon: 'fa-solid fa-ban',
			title: 'Uninterrupted Listening',
			tagline: 'Pure Sound',
			description: 'Zero third-party audio interruptions, sponsored breaks, or intrusive ads. Your queue plays straight through.',
			accent: '#e52e71'
		},
		{
			icon: 'fa-solid fa-hard-drive',
			title: 'Offline Library & Caching',
			tagline: 'Always Available',
			description: 'Save favorite tracks and import local audio files into your offline library, powered by an embedded database.',
			accent: '#ff8a00'
		},
		{
			icon: 'fa-solid fa-bolt-lightning',
			title: 'High-Performance Engine',
			tagline: 'Flutter & Rust FFI',
			description: 'Engineered with a responsive Flutter UI connected directly to a native Rust FFI layer and libmpv media core.',
			accent: '#38ef7d'
		},
		{
			icon: 'fa-solid fa-compass',
			title: 'Smart Curated Discoveries',
			tagline: 'Time & Season Aware',
			description: 'Explore time-of-day listening moods, regional Indian charts, and festive specials like Navratri Dandiya.',
			accent: '#ffd48e'
		}
	];
</script>

<div class="features-grid-container">
	<div class="grid-header">
		<h2>Designed for Pure Listening</h2>
		<p class="grid-subtitle">Engineered from the ground up for speed, transparency, and audio quality.</p>
	</div>

	<div class="cards-grid">
		{#each features as f, i}
			<article class="feature-card" style="--accent-color: {f.accent};">
				<div class="card-top">
					<div class="icon-bubble" aria-hidden="true">
						<i class={f.icon}></i>
					</div>
					<span class="card-number">0{i + 1}</span>
				</div>
				<span class="card-tagline">{f.tagline}</span>
				<h3 class="card-title">{f.title}</h3>
				<p class="card-desc">{f.description}</p>
				<div class="card-hairline" aria-hidden="true"></div>
			</article>
		{/each}
	</div>
</div>

<style>
	.features-grid-container {
		width: 100%;
		max-width: 900px;
		margin: 0 auto;
		padding: 0.5rem 0.5rem 1.5rem 0.5rem;
	}

	.grid-header {
		text-align: center;
		margin-bottom: 1.5rem;
	}

	.grid-header h2 {
		font-size: clamp(1.6rem, 4vw, 2.3rem);
		font-weight: 700;
		background: linear-gradient(45deg, #ff8a00, #e52e71);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		margin: 0 0 0.4rem 0;
	}

	.grid-subtitle {
		font-family: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, sans-serif;
		font-size: clamp(0.85rem, 2vw, 1.05rem);
		color: rgba(255, 237, 248, 0.85);
		margin: 0 auto;
		max-width: 600px;
		line-height: 1.4;
	}

	.cards-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1.2rem;
	}

	.feature-card {
		position: relative;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 20px;
		padding: 1.4rem;
		backdrop-filter: blur(16px);
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
		transition: transform 0.3s ease, border-color 0.3s ease, box-shadow 0.3s ease;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.feature-card:hover {
		transform: translateY(-4px);
		border-color: rgba(255, 255, 255, 0.25);
		box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
	}

	.card-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.8rem;
	}

	.icon-bubble {
		width: 44px;
		height: 44px;
		border-radius: 12px;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.15);
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--accent-color);
		font-size: 1.2rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
	}

	.card-number {
		font-family: 'Courier New', monospace;
		font-size: 0.8rem;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.35);
		letter-spacing: 1px;
	}

	.card-tagline {
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		color: var(--accent-color);
		margin-bottom: 0.2rem;
	}

	.card-title {
		font-size: 1.15rem;
		font-weight: 700;
		color: #ffffff;
		margin: 0 0 0.5rem 0;
		line-height: 1.3;
	}

	.card-desc {
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.72);
		line-height: 1.5;
		margin: 0;
		flex-grow: 1;
	}

	.card-hairline {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		height: 2px;
		background: linear-gradient(90deg, transparent, var(--accent-color), transparent);
		opacity: 0.4;
	}

	@media (max-width: 768px) {
		.cards-grid {
			grid-template-columns: 1fr;
			gap: 0.9rem;
		}

		.feature-card {
			padding: 1.1rem;
		}

		.card-title {
			font-size: 1.05rem;
		}

		.card-desc {
			font-size: 0.8rem;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.feature-card:hover {
			transform: none;
		}
	}
</style>
