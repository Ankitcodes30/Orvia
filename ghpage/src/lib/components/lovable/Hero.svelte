<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';

	let heroEl;
	let playing = true;
	let progress = 0.34;

	// Typewriter state
	const L1 = 'Your music.';
	const L2a = 'Your';
	const L2b = ' atmosphere.';
	const TOTAL = L1.length + L2a.length + L2b.length;

	let n = TOTAL;
	let dir = -1;
	let reducedMotion = false;

	function fmt(p) {
		const s = Math.round(p * 222);
		return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
	}

	function togglePlay() {
		playing = !playing;
	}

	onMount(() => {
		reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

		if (!reducedMotion) {
			let raf = 0;
			const onMove = (e) => {
				cancelAnimationFrame(raf);
				raf = requestAnimationFrame(() => {
					if (heroEl) {
						heroEl.style.setProperty('--mx', String(e.clientX / window.innerWidth - 0.5));
						heroEl.style.setProperty('--my', String(e.clientY / window.innerHeight - 0.5));
					}
				});
			};
			const onScroll = () => {
				if (heroEl) {
					heroEl.style.setProperty('--sy', String(Math.min(window.scrollY, 900)));
				}
			};

			window.addEventListener('pointermove', onMove);
			window.addEventListener('scroll', onScroll, { passive: true });

			return () => {
				window.removeEventListener('pointermove', onMove);
				window.removeEventListener('scroll', onScroll);
				cancelAnimationFrame(raf);
			};
		}
	});

	// Progress loop for demo player
	onMount(() => {
		const id = setInterval(() => {
			if (playing) {
				progress = progress >= 1 ? 0 : progress + 0.004;
			}
		}, 120);

		return () => clearInterval(id);
	});

	// Typewriter loop
	onMount(() => {
		if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
			n = TOTAL;
			return;
		}

		let timer;
		const step = () => {
			let delay = dir === 1 ? 85 + Math.random() * 60 : 35;
			if (dir === 1 && n === TOTAL) delay = 2600;
			if (dir === -1 && n === 0) delay = 500;

			timer = setTimeout(() => {
				if (dir === 1 && n >= TOTAL) dir = -1;
				else if (dir === -1 && n <= 0) dir = 1;
				else n += dir;
				step();
			}, delay);
		};

		step();
		return () => clearTimeout(timer);
	});

	$: a = L1.slice(0, n);
	$: b = L2a.slice(0, Math.max(0, n - L1.length));
	$: c = L2b.slice(0, Math.max(0, n - L1.length - L2a.length));
</script>

<section
	id="top"
	bind:this={heroEl}
	class="ambient grain relative flex min-h-[100svh] items-center overflow-hidden pt-28 pb-20 md:py-36"
