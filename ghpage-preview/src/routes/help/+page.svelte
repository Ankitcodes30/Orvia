<script>
	import { base } from '$app/paths';
	import { trackDownloadClick } from '$lib/analytics.js';

	// Accordion state
	let openIndex = 0; // Default first item open

	function toggleItem(index) {
		openIndex = openIndex === index ? -1 : index;
	}

	const faqs = [
		{
			q: 'How do I install Orvia on Android?',
			a: 'Download the APK directly using the button below. When prompted by your browser, tap "Open" or "Install". If your phone displays "Install unknown apps", tap Settings and toggle allow for your browser. Orvia is an officially signed, secure package (Package ID: ls.orvia.musicplayer, v3.0.7).',
			action: {
				label: 'Download Android APK (59 MB)',
				href: 'https://ankitcodes30.github.io/Orvia/downloads/app-release.apk',
				platform: 'android'
			}
		},
		{
			q: 'How do I run Orvia on Windows?',
			a: 'Download the portable Windows ZIP package. Extract the archive into any folder of your choice and double-click orvia.exe to launch. If Windows SmartScreen prompts "Windows protected your PC", click "More info" and select "Run anyway" (standard for independent open-source software). No installer required.',
			action: {
				label: 'Download Windows ZIP (34 MB)',
				href: 'https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip',
				platform: 'windows'
			}
		},
		{
			q: 'How do application updates work?',
			a: 'Orvia features a built-in update checker. When a new release is published, the app notifies you directly with the changelog. You can also re-download the latest verified version anytime directly from this website.'
		},
		{
			q: 'How can I share feedback about Orvia?',
			a: 'You can share feedback or report an issue through the support contact provided on the Orvia website. Please include relevant details about your device, platform and the issue you encountered so it can be investigated.'
		},
		{
			q: 'Which audio formats and features are supported?',
			a: 'Orvia supports standard audio formats including MP3, FLAC, WAV, AAC, M4A, and OGG. Features include background media playback, lock screen controls, desktop volume shortcuts, offline caching, and playlist sharing.'
		},
		{
			q: 'How do I report a bug or request a feature?',
			a: 'You can reach out directly via email to ankitkumbhare301@gmail.com or open an issue on our GitHub repository at github.com/Ankitcodes30/Orvia. When reporting a bug, sharing your device model, OS version, and steps to reproduce will help us troubleshoot.'
		}
	];
</script>

