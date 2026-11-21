<script>
	import { base } from '$app/paths';

	const moods = [
		{ art: `${base}/assets/art-1.jpg`, mood: 'Nocturne', genre: 'Ambient · Electronic' },
		{ art: `${base}/assets/art-3.jpg`, mood: 'Night drive', genre: 'Synth · Downtempo' },
		{ art: `${base}/assets/art-2.jpg`, mood: 'Velvet', genre: 'Soul · R&B' }
	];
</script>

<section id="discover" class="grain relative overflow-hidden border-t hairline bg-[oklch(0.155_0.01_265)] py-28 md:py-40">
	<div class="mx-auto w-full max-w-7xl px-5 sm:px-6 md:px-10">
		<!-- Section Header -->
		<div class="mb-14 grid gap-6 md:mb-20 md:grid-cols-12 items-baseline">
			<div class="eyebrow md:col-span-3">
				<span class="text-[oklch(0.7_0.2_20)]">03</span> — Discovery
			</div>
			<div class="min-w-0 md:col-span-9">
				<h2 class="break-words font-display text-4xl leading-[1.08] sm:text-5xl lg:text-7xl">
					Find the sound of<br /><em class="text-brand pr-1">tonight.</em>
				</h2>
				<p class="mt-4 sm:mt-6 max-w-xl text-base sm:text-lg text-[oklch(0.7_0.02_265)]">
					Discovery should feel like flipping through records — by mood, colour and feeling.
				</p>
			</div>
		</div>

		<!-- Moods Grid -->
		<div class="grid gap-5 md:grid-cols-12">
			{#each moods as m, i}
				<div class={i === 0 ? 'md:col-span-12 lg:col-span-7' : 'md:col-span-6 lg:col-span-5'}>
					<figure class="group relative h-full overflow-hidden rounded-2xl {i === 0 ? 'min-h-[300px] sm:min-h-[380px] lg:min-h-[460px]' : 'min-h-[220px] sm:min-h-[260px] lg:min-h-[220px]'}">
						<img
							src={m.art}
							alt="Illustrative artwork for the {m.mood} mood"
							loading="lazy"
							class="absolute inset-0 h-full w-full object-cover transition-transform duration-[1.2s] group-hover:scale-105"
						/>
						<div class="absolute inset-0 bg-gradient-to-t from-[oklch(0.12_0.006_265/0.92)] via-[oklch(0.12_0.006_265/0.3)] to-transparent"></div>
						<figcaption class="absolute inset-x-0 bottom-0 grid grid-cols-[minmax(0,1fr)_auto] items-end gap-3 p-5 sm:p-6">
							<div class="min-w-0">
								<p class="eyebrow">{m.genre}</p>
								<p class="break-words font-display text-3xl sm:text-4xl lg:text-5xl text-[oklch(0.95_0.015_85)] leading-tight">{m.mood}</p>
							</div>
							<span class="font-mono text-xs text-[oklch(0.7_0.02_265)]">No. 0{i + 1}</span>
						</figcaption>
					</figure>
				</div>
			{/each}
		</div>

		<p class="mt-6 font-mono text-[10px] uppercase tracking-widest text-[oklch(0.7_0.02_265/0.7)]">
			Illustrative moods · not a live chart or catalogue
		</p>
	</div>
</section>
