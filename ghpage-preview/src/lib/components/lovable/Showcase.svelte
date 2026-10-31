<script>
	import { base } from '$app/paths';

	const english = [
		{ t: 'Blinding Lights', a: 'The Weeknd', art: `${base}/assets/art-3.jpg` },
		{ t: 'Shape of You', a: 'Ed Sheeran', art: `${base}/assets/art-2.jpg` },
		{ t: 'Levitating', a: 'Dua Lipa', art: `${base}/assets/art-1.jpg` }
	];

	// Mobile carousel state
	let activeSlide = 1; // Default to center phone (Trending Now Playing)
	let touchStartX = 0;
	let touchStartY = 0;
	let isSwiping = false;

	function nextSlide() {
		if (activeSlide < 2) activeSlide++;
	}

	function prevSlide() {
		if (activeSlide > 0) activeSlide--;
	}

	function goToSlide(index) {
		activeSlide = index;
	}

	function handleTouchStart(e) {
		touchStartX = e.touches[0].clientX;
		touchStartY = e.touches[0].clientY;
		isSwiping = true;
	}

	function handleTouchEnd(e) {
		if (!isSwiping) return;
		isSwiping = false;
		const touchEndX = e.changedTouches[0].clientX;
		const touchEndY = e.changedTouches[0].clientY;
		const diffX = touchEndX - touchStartX;
		const diffY = touchEndY - touchStartY;

		// Only trigger horizontal slide if horizontal intent is stronger than vertical scroll
		if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 40) {
			if (diffX < 0) {
				nextSlide();
			} else {
				prevSlide();
			}
		}
	}
</script>

