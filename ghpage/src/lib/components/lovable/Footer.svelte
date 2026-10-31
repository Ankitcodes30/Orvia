<script>
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { isTrackingAllowed, setAnalyticsConsent } from '$lib/analytics.js';

	const nav = [
		{ href: '#showcase', label: 'The app' },
		{ href: '#features', label: 'Features' },
		{ href: '#discover', label: 'Discover' },
		{ href: '#about', label: 'About' }
	];

	const releases = [
		{ platform: 'Android', href: '#download' },
		{ platform: 'Windows', href: '#download' }
	];

	const social = [
		{ href: 'https://github.com/Ankitcodes30', label: 'GitHub', isExternal: true },
		{ href: 'https://www.linkedin.com/in/ankit-kumbhare-024465366', label: 'LinkedIn', isExternal: true },
		{ href: 'mailto:ankitkumbhare301@gmail.com', label: 'Get in touch', isExternal: false }
	];

	const currentYear = new Date().getFullYear();

	let analyticsAllowed = true;
	onMount(() => {
		analyticsAllowed = isTrackingAllowed();
	});

	function handleToggleAnalytics() {
		const next = !analyticsAllowed;
		setAnalyticsConsent(next);
		analyticsAllowed = isTrackingAllowed();
	}
</script>

<footer class="border-t hairline bg-[oklch(0.12_0.006_265)]">
	<div class="mx-auto w-full max-w-7xl px-5 sm:px-6 md:px-10 py-16 sm:py-20">
		<div class="grid gap-10 sm:gap-12 md:grid-cols-12">
			<!-- Col 1: Brand & Tagline -->
			<div class="md:col-span-5 flex flex-col items-center text-center md:items-start md:text-left">
				<a href="#top" class="inline-flex items-center gap-2.5">
					<img
						src="{base}/assets/OrviaLogo_Master.png"
						alt="Orvia"
						width="36"
						height="36"
						class="h-9 w-9 rounded-[10px] object-cover shadow-glow"
					/>
					<span class="font-display text-2xl leading-none">Orvia</span>
				</a>
				<p class="mt-3 sm:mt-4 max-w-xs text-sm text-[oklch(0.7_0.02_265)]">
					Your music. Your atmosphere.
				</p>
			</div>

			<!-- Col 2: Navigation Links -->
			<nav class="md:col-span-3 text-center md:text-left" aria-label="Footer Navigation">
				<p class="eyebrow mb-3 sm:mb-4">Explore</p>
				<ul class="space-y-2 text-sm">
					{#each nav as item}
						<li>
							<a href={item.href} class="text-[oklch(0.7_0.02_265)] transition-colors hover:text-[oklch(0.7_0.2_20)]">
								{item.label}
							</a>
						</li>
					{/each}
				</ul>
			</nav>

			<!-- Col 3: Get the App Links -->
			<div class="md:col-span-4 text-center md:text-left">
				<p class="eyebrow mb-3 sm:mb-4">Get the app</p>
				<ul class="space-y-2 text-sm">
					{#each releases as r}
						<li>
							<a href={r.href} class="text-[oklch(0.7_0.02_265)] transition-colors hover:text-[oklch(0.7_0.2_20)]">
								{r.platform} — Beta (Upcoming)
							</a>
						</li>
					{/each}
				</ul>
			</div>
		</div>

		<!-- Giant Watermark Text - Protected against horizontal overflow -->
		<div class="mt-14 sm:mt-20 overflow-hidden text-center select-none pointer-events-none">
			<p
				class="font-display text-[18vw] sm:text-[20vw] md:text-[14rem] lg:text-[16rem] leading-none text-[oklch(0.95_0.015_85/0.06)]"
				aria-hidden="true"
			>
				Orvia
			</p>
		</div>

		<!-- Privacy & Analytics Disclosure -->
		<div class="mt-8 border-t hairline pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-[oklch(0.65_0.02_265)]">
			<p class="text-center sm:text-left max-w-2xl leading-relaxed">
				<span class="text-[oklch(0.85_0.015_85)] font-medium">Privacy Notice:</span> This website uses Google Analytics 4 (Measurement ID: <code>G-J0ME4TR9F8</code>) with IP anonymization to measure aggregate website usage and download interactions. No personal information or passwords are ever collected. We honor browser Do Not Track (DNT) and Global Privacy Control (GPC) signals.
			</p>
			<button
				type="button"
				class="inline-flex items-center gap-1.5 rounded-full border border-[oklch(0.95_0.015_85/0.15)] px-3 py-1 text-[11px] text-[oklch(0.7_0.02_265)] transition-colors hover:border-[oklch(0.7_0.2_20/0.5)] hover:text-[oklch(0.95_0.015_85)] cursor-pointer whitespace-nowrap"
				on:click={handleToggleAnalytics}
				title="Toggle Google Analytics tracking preference"
			>
				<span class="inline-block h-1.5 w-1.5 rounded-full {analyticsAllowed ? 'bg-emerald-400' : 'bg-amber-400'}"></span>
				Analytics: {analyticsAllowed ? 'Active (Opt out)' : 'Disabled (Opt in)'}
			</button>
		</div>

		<!-- Bottom Copyright & Social Pills -->
		<div class="mt-6 flex flex-col items-center gap-5 border-t hairline pt-6 lg:flex-row lg:justify-between">
			<p class="min-w-0 text-center text-xs text-[oklch(0.7_0.02_265)] lg:text-left">
				© {currentYear} Orvia · Designed &amp; built by{' '}
				<span class="text-brand-glow font-medium">Ankit Kumbhare</span>
			</p>

			<ul class="flex flex-wrap items-center justify-center gap-2.5">
				<!-- GitHub -->
				<li>
					<a
						href={social[0].href}
						target="_blank"
						rel="noreferrer"
						class="inline-flex items-center gap-2 rounded-full border border-[oklch(0.95_0.015_85/0.15)] px-4 py-2 text-xs text-[oklch(0.7_0.02_265)] transition-colors hover:border-[oklch(0.7_0.2_20/0.5)] hover:text-[oklch(0.95_0.015_85)]"
					>
						<svg class="h-3.5 w-3.5 fill-current" viewBox="0 0 24 24">
							<path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
						</svg>
						{social[0].label}
					</a>
				</li>

				<!-- LinkedIn -->
				<li>
					<a
						href={social[1].href}
						target="_blank"
						rel="noreferrer"
						class="inline-flex items-center gap-2 rounded-full border border-[oklch(0.95_0.015_85/0.15)] px-4 py-2 text-xs text-[oklch(0.7_0.02_265)] transition-colors hover:border-[oklch(0.7_0.2_20/0.5)] hover:text-[oklch(0.95_0.015_85)]"
					>
						<svg class="h-3.5 w-3.5 fill-current" viewBox="0 0 24 24">
							<path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.79-1.75-1.764s.784-1.764 1.75-1.764 1.75.79 1.75 1.764-.783 1.764-1.75 1.764zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z" />
						</svg>
						{social[1].label}
					</a>
				</li>

				<!-- Email -->
				<li>
					<a
						href={social[2].href}
						class="inline-flex items-center gap-2 rounded-full border border-[oklch(0.95_0.015_85/0.15)] px-4 py-2 text-xs text-[oklch(0.7_0.02_265)] transition-colors hover:border-[oklch(0.7_0.2_20/0.5)] hover:text-[oklch(0.95_0.015_85)]"
					>
						<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
						</svg>
						{social[2].label}
					</a>
				</li>
			</ul>
		</div>
	</div>
</footer>
