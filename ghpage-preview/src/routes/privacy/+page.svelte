<script>
	import { base } from '$app/paths';
</script>

<svelte:head>
	<title>Privacy Policy — Orvia</title>
	<meta
		name="description"
		content="Orvia Privacy Policy. Complete transparency regarding website analytics, privacy controls, and data practices."
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
				<span class="text-[oklch(0.7_0.2_20)]">Legal</span> — Privacy Policy
			</div>
			<h1 class="font-display text-3xl sm:text-4xl text-[oklch(0.95_0.015_85)]">
				Privacy Policy
			</h1>
			<p class="mt-2 text-xs text-[oklch(0.6_0.02_265)]">
				Effective: October 2026
			</p>
		</div>

		<div class="space-y-8 text-sm text-[oklch(0.75_0.02_265)] leading-relaxed">
			<!-- Introduction -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					1. Overview &amp; Project Philosophy
				</h2>
				<p class="mb-3">
					This Privacy Policy explains how Orvia handles information associated with its website and software, including website analytics, available privacy controls, and ways to contact the project owner with privacy-related questions.
				</p>
				<p>
					Orvia is an open-source, non-commercial music player built for Android and Windows. The software is designed to prioritize listener privacy. Orvia does not sell, broker, monetize, or track your personal listening habits.
				</p>
			</section>

			<!-- Website Analytics -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					2. Website Usage &amp; Google Analytics 4
				</h2>
				<p class="mb-3">
					The Orvia website uses Google Analytics 4 (Measurement ID: <code>G-J0ME4TR9F8</code>) with IP anonymization enabled to measure aggregate website usage and download interactions.
				</p>
				<ul class="list-disc pl-5 space-y-2 text-xs text-[oklch(0.7_0.02_265)]">
					<li>
						<strong>Events Measured:</strong> Aggregated page views and download button interactions (Android APK and Windows ZIP clicks via the <code>orvia_download_click</code> event). No personal data or passwords are ever collected.
					</li>
					<li>
						<strong>IP Anonymization:</strong> IP anonymization is enforced so that full IP addresses are not stored or retained.
					</li>
					<li>
						<strong>Browser Privacy Signals:</strong> We honor browser <code>Do Not Track</code> (DNT) and <code>Global Privacy Control</code> (GPC) signals. When either signal is active, analytics tracking is automatically disabled.
					</li>
					<li>
						<strong>On-Site Privacy Toggle:</strong> You can toggle analytics tracking on or off anytime using the privacy control button located in the website footer. Your preference is saved locally in your browser storage.
					</li>
					<li>
						<strong>Google Privacy Policy:</strong> For details on how Google processes analytics data, visit <a href="https://policies.google.com/privacy" target="_blank" rel="noreferrer" class="text-brand hover:underline">Google's Privacy &amp; Terms</a>.
					</li>
				</ul>
			</section>

			<!-- Application & Data Handling -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					3. Application Data &amp; Local Storage
				</h2>
				<p class="mb-3">
					The Orvia application operates primarily as a local client on your device:
				</p>
				<ul class="list-disc pl-5 space-y-2 text-xs text-[oklch(0.7_0.02_265)]">
					<li>
						<strong>Local Library &amp; Playlists:</strong> Local media files, playlists, favorites, and settings remain stored locally on your device. Orvia does not upload your personal music library to any remote server.
					</li>
					<li>
						<strong>Network Streams:</strong> When playing online streams or fetching track metadata, network requests connect directly to public or supported content endpoints to retrieve the requested media.
					</li>
					<li>
						<strong>No Account Required:</strong> Orvia does not require an account, registration, or login to use the music player.
					</li>
				</ul>
			</section>

			<!-- Contact Information -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					4. Inquiries &amp; Contact Information
				</h2>
				<p class="mb-3">
					If you have questions regarding this Privacy Policy, your privacy preferences, or the project's data practices, please contact the maintainer:
				</p>
				<p class="text-xs font-mono text-[oklch(0.85_0.015_85)] space-y-1">
					<span>Email: <a href="mailto:ankitkumbhare301@gmail.com" class="text-brand hover:underline">ankitkumbhare301@gmail.com</a></span><br />
					<span>Project Repository: <a href="https://github.com/Ankitcodes30/Orvia" target="_blank" rel="noreferrer" class="text-brand hover:underline">github.com/Ankitcodes30/Orvia</a></span>
				</p>
			</section>
		</div>
	</main>

	<!-- Minimal Footer -->
	<footer class="border-t hairline py-8 text-center text-xs text-[oklch(0.6_0.02_265)]">
		<div class="mx-auto max-w-5xl px-5 flex flex-wrap items-center justify-between gap-4">
			<p>&copy; {new Date().getFullYear()} Orvia · Built by Ankit Kumbhare</p>
			<div class="flex items-center gap-4">
				<a href="{base}/terms" class="hover:text-white transition-colors">Terms</a>
				<a href="{base}/licenses" class="hover:text-white transition-colors">Licenses</a>
				<a href="{base}/help" class="hover:text-white transition-colors">Help</a>
			</div>
		</div>
	</footer>
</div>