<section id="showcase" class="relative py-28 md:py-40 overflow-hidden">
	<div class="mx-auto w-full max-w-7xl px-5 sm:px-6 md:px-10">
		<!-- Section Header (Matches Desktop Screenshots) -->
		<div class="mb-14 grid gap-6 md:mb-20 md:grid-cols-12 items-baseline">
			<div class="eyebrow md:col-span-3">
				<span class="text-[oklch(0.7_0.2_20)]">01</span> — THE APP
			</div>
			<div class="min-w-0 md:col-span-9">
				<h2 class="break-words font-display text-4xl leading-[1.08] sm:text-5xl lg:text-7xl">
					Designed to <em class="text-brand pr-1">disappear</em><br />behind the music.
				</h2>
				<p class="mt-4 sm:mt-6 max-w-xl text-base sm:text-lg text-[oklch(0.7_0.02_265)]">
					Curved artwork, festive specials, top charts and a mini player that's always one tap away.
				</p>
			</div>
		</div>

		<!-- MOBILE & TABLET (< 1024px): Touch-Enabled Horizontal Sliding Carousel -->
		<div class="block lg:hidden w-full relative">
			<div
				class="overflow-hidden w-full touch-pan-y"
				on:touchstart={handleTouchStart}
				on:touchend={handleTouchEnd}
				role="region"
				aria-label="App screen mockups carousel"
			>
				<div
					class="flex transition-transform duration-500 ease-out will-change-transform"
					style="transform: translateX(-{activeSlide * 100}%);"
				>
					<!-- Slide 0: Explore Screen -->
					<div class="w-full shrink-0 flex flex-col items-center px-4">
						<div class="relative w-full max-w-[260px] rounded-[2.6rem] border-[6px] border-[oklch(0.12_0.006_265)] bg-[oklch(0.12_0.006_265)] shadow-deep ring-1 ring-[oklch(0.95_0.015_85/0.1)]">
							<div class="absolute left-1/2 top-2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-[oklch(0.12_0.006_265)]"></div>
							<div class="sheen relative aspect-[9/19.5] overflow-hidden rounded-[2.1rem] bg-[oklch(0.155_0.01_265)]">
								<img
									src="{base}/assets/app-explore.jpg"
									alt="Orvia Explore screen with festive special and recently played tracks"
									loading="lazy"
									class="h-full w-full object-cover object-top"
								/>
							</div>
						</div>
						<p class="mt-4 font-mono text-[11px] uppercase tracking-wider text-[oklch(0.7_0.02_265)]">
							Explore &amp; Specials
						</p>
					</div>

					<!-- Slide 1: Trending Now Playing Screen -->
					<div class="w-full shrink-0 flex flex-col items-center px-4">
						<div class="relative w-full max-w-[260px] rounded-[2.6rem] border-[6px] border-[oklch(0.12_0.006_265)] bg-[oklch(0.12_0.006_265)] shadow-deep ring-1 ring-[oklch(0.95_0.015_85/0.1)] shadow-glow">
							<div class="absolute left-1/2 top-2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-[oklch(0.12_0.006_265)]"></div>
							<div class="sheen relative aspect-[9/19.5] overflow-hidden rounded-[2.1rem] bg-[oklch(0.155_0.01_265)] flex flex-col">
								<!-- Blurred Background -->
								<div aria-hidden="true" class="absolute inset-0 z-0">
									<img
										src="{base}/assets/art-3.jpg"
										alt=""
										class="h-full w-full scale-125 object-cover opacity-40 blur-2xl"
									/>
									<div class="absolute inset-0 bg-gradient-to-b from-[oklch(0.155_0.01_265/0.5)] via-[oklch(0.155_0.01_265/0.8)] to-[oklch(0.155_0.01_265)]"></div>
								</div>

								<!-- Screen Contents -->
								<div aria-hidden="true" class="relative z-10 flex h-full flex-col px-4 pt-8 pb-3 justify-between">
									<div class="flex items-center justify-between">
										<p class="font-display text-2xl text-[oklch(0.95_0.015_85)]">Trending</p>
										<span class="rounded-full bg-[oklch(0.7_0.2_20/0.2)] px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-[oklch(0.7_0.2_20)]">Now</span>
									</div>

									<div class="my-auto py-1 flex justify-center">
										<img
											src="{base}/assets/art-3.jpg"
											alt=""
											class="w-32 aspect-square rounded-2xl object-cover shadow-deep"
										/>
									</div>

									<div>
										<div class="flex items-center justify-between">
											<div class="min-w-0 pr-2">
												<p class="text-sm font-semibold text-[oklch(0.95_0.015_85)] truncate">Blinding Lights</p>
												<p class="text-[11px] text-[oklch(0.7_0.02_265)] truncate">The Weeknd</p>
											</div>
											<svg class="h-4 w-4 fill-current text-[oklch(0.7_0.2_20)] shrink-0" viewBox="0 0 24 24">
												<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
											</svg>
										</div>

										<div class="mt-2 h-1 rounded-full bg-[oklch(0.95_0.015_85/0.15)]">
											<div class="h-full w-[58%] rounded-full bg-brand"></div>
										</div>

										<div class="mt-2.5 flex items-center justify-center gap-6">
											<svg class="h-4 w-4 text-[oklch(0.95_0.015_85)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
												<path stroke-linecap="round" stroke-linejoin="round" d="M19 20L9 12l10-8v16zM5 19V5" />
											</svg>
											<div class="grid h-10 w-10 place-items-center rounded-full btn-brand">
												<svg class="ml-0.5 h-4 w-4 fill-current" viewBox="0 0 24 24">
													<polygon points="5 3 19 12 5 21 5 3" />
												</svg>
											</div>
											<svg class="h-4 w-4 text-[oklch(0.95_0.015_85)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
												<path stroke-linecap="round" stroke-linejoin="round" d="M5 4l10 8-10 8V4zM19 5v14" />
											</svg>
										</div>
									</div>

									<ul class="my-1.5 space-y-1.5">
										{#each english.slice(1, 3) as s}
											<li class="flex items-center gap-2.5">
												<img src={s.art} alt="" class="h-7 w-7 rounded-lg object-cover shrink-0" />
												<div class="min-w-0 flex-1">
													<p class="truncate text-[11px] font-medium text-[oklch(0.95_0.015_85)]">{s.t}</p>
													<p class="text-[9px] text-[oklch(0.7_0.02_265)] truncate">{s.a}</p>
												</div>
												<svg class="h-3.5 w-3.5 text-[oklch(0.7_0.02_265)] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
													<path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
												</svg>
											</li>
										{/each}
									</ul>

									<div class="flex items-center justify-around rounded-xl bg-[oklch(0.12_0.006_265/0.85)] py-1.5 text-[oklch(0.7_0.02_265)]">
										<span class="flex items-center gap-1 rounded-full bg-[oklch(0.7_0.2_20/0.25)] px-2.5 py-0.5 text-[10px] text-[oklch(0.7_0.2_20)] font-medium">
											<svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
												<path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
											</svg>
											Home
										</span>
										<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
										</svg>
										<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
										</svg>
										<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
										</svg>
										<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
										</svg>
									</div>
								</div>
							</div>
						</div>
						<p class="mt-4 font-mono text-[11px] uppercase tracking-wider text-[oklch(0.7_0.2_20)]">
							Now Playing
						</p>
					</div>

					<!-- Slide 2: Browse Screen -->
					<div class="w-full shrink-0 flex flex-col items-center px-4">
						<div class="relative w-full max-w-[260px] rounded-[2.6rem] border-[6px] border-[oklch(0.12_0.006_265)] bg-[oklch(0.12_0.006_265)] shadow-deep ring-1 ring-[oklch(0.95_0.015_85/0.1)]">
							<div class="absolute left-1/2 top-2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-[oklch(0.12_0.006_265)]"></div>
							<div class="sheen relative aspect-[9/19.5] overflow-hidden rounded-[2.1rem] bg-[oklch(0.155_0.01_265)]">
								<img
									src="{base}/assets/app-browse.jpg"
									alt="Orvia Browse screen with top charts and categories"
									loading="lazy"
									class="h-full w-full object-cover object-top"
								/>
							</div>
						</div>
						<p class="mt-4 font-mono text-[11px] uppercase tracking-wider text-[oklch(0.7_0.02_265)]">
							Browse &amp; Categories
						</p>
					</div>
				</div>
			</div>

			<!-- Carousel Pagination Controls -->
			<div class="mt-6 flex items-center justify-center gap-3">
				<button
					type="button"
					on:click={prevSlide}
					disabled={activeSlide === 0}
					aria-label="Previous phone mockup"
					class="h-9 w-9 rounded-full border border-[oklch(0.95_0.015_85/0.15)] flex items-center justify-center text-[oklch(0.95_0.015_85)] transition-opacity disabled:opacity-30"
				>
					<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
					</svg>
				</button>

				<div class="flex items-center gap-2">
					{#each [0, 1, 2] as i}
						<button
							type="button"
							on:click={() => goToSlide(i)}
							aria-label="Go to phone slide {i + 1}"
							class="h-2 rounded-full transition-all duration-300 {activeSlide === i
								? 'w-7 bg-brand'
								: 'w-2 bg-[oklch(0.95_0.015_85/0.25)] hover:bg-[oklch(0.95_0.015_85/0.4)]'}"
						></button>
					{/each}
				</div>

				<button
					type="button"
					on:click={nextSlide}
					disabled={activeSlide === 2}
					aria-label="Next phone mockup"
					class="h-9 w-9 rounded-full border border-[oklch(0.95_0.015_85/0.15)] flex items-center justify-center text-[oklch(0.95_0.015_85)] transition-opacity disabled:opacity-30"
				>
					<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
					</svg>
				</button>
			</div>
		</div>

		<!-- DESKTOP (>= 1024px): 3-Phone Staggered Composition (Matches Screenshot Exactly) -->
		<div class="hidden lg:grid lg:grid-cols-3 lg:items-start lg:gap-8 justify-items-center">
			<!-- Phone 1 (Left - Explore Screen) -->
			<div class="w-full flex justify-center lg:mt-24">
				<div class="relative w-full max-w-[260px] rounded-[2.6rem] border-[6px] border-[oklch(0.12_0.006_265)] bg-[oklch(0.12_0.006_265)] shadow-deep ring-1 ring-[oklch(0.95_0.015_85/0.1)] transition-transform duration-700 hover:-translate-y-2">
					<div class="absolute left-1/2 top-2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-[oklch(0.12_0.006_265)]"></div>
					<div class="sheen relative aspect-[9/19.5] overflow-hidden rounded-[2.1rem] bg-[oklch(0.155_0.01_265)]">
						<img
							src="{base}/assets/app-explore.jpg"
							alt="Orvia Explore screen with a Navratri festive special and recently played Hindi songs"
							loading="lazy"
							class="h-full w-full object-cover object-top"
						/>
					</div>
				</div>
			</div>

			<!-- Phone 2 (Center - Now Playing Trending) -->
			<div class="w-full flex justify-center lg:z-10">
				<div class="relative w-full max-w-[260px] rounded-[2.6rem] border-[6px] border-[oklch(0.12_0.006_265)] bg-[oklch(0.12_0.006_265)] shadow-deep ring-1 ring-[oklch(0.95_0.015_85/0.1)] transition-transform duration-700 hover:-translate-y-2 lg:scale-105 shadow-glow">
					<div class="absolute left-1/2 top-2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-[oklch(0.12_0.006_265)]"></div>
					<div class="sheen relative aspect-[9/19.5] overflow-hidden rounded-[2.1rem] bg-[oklch(0.155_0.01_265)] flex flex-col">
						<!-- Ambient Blurred Backdrop -->
						<div aria-hidden="true" class="absolute inset-0 z-0">
							<img
								src="{base}/assets/art-3.jpg"
								alt=""
								class="h-full w-full scale-125 object-cover opacity-40 blur-2xl"
							/>
							<div class="absolute inset-0 bg-gradient-to-b from-[oklch(0.155_0.01_265/0.5)] via-[oklch(0.155_0.01_265/0.8)] to-[oklch(0.155_0.01_265)]"></div>
						</div>

						<!-- Screen Content -->
						<div aria-hidden="true" class="relative z-10 flex h-full flex-col px-4 pt-8 pb-3 justify-between">
							<!-- Header -->
							<div class="flex items-center justify-between">
								<p class="font-display text-2xl text-[oklch(0.95_0.015_85)]">Trending</p>
								<span class="rounded-full bg-[oklch(0.7_0.2_20/0.2)] px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-[oklch(0.7_0.2_20)]">Now</span>
							</div>

							<!-- Album Art -->
							<div class="my-auto py-1 flex justify-center">
								<img
									src="{base}/assets/art-3.jpg"
									alt=""
									class="w-32 aspect-square rounded-2xl object-cover shadow-deep"
								/>
							</div>

							<!-- Track Info -->
							<div>
								<div class="flex items-center justify-between">
									<div class="min-w-0 pr-2">
										<p class="text-sm font-semibold text-[oklch(0.95_0.015_85)] truncate">Blinding Lights</p>
										<p class="text-[11px] text-[oklch(0.7_0.02_265)] truncate">The Weeknd</p>
									</div>
									<svg class="h-4 w-4 fill-current text-[oklch(0.7_0.2_20)] shrink-0" viewBox="0 0 24 24">
										<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
									</svg>
								</div>

								<!-- Progress Bar -->
								<div class="mt-2 h-1 rounded-full bg-[oklch(0.95_0.015_85/0.15)]">
									<div class="h-full w-[58%] rounded-full bg-brand"></div>
								</div>

								<!-- Controls -->
								<div class="mt-2.5 flex items-center justify-center gap-6">
									<svg class="h-4 w-4 text-[oklch(0.95_0.015_85)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<path stroke-linecap="round" stroke-linejoin="round" d="M19 20L9 12l10-8v16zM5 19V5" />
									</svg>
									<div class="grid h-10 w-10 place-items-center rounded-full btn-brand">
										<svg class="ml-0.5 h-4 w-4 fill-current" viewBox="0 0 24 24">
											<polygon points="5 3 19 12 5 21 5 3" />
										</svg>
									</div>
									<svg class="h-4 w-4 text-[oklch(0.95_0.015_85)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<path stroke-linecap="round" stroke-linejoin="round" d="M5 4l10 8-10 8V4zM19 5v14" />
									</svg>
								</div>
							</div>

							<!-- Up Next List -->
							<ul class="my-1.5 space-y-1.5">
								{#each english.slice(1, 3) as s}
									<li class="flex items-center gap-2.5">
										<img src={s.art} alt="" class="h-7 w-7 rounded-lg object-cover shrink-0" />
										<div class="min-w-0 flex-1">
											<p class="truncate text-[11px] font-medium text-[oklch(0.95_0.015_85)]">{s.t}</p>
											<p class="text-[9px] text-[oklch(0.7_0.02_265)] truncate">{s.a}</p>
										</div>
										<svg class="h-3.5 w-3.5 text-[oklch(0.7_0.02_265)] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
										</svg>
									</li>
								{/each}
							</ul>

							<!-- Bottom Tab Bar -->
							<div class="flex items-center justify-around rounded-xl bg-[oklch(0.12_0.006_265/0.85)] py-1.5 text-[oklch(0.7_0.02_265)]">
								<span class="flex items-center gap-1 rounded-full bg-[oklch(0.7_0.2_20/0.25)] px-2.5 py-0.5 text-[10px] text-[oklch(0.7_0.2_20)] font-medium">
									<svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
									</svg>
									Home
								</span>
								<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
									<path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
								</svg>
								<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
									<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
								</svg>
								<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
									<path stroke-linecap="round" stroke-linejoin="round" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
								</svg>
								<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
									<path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
								</svg>
							</div>
						</div>
					</div>
				</div>
			</div>

			<!-- Phone 3 (Right - Browse Screen) -->
			<div class="w-full flex justify-center lg:mt-36">
				<div class="relative w-full max-w-[260px] rounded-[2.6rem] border-[6px] border-[oklch(0.12_0.006_265)] bg-[oklch(0.12_0.006_265)] shadow-deep ring-1 ring-[oklch(0.95_0.015_85/0.1)] transition-transform duration-700 hover:-translate-y-2">
					<div class="absolute left-1/2 top-2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-[oklch(0.12_0.006_265)]"></div>
					<div class="sheen relative aspect-[9/19.5] overflow-hidden rounded-[2.1rem] bg-[oklch(0.155_0.01_265)]">
						<img
							src="{base}/assets/app-browse.jpg"
							alt="Orvia Browse screen with categories, top charts and editorial picks"
							loading="lazy"
							class="h-full w-full object-cover object-top"
						/>
					</div>
				</div>
			</div>
		</div>

		<!-- Centered Bottom Note (Matches Desktop Screenshot exactly) -->
		<div class="mt-16 flex items-center justify-center gap-3 text-center font-mono text-[10px] uppercase tracking-widest text-[oklch(0.7_0.02_265/0.7)]">
			<span aria-hidden="true" class="inline-flex h-3 items-end gap-[3px] shrink-0">
				{#each [0, 1, 2] as i}
					<span
						class="eq-bar block h-full w-[3px] rounded-full bg-[oklch(0.7_0.2_20)]"
						style="animation-delay: {(i * 137) % 900}ms; animation-duration: {0.8 + ((i * 53) % 7) / 10}s;"
					></span>
				{/each}
			</span>
			<span class="min-w-0">ORVIA APP SCREENS</span>
		</div>
	</div>
</section>
