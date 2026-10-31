<script>
	import { base } from '$app/paths';
</script>

<svelte:head>
	<title>Terms &amp; Conditions — Orvia</title>
	<meta
		name="description"
		content="Terms and Conditions governing the use of the Orvia music player website and software packages."
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
				<span class="text-[oklch(0.7_0.2_20)]">Legal</span> — Terms &amp; Conditions
			</div>
			<h1 class="font-display text-3xl sm:text-4xl text-[oklch(0.95_0.015_85)]">
				Terms &amp; Conditions
			</h1>
			<p class="mt-2 text-xs text-[oklch(0.6_0.02_265)]">
				Effective: October 2026
			</p>
		</div>

		<div class="space-y-8 text-sm text-[oklch(0.75_0.02_265)] leading-relaxed">
			<!-- Section 1: Overview & Acceptance -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					1. Acceptance &amp; Permitted Use
				</h2>
				<p class="mb-3">
					These Terms &amp; Conditions explain the permitted use of Orvia and its website, including applicable usage guidelines, responsibilities, and limitations. Please review them before using the software or website.
				</p>
				<p>
					By accessing the Orvia website or installing the Orvia application for Android or Windows, you agree to these Terms. Orvia is an open-source, non-commercial software project designed to provide a lightweight, ad-free personal audio playback experience.
				</p>
			</section>

			<!-- Section 2: Software License & Downloads -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					2. Software License &amp; Downloads
				</h2>
				<p class="mb-3">
					The Orvia application is released under the <strong>GNU General Public License v2.0 (GPL-2.0)</strong>.
				</p>
				<ul class="list-disc pl-5 space-y-2 text-xs text-[oklch(0.7_0.02_265)]">
					<li>
						<strong>Rights &amp; Freedoms:</strong> You are granted the freedom to run, study, share, and modify the software in compliance with the applicable GPL-2.0 terms.
					</li>
					<li>
						<strong>Integrity Checksums:</strong> Official release packages (Android APK and Windows Portable ZIP) are accompanied by published SHA-256 integrity checksums so users can independently verify file authenticity.
					</li>
					<li>
						<strong>Update Checks:</strong> The application may query public release metadata to notify users when a verified newer version is available.
					</li>
				</ul>
			</section>

			<!-- Section 3: Content Disclaimer & Media Handling -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					3. Content Disclaimer &amp; Media Handling
				</h2>
				<p class="mb-3">
					Orvia is an audio playback client for playing local media files and supported network streams.
				</p>
				<p class="text-xs text-[oklch(0.7_0.02_265)] leading-relaxed">
					Orvia <strong>does not host, store, sell, or claim ownership</strong> over any audio files, music tracks, artist artwork, or third-party metadata that users choose to access or play through the application. Users are responsible for ensuring they possess the appropriate rights and permissions for any content they play, store, or import.
				</p>
			</section>

			<!-- Section 4: Warranty Disclaimer & Limitations -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					4. Warranty Disclaimer &amp; Limitations
				</h2>
				<p class="text-xs text-[oklch(0.7_0.02_265)] leading-relaxed">
					As provided under the GNU General Public License v2.0, the software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability arising from the use of the software.
				</p>
			</section>

			<!-- Section 5: Contact & Inquiries -->
			<section class="rounded-2xl border hairline bg-[oklch(0.14_0.007_265/0.6)] p-6 sm:p-8 backdrop-blur">
				<h2 class="font-display text-lg text-[oklch(0.95_0.015_85)] mb-3">
					5. Inquiries &amp; Project Contact
				</h2>
				<p class="mb-3">
					Questions regarding these terms can be directed to the project maintainer:
				</p>
				<p class="text-xs font-mono text-[oklch(0.85_0.015_85)] space-y-1">
					<span>Project Maintainer: Ankit Kumbhare</span><br />
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
				<a href="{base}/privacy" class="hover:text-white transition-colors">Privacy</a>
				<a href="{base}/licenses" class="hover:text-white transition-colors">Licenses</a>
				<a href="{base}/help" class="hover:text-white transition-colors">Help</a>
			</div>
		</div>
	</footer>
</div>
