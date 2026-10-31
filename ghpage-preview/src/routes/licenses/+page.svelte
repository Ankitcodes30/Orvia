<script>
	import { base } from '$app/paths';
</script>

<svelte:head>
	<title>Copyright &amp; Open-Source Licenses — Orvia</title>
	<meta
		name="description"
		content="Open-source licensing information, GPL-2.0 notice, and third-party software attributions for Orvia."
	/>
</svelte:head>

<div class="min-h-screen bg-[#0a0b0e] text-[oklch(0.95_0.015_85)] flex flex-col">
	<!-- Subpage Header -->
	<header class="border-b hairline bg-[oklch(0.12_0.006_265/0.88)] backdrop-blur-md sticky top-0 z-40">
		<div class="mx-auto flex h-16 w-full max-w-5xl items-center justify-between px-5 sm:px-6">
			<a href="{base}/" class="inline-flex items-center gap-2.5">
				<img
					src="{base}/assets/OrviaLogo_Master.png"
					alt="Orvia"
					width="32"
					height="32"
					class="h-8 w-8 rounded-[9px] object-cover shadow-glow"
				/>
				<span class="font-display text-xl leading-none">Orvia</span>
			</a>
			<a
				href="{base}/"
				class="inline-flex items-center gap-1.5 text-xs text-[oklch(0.7_0.02_265)] hover:text-white transition-colors"
			>
				&larr; Back to Home
			</a>
		</div>
	</header>

	<!-- Main Content Container -->
	<main class="flex-1 mx-auto w-full max-w-4xl px-5 sm:px-6 py-12 md:py-16">
		<div class="mb-8">
			<div class="eyebrow mb-2">
				<span class="text-[oklch(0.7_0.2_20)]">Attribution</span> — Open Source Licenses
			</div>
			<h1 class="font-display text-3xl sm:text-4xl text-[oklch(0.95_0.015_85)]">
				Copyright &amp; Licenses
			</h1>
			<p class="mt-2 text-xs text-[oklch(0.6_0.02_265)]">
				Orvia is free open-source software licensed under GPL-2.0
			</p>
		</div>

		<div class="space-y-8 text-sm text-[oklch(0.75_0.02_265)] leading-relaxed">
			<!-- Section 1: Orvia Application License -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<div class="flex items-center justify-between mb-3">
					<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)]">
						Orvia Music Player License
					</h2>
					<span class="rounded-full bg-emerald-500/15 border border-emerald-500/30 px-2.5 py-0.5 text-[10px] font-mono text-emerald-300">
						GNU GPL-2.0
					</span>
				</div>
				<p class="mb-3">
					Copyright &copy; 2024–2026 Ankit Kumbhare.
				</p>
				<p class="text-xs text-[oklch(0.7_0.02_265)] leading-relaxed mb-4">
					This program is free software; you can redistribute it and/or modify it under the terms of the <strong>GNU General Public License</strong> as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
				</p>
				<p class="text-xs text-[oklch(0.7_0.02_265)] leading-relaxed">
					This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
				</p>
			</section>

			<!-- Section 2: Branding & Content Disclaimer -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					Branding, Artwork &amp; Content Disclaimer
				</h2>
				<ul class="list-disc pl-5 space-y-2 text-xs text-[oklch(0.7_0.02_265)]">
					<li>
						<strong>Orvia Brand Assets:</strong> The Orvia name, logo design (<code>OrviaLogo_Master.png</code>), visual branding, and website design are copyright &copy; Ankit Kumbhare.
					</li>
					<li>
						<strong>Third-Party Media:</strong> Orvia is an audio playback client. Orvia does not claim ownership of music tracks, album artwork, artist names, or media files played by users. All third-party trademarks, artist names, and cover art remain the intellectual property of their respective owners.
					</li>
				</ul>
			</section>

			<!-- Section 3: Open-Source Attributions -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-4">
					Third-Party Open-Source Components
				</h2>
				<div class="grid gap-3 sm:grid-cols-2 text-xs">
					<div class="p-3.5 rounded-xl border border-[oklch(0.95_0.015_85/0.08)] bg-[oklch(0.12_0.006_265/0.6)]">
						<div class="flex items-center justify-between mb-1">
							<strong class="text-[oklch(0.9_0.015_85)]">Flutter &amp; Dart</strong>
							<span class="font-mono text-[10px] text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">BSD-3-Clause</span>
						</div>
						<p class="text-[11px] text-[oklch(0.65_0.02_265)]">UI toolkit for building cross-platform applications by Google.</p>
					</div>

					<div class="p-3.5 rounded-xl border border-[oklch(0.95_0.015_85/0.08)] bg-[oklch(0.12_0.006_265/0.6)]">
						<div class="flex items-center justify-between mb-1">
							<strong class="text-[oklch(0.9_0.015_85)]">SvelteKit</strong>
							<span class="font-mono text-[10px] text-blue-400 bg-blue-500/10 px-2 py-0.5 rounded">MIT License</span>
						</div>
						<p class="text-[11px] text-[oklch(0.65_0.02_265)]">Web framework for the Orvia web application and static website.</p>
					</div>

					<div class="p-3.5 rounded-xl border border-[oklch(0.95_0.015_85/0.08)] bg-[oklch(0.12_0.006_265/0.6)]">
						<div class="flex items-center justify-between mb-1">
							<strong class="text-[oklch(0.9_0.015_85)]">Tailwind CSS</strong>
							<span class="font-mono text-[10px] text-cyan-400 bg-cyan-500/10 px-2 py-0.5 rounded">MIT License</span>
						</div>
						<p class="text-[11px] text-[oklch(0.65_0.02_265)]">Utility-first styling system for interface design.</p>
					</div>

					<div class="p-3.5 rounded-xl border border-[oklch(0.95_0.015_85/0.08)] bg-[oklch(0.12_0.006_265/0.6)]">
						<div class="flex items-center justify-between mb-1">
							<strong class="text-[oklch(0.9_0.015_85)]">fflate</strong>
							<span class="font-mono text-[10px] text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded">MIT License</span>
						</div>
						<p class="text-[11px] text-[oklch(0.65_0.02_265)]">High-speed compression and decompression utility library.</p>
					</div>
				</div>
			</section>

			<!-- Section 4: Source Repository -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					Source Code Access
				</h2>
				<p class="mb-3">
					In accordance with the GNU General Public License v2.0, the complete source code for Orvia is publicly accessible:
				</p>
				<a
					href="https://github.com/Ankitcodes30/Orvia"
					target="_blank"
					rel="noreferrer"
					class="inline-flex items-center gap-2 rounded-full border border-[oklch(0.95_0.015_85/0.2)] px-4 py-2 text-xs font-mono text-[oklch(0.9_0.015_85)] hover:border-brand hover:text-brand transition-colors"
				>
					<svg class="h-4 w-4 fill-current shrink-0" viewBox="0 0 24 24" aria-hidden="true">
						<path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
					</svg>
					<span>View Orvia Source Code on GitHub &rarr;</span>
				</a>
			</section>
		</div>
	</main>

	<!-- Minimal Footer -->
	<footer class="border-t hairline py-8 text-center text-xs text-[oklch(0.6_0.02_265)]">
		<div class="mx-auto max-w-5xl px-5 flex flex-wrap items-center justify-between gap-4">
			<p>&copy; {new Date().getFullYear()} Orvia · Built by Ankit Kumbhare</p>
			<div class="flex items-center gap-4">
				<a href="{base}/privacy" class="hover:text-white transition-colors">Privacy</a>
				<a href="{base}/terms" class="hover:text-white transition-colors">Terms</a>
				<a href="{base}/help" class="hover:text-white transition-colors">Help</a>
			</div>
		</div>
	</footer>
</div>
