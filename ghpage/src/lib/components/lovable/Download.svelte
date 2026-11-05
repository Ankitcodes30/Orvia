<script>
	import { trackDownloadClick } from '$lib/analytics.js';
</script>

<section id="download" class="ambient relative border-t hairline py-28 md:py-40">
	<div class="mx-auto w-full max-w-7xl px-5 sm:px-6 md:px-10">
		<!-- Section Header -->
		<div class="mb-14 grid gap-6 md:mb-20 md:grid-cols-12 items-baseline">
			<div class="eyebrow md:col-span-3">
				<span class="text-[oklch(0.7_0.2_20)]">04</span> — Download
			</div>
			<div class="min-w-0 md:col-span-9">
				<h2 class="break-words font-display text-4xl leading-[1.08] sm:text-5xl lg:text-7xl">
					Take Orvia<br /><em class="text-brand pr-1">with you.</em>
				</h2>
				<p class="mt-4 sm:mt-6 max-w-xl text-base sm:text-lg text-[oklch(0.7_0.02_265)]">
					Your music, your way. Download Orvia for Android or Windows and make every moment sound better.
				</p>
			</div>
		</div>

		<!-- Platform Download Cards -->
		<div class="grid gap-6 md:gap-8 md:grid-cols-2">
			<!-- Android Card -->
			<article class="group relative flex h-full flex-col justify-between gap-8 sm:gap-12 overflow-hidden rounded-3xl border hairline bg-[oklch(0.17_0.008_265/0.7)] p-6 sm:p-8 md:p-10 transition-colors hover:border-[oklch(0.7_0.2_20/0.4)]">
				<div class="flex items-start justify-between">
					<!-- Smartphone Icon -->
					<div class="grid h-12 w-12 place-items-center rounded-2xl bg-[oklch(0.7_0.2_20/0.15)] text-[oklch(0.7_0.2_20)]">
						<svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<rect x="5" y="2" width="14" height="20" rx="2" />
							<line x1="12" y1="18" x2="12.01" y2="18" />
						</svg>
					</div>
				</div>

				<div>
					<h3 class="break-words font-display text-4xl sm:text-5xl lg:text-6xl leading-tight">Android</h3>
					<p class="mt-2 text-sm sm:text-base text-[oklch(0.7_0.02_265)] leading-relaxed">
						For phones and tablets.
					</p>

					<a
						id="download-android-btn"
						href="https://ankitcodes30.github.io/Orvia/downloads/app-release.apk"
						on:click={() => trackDownloadClick('android')}
						class="mt-6 sm:mt-8 w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-full btn-brand px-6 py-3.5 text-sm font-medium transition-transform hover:-translate-y-0.5"
					>
						Download for Android
						<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M7 17L17 7m0 0H7m10 0v10" />
						</svg>
					</a>
				</div>
			</article>

			<!-- Windows Card -->
			<article class="group relative flex h-full flex-col justify-between gap-8 sm:gap-12 overflow-hidden rounded-3xl border hairline bg-[oklch(0.17_0.008_265/0.7)] p-6 sm:p-8 md:p-10 transition-colors hover:border-[oklch(0.7_0.2_20/0.4)]">
				<div class="flex items-start justify-between">
					<!-- Monitor Icon -->
					<div class="grid h-12 w-12 place-items-center rounded-2xl bg-[oklch(0.7_0.2_20/0.15)] text-[oklch(0.7_0.2_20)]">
						<svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<rect x="2" y="3" width="20" height="14" rx="2" />
							<line x1="8" y1="21" x2="16" y2="21" />
							<line x1="12" y1="17" x2="12" y2="21" />
						</svg>
					</div>
				</div>

				<div>
					<h3 class="break-words font-display text-4xl sm:text-5xl lg:text-6xl leading-tight">Windows</h3>
					<p class="mt-2 text-sm sm:text-base text-[oklch(0.7_0.02_265)] leading-relaxed">
						For 64-bit Windows desktops and laptops.
					</p>

					<a
						id="download-windows-btn"
						href="https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip"
						on:click={() => trackDownloadClick('windows')}
						class="mt-6 sm:mt-8 w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-full btn-brand px-6 py-3.5 text-sm font-medium transition-transform hover:-translate-y-0.5"
					>
						Download for Windows
						<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M7 17L17 7m0 0H7m10 0v10" />
						</svg>
					</a>
				</div>
			</article>
		</div>
		<p id="download-availability" class="mt-6 text-sm text-[oklch(0.7_0.02_265)]" role="status">
			Verified production release v3.0.7+7 is available. Direct verified downloads with SHA-256 integrity verification.
		</p>
	</div>
</section>