>
	<div class="mx-auto w-full max-w-7xl px-5 sm:px-6 md:px-10">
		<div class="grid items-center gap-12 lg:grid-cols-12 lg:gap-16">
			<!-- Left/Top: Copy & CTAs -->
			<div
				class="flex flex-col items-center text-center lg:items-start lg:text-left lg:col-span-6 min-w-0"
				data-parallax
				style="transform: translateY(calc(var(--sy, 0) * 0.15px))"
			>
				<div class="eyebrow mb-6 sm:mb-8 inline-flex items-center gap-3">
					<span
						aria-hidden="true"
						class="inline-flex h-3 items-end gap-[3px]"
						style="--eq-state: {playing ? 'running' : 'paused'};"
					>
						{#each [0, 1, 2, 3] as i}
							<span
								class="eq-bar block h-full w-[3px] rounded-full bg-[oklch(0.7_0.2_20)]"
								style="animation-delay: {(i * 137) % 900}ms; animation-duration: {0.8 + ((i * 53) % 7) / 10}s;"
							></span>
						{/each}
					</span>
					Ad-free music player
				</div>

				<!-- Typewriter Headline with reserved layout height -->
				<div class="relative w-full min-h-[4.5rem] sm:min-h-[6.5rem] md:min-h-[8rem] lg:min-h-[10.5rem] xl:min-h-[11.5rem] flex items-center justify-center lg:justify-start">
					<h1
						class="font-display text-3xl sm:text-5xl md:text-6xl lg:text-[4.2rem] xl:text-[5rem] leading-[1.08] break-words"
						aria-label="Your music. Your atmosphere."
					>
						<span aria-hidden="true" class="invisible block">
							Your music.<br /><em>Your</em> atmosphere.
						</span>
						<span aria-hidden="true" class="absolute inset-0 flex flex-col justify-center lg:justify-start">
							<span>
								{a || '\u200b'}
								{#if n <= L1.length}
									<span class="caret ml-1 inline-block h-[0.8em] w-[3px] translate-y-[0.08em] bg-brand"></span>
								{/if}
							</span>
							<span>
								<em class="text-brand pr-1">{b}</em>
								{c}
								{#if n > L1.length}
									<span class="caret ml-1 inline-block h-[0.8em] w-[3px] translate-y-[0.08em] bg-brand"></span>
								{/if}
							</span>
						</span>
					</h1>
				</div>

				<p class="mt-6 sm:mt-8 max-w-lg text-base sm:text-lg text-[oklch(0.7_0.02_265)] md:text-xl leading-relaxed">
					A music experience designed around the way you listen.
				</p>

				<div class="mt-8 sm:mt-10 flex flex-wrap items-center justify-center lg:justify-start gap-3 sm:gap-4 w-full">
					<a
						href="#showcase"
						class="group inline-flex items-center gap-3 rounded-full btn-brand px-6 sm:px-7 py-3.5 sm:py-4 text-sm font-medium transition-transform hover:-translate-y-0.5"
					>
						Explore Orvia
						<svg
							class="h-4 w-4 transition-transform group-hover:translate-y-0.5"
							fill="none"
							viewBox="0 0 24 24"
							stroke="currentColor"
							stroke-width="2"
						>
							<path stroke-linecap="round" stroke-linejoin="round" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
						</svg>
					</a>
					<a
						href="#download"
						class="inline-flex items-center rounded-full border border-[oklch(0.95_0.015_85/0.2)] px-6 sm:px-7 py-3.5 sm:py-4 text-sm text-[oklch(0.95_0.015_85)] transition-colors hover:border-[oklch(0.7_0.2_20)] hover:text-[oklch(0.7_0.2_20)]"
					>
						Get the app
					</a>
				</div>
			</div>

			<!-- Right/Bottom: Illustrative interactive player -->
			<div class="relative mx-auto w-full max-w-[384px] lg:col-span-6 flex justify-center items-center">
				<!-- Floating Art 2 (Left) - Hidden on extra small mobile -->
				<img
					src="{base}/assets/art-2.jpg"
					alt=""
					aria-hidden="true"
					width="816"
					height="816"
					data-parallax
					class="float-slow absolute -left-8 top-10 hidden sm:block w-36 lg:w-44 rounded-md opacity-70 shadow-deep pointer-events-none z-0"
					style="--r: -8deg; translate: calc(var(--mx, 0) * -30px) calc(var(--my, 0) * -30px);"
				/>

				<!-- Floating Art 4 (Right) - Hidden on extra small mobile -->
				<img
					src="{base}/assets/art-4.jpg"
					alt=""
					aria-hidden="true"
					width="816"
					height="816"
					data-parallax
					class="float-slow absolute -right-6 bottom-4 hidden sm:block w-32 lg:w-40 rounded-md opacity-80 shadow-deep pointer-events-none z-0"
					style="--r: 7deg; animation-delay: -3s; translate: calc(var(--mx, 0) * 40px) calc(var(--my, 0) * 40px);"
				/>

				<!-- Center Demo Player Card -->
				<div
					data-parallax
					class="relative z-10 w-full rounded-[1.75rem] border hairline bg-[oklch(0.17_0.008_265/0.92)] p-5 sm:p-6 shadow-deep shadow-glow backdrop-blur"
					style="translate: calc(var(--mx, 0) * 12px) calc(var(--my, 0) * 12px);"
				>
					<div class="mb-4 grid grid-cols-[minmax(0,1fr)_auto] items-center gap-2">
						<span class="eyebrow min-w-0">Now playing</span>
						<span
							class="shrink-0 rounded-full border border-[oklch(0.95_0.015_85/0.15)] px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest text-[oklch(0.7_0.02_265)]"
						>
							Demo · no audio
						</span>
					</div>

					<img
						src="{base}/assets/art-1.jpg"
						alt="Illustrative album artwork: a blue eclipse over a misty horizon"
						width="816"
						height="816"
						class="aspect-square w-full rounded-xl object-cover shadow-sm"
					/>

					<div class="mt-5 flex items-end justify-between gap-4">
						<div class="min-w-0">
							<p class="truncate font-display text-2xl sm:text-3xl leading-tight">Low Horizon</p>
							<p class="truncate text-xs sm:text-sm text-[oklch(0.7_0.02_265)]">Sample Artist · Illustrative</p>
						</div>
						<!-- Equalizer -->
						<span
							aria-hidden="true"
							class="inline-flex h-4 items-end gap-[3px] shrink-0"
							style="--eq-state: {playing ? 'running' : 'paused'};"
						>
							{#each [0, 1, 2, 3, 4] as i}
								<span
									class="eq-bar block h-full w-[3px] rounded-full bg-[oklch(0.7_0.2_20)]"
									style="animation-delay: {(i * 137) % 900}ms; animation-duration: {0.8 + ((i * 53) % 7) / 10}s;"
								></span>
							{/each}
						</span>
					</div>

					<!-- Waveform -->
					<div aria-hidden="true" class="mt-4 flex h-8 sm:h-10 items-center gap-[2px]">
						{#each Array(48) as _, i}
							{@const h = 20 + Math.abs(Math.sin(i * 0.7) * 55 + Math.cos(i * 0.31) * 25)}
							<span
								class="block w-full rounded-full {i / 48 < progress
									? 'bg-[oklch(0.7_0.2_20)]'
									: 'bg-[oklch(0.95_0.015_85/0.15)]'}"
								style="height: {Math.min(h, 100)}%;"
							></span>
						{/each}
					</div>

					<div class="mt-2 flex justify-between font-mono text-[11px] text-[oklch(0.7_0.02_265)]">
						<span>{fmt(progress)}</span>
						<span>3:42</span>
					</div>

					<!-- Controls -->
					<div class="mt-4 flex items-center justify-between text-[oklch(0.7_0.02_265)] px-1">
						<!-- Shuffle -->
						<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M16 3h5v5M4 20L21 3M21 16v5h-5M15 15l6 6M4 4l5 5" />
						</svg>

						<!-- SkipBack -->
						<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M19 20L9 12l10-8v16zM5 19V5" />
						</svg>

						<!-- Play/Pause Toggle Button -->
						<button
							type="button"
							on:click={togglePlay}
							aria-label={playing ? 'Pause demo animation' : 'Play demo animation'}
							aria-pressed={playing}
							class="grid h-12 w-12 sm:h-14 sm:w-14 place-items-center rounded-full btn-brand transition-transform hover:scale-105"
						>
							{#if playing}
								<svg class="h-5 w-5 fill-current" viewBox="0 0 24 24">
									<rect x="6" y="4" width="4" height="16" rx="1" />
									<rect x="14" y="4" width="4" height="16" rx="1" />
								</svg>
							{:else}
								<svg class="ml-0.5 h-5 w-5 fill-current" viewBox="0 0 24 24">
									<polygon points="5 3 19 12 5 21 5 3" />
								</svg>
							{/if}
						</button>

						<!-- SkipForward -->
						<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M5 4l10 8-10 8V4zM19 5v14" />
						</svg>

						<!-- Repeat -->
						<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M17 1l4 4-4 4M3 11V9a4 4 0 014-4h14M7 23l-4-4 4-4M21 13v2a4 4 0 01-4 4H3" />
						</svg>
					</div>
				</div>

				<p class="absolute -bottom-8 left-0 right-0 text-center font-mono text-[10px] uppercase tracking-widest text-[oklch(0.7_0.02_265/0.7)]">
					Website preview — not the actual app
				</p>
			</div>
		</div>
	</div>

	<div class="pointer-events-none absolute inset-x-0 bottom-0 h-32 bg-gradient-to-b from-transparent to-[#0a0b0e]"></div>
</section>