<svelte:head>
	<title>FAQ &amp; Help — Orvia</title>
	<meta
		name="description"
		content="Frequently asked questions, installation guides for Android APK and Windows, troubleshooting, and support for Orvia."
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
				<span class="text-[oklch(0.7_0.2_20)]">Support</span> — Help &amp; Guides
			</div>
			<h1 class="font-display text-3xl sm:text-4xl text-[oklch(0.95_0.015_85)]">
				Frequently Asked Questions
			</h1>
			<p class="mt-2 text-xs sm:text-sm text-[oklch(0.6_0.02_265)]">
				Installation guides, update instructions, and troubleshooting for Orvia v3.0.7
			</p>
		</div>

		<!-- Direct Download Banner -->
		<div class="mb-8 rounded-2xl border hairline bg-[oklch(0.15_0.008_265/0.7)] p-5 sm:p-6 backdrop-blur flex flex-col sm:flex-row items-center justify-between gap-4">
			<div>
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)]">
					Looking to download Orvia?
				</h2>
				<p class="text-xs text-[oklch(0.7_0.02_265)] mt-1">
					Official verified release v3.0.7 for Android (APK) and Windows (ZIP).
				</p>
			</div>
			<div class="flex flex-wrap items-center gap-2.5">
				<a
					href="https://ankitcodes30.github.io/Orvia/downloads/app-release.apk"
					on:click={() => trackDownloadClick('android')}
					class="rounded-full btn-brand px-4 py-2 text-xs font-medium inline-flex items-center gap-1.5"
				>
					<i class="fa-brands fa-android"></i> Android APK
				</a>
				<a
					href="https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip"
					on:click={() => trackDownloadClick('windows')}
					class="rounded-full border border-[oklch(0.95_0.015_85/0.2)] px-4 py-2 text-xs font-medium text-[oklch(0.95_0.015_85)] hover:border-brand hover:text-brand transition-colors inline-flex items-center gap-1.5"
				>
					<i class="fa-brands fa-windows"></i> Windows ZIP
				</a>
			</div>
		</div>

		<!-- FAQ Accordion -->
		<div class="space-y-3">
			{#each faqs as item, i}
				<div class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] backdrop-blur overflow-hidden transition-colors hover:border-[oklch(0.7_0.2_20/0.4)]">
					<button
						type="button"
						on:click={() => toggleItem(i)}
						class="w-full flex items-center justify-between p-5 sm:p-6 text-left cursor-pointer focus:outline-none"
					>
						<span class="font-display text-base sm:text-lg text-[oklch(0.95_0.015_85)] pr-4">
							{item.q}
						</span>
						<span class="grid h-7 w-7 place-items-center rounded-full border hairline text-xs text-[oklch(0.7_0.02_265)] shrink-0 transition-transform {openIndex === i ? 'rotate-180 text-brand' : ''}">
							<i class="fa-solid fa-chevron-down"></i>
						</span>
					</button>

					{#if openIndex === i}
						<div class="px-5 pb-5 sm:px-6 sm:pb-6 pt-0 border-t hairline mt-1 text-xs sm:text-sm text-[oklch(0.75_0.02_265)] leading-relaxed">
							<p class="pt-4">{item.a}</p>

							{#if item.action}
								<div class="mt-4 pt-2">
									<a
										href={item.action.href}
										on:click={() => trackDownloadClick(item.action.platform)}
										class="inline-flex items-center gap-2 rounded-full btn-brand px-4 py-2 text-xs font-medium"
									>
										<i class="fa-solid fa-download"></i>
										{item.action.label}
									</a>
								</div>
							{/if}
						</div>
					{/if}
				</div>
			{/each}
		</div>

		<!-- Still Need Help Box -->
		<div class="mt-10 rounded-2xl border border-[oklch(0.95_0.015_85/0.1)] bg-[oklch(0.12_0.006_265/0.5)] p-6 text-center">
			<h3 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-2">
				Still have questions?
			</h3>
			<p class="text-xs text-[oklch(0.7_0.02_265)] mb-4 max-w-md mx-auto leading-relaxed">
				Reach out to the project maintainer directly. We are happy to assist with setup questions or playback issues.
			</p>
			<a
				href="mailto:ankitkumbhare301@gmail.com"
				class="inline-flex items-center gap-2 rounded-full border border-[oklch(0.7_0.2_20/0.4)] bg-[oklch(0.7_0.2_20/0.1)] px-5 py-2.5 text-xs text-white hover:border-brand transition-colors"
			>
				<i class="fa-solid fa-envelope text-brand"></i>
				Contact ankitkumbhare301@gmail.com
			</a>
		</div>
	</main>

	<!-- Minimal Footer -->
	<footer class="border-t hairline py-8 text-center text-xs text-[oklch(0.6_0.02_265)]">
		<div class="mx-auto max-w-5xl px-5 flex flex-wrap items-center justify-between gap-4">
			<p>&copy; {new Date().getFullYear()} Orvia · Built by Ankit Kumbhare</p>
			<div class="flex items-center gap-4">
				<a href="{base}/privacy" class="hover:text-white transition-colors">Privacy</a>
				<a href="{base}/terms" class="hover:text-white transition-colors">Terms</a>
				<a href="{base}/licenses" class="hover:text-white transition-colors">Licenses</a>
			</div>
		</div>
	</footer>
</div>
