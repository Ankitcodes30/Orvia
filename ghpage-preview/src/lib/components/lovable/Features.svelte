<script>
	const pillars = [
		{
			title: 'Ad-free streaming',
			body: 'No interruptions, no sponsored breaks. Every song plays straight through, the way it was meant to.',
			index: '01'
		},
		{
			title: 'Offline caching',
			body: 'Keep the music you love saved on your device, so it keeps playing when the signal drops.',
			index: '02'
		},
		{
			title: 'Fluid performance',
			body: 'Instant taps, smooth scrolling and quick starts — built to feel light on phone and desktop.',
			index: '03'
		}
	];
</script>

<section id="features" class="relative overflow-hidden border-t hairline py-28 md:py-40">
	<div
		aria-hidden="true"
		class="pointer-events-none absolute left-1/2 top-1/3 h-[420px] w-[min(900px,90vw)] -translate-x-1/2 rounded-full bg-brand opacity-[0.10] blur-[120px]"
	></div>

	<div class="relative mx-auto w-full max-w-7xl px-5 sm:px-6 md:px-10">
		<!-- Section Header -->
		<div class="mb-14 grid gap-6 md:mb-20 md:grid-cols-12 items-baseline">
			<div class="eyebrow md:col-span-3">
				<span class="text-[oklch(0.7_0.2_20)]">02</span> — Pillars
			</div>
			<div class="min-w-0 md:col-span-9">
				<h2 class="break-words font-display text-4xl leading-[1.08] sm:text-5xl lg:text-7xl">
					No ads. No noise.<br /><em class="text-brand pr-1">Just listening.</em>
				</h2>
				<p class="mt-4 sm:mt-6 max-w-xl text-base sm:text-lg text-[oklch(0.7_0.02_265)]">
					Three promises Orvia is built around.
				</p>
			</div>
		</div>

		<!-- 3 Pillars Grid -->
		<div class="grid gap-6 md:gap-8 lg:grid-cols-3">
			{#each pillars as p}
				<article class="group relative h-full flex flex-col justify-between overflow-hidden rounded-3xl border hairline bg-[oklch(0.17_0.008_265/0.6)] p-6 sm:p-8 md:p-10 backdrop-blur transition-colors hover:border-[oklch(0.7_0.2_20/0.4)]">
					<div>
						<div class="flex items-center justify-between">
							<div class="grid h-12 w-12 place-items-center rounded-2xl bg-brand text-[#0a0b0e]">
								{#if p.index === '01'}
									<!-- Ban Icon -->
									<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10" />
										<line x1="4.93" y1="4.93" x2="19.07" y2="19.07" />
									</svg>
								{:else if p.index === '02'}
									<!-- HardDriveDownload Icon -->
									<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<rect x="2" y="14" width="20" height="8" rx="2" />
										<line x1="6" y1="18" x2="6.01" y2="18" />
										<line x1="10" y1="18" x2="10.01" y2="18" />
										<path d="M12 2v8m-4-4l4 4 4-4" />
									</svg>
								{:else}
									<!-- Gauge Icon -->
									<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
										<path d="M12 14l4-4" />
										<path d="M3.34 19a10 10 0 1 1 17.32 0" />
									</svg>
								{/if}
							</div>
							<span class="eyebrow">{p.index}</span>
						</div>

						<h3 class="mt-8 sm:mt-10 break-words font-display text-3xl sm:text-4xl xl:text-5xl leading-tight">
							{p.title}
						</h3>
					</div>

					<p class="mt-4 sm:mt-6 text-sm sm:text-base text-[oklch(0.7_0.02_265)] leading-relaxed">
						{p.body}
					</p>
				</article>
			{/each}
		</div>
	</div>
</section>
