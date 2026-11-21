<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';

	let open = false;
	let scrolled = false;

	const links = [
		{ href: '#showcase', label: 'The app' },
		{ href: '#features', label: 'Features' },
		{ href: '#discover', label: 'Discover' },
		{ href: '#about', label: 'About' }
	];

	function toggleMenu() {
		open = !open;
	}

	function closeMenu() {
		open = false;
	}

	onMount(() => {
		const onScroll = () => {
			scrolled = window.scrollY > 24;
		};
		onScroll();
		window.addEventListener('scroll', onScroll, { passive: true });

		const onKeyDown = (e) => {
			if (e.key === 'Escape' && open) {
				open = false;
			}
		};
		window.addEventListener('keydown', onKeyDown);

		const desktopQuery = window.matchMedia('(min-width: 1024px)');
		const onDesktopChange = (e) => {
			if (e.matches) open = false;
		};
		desktopQuery.addEventListener('change', onDesktopChange);

		return () => {
			window.removeEventListener('scroll', onScroll);
			window.removeEventListener('keydown', onKeyDown);
			desktopQuery.removeEventListener('change', onDesktopChange);
		};
	});

	$: if (typeof document !== 'undefined') {
		document.body.style.overflow = open ? 'hidden' : '';
	}
</script>

<header
	class="fixed inset-x-0 top-0 z-50 transition-colors duration-500 {scrolled || open
		? 'border-b hairline bg-[oklch(0.12_0.006_265/0.88)] backdrop-blur-md'
		: 'bg-transparent'}"
>
	<nav
		class="mx-auto flex h-16 w-full max-w-7xl items-center justify-between px-5 sm:px-6 md:px-10 lg:h-20"
		aria-label="Main"
	>
		<a href="#top" class="min-w-0" aria-label="Orvia home" on:click={closeMenu}>
			<span class="inline-flex items-center gap-2.5">
				<img
					src="{base}/assets/OrviaLogo_Master.png"
					alt="Orvia"
					width="40"
					height="40"
					class="h-10 w-10 rounded-[10px] object-cover shadow-glow"
				/>
				<span class="font-display text-2xl leading-none">Orvia</span>
			</span>
		</a>

		<ul class="hidden items-center gap-9 lg:flex">
			{#each links as link}
				<li>
					<a
						href={link.href}
						class="text-sm text-[oklch(0.7_0.02_265)] transition-colors hover:text-[oklch(0.95_0.015_85)]"
					>
						{link.label}
					</a>
				</li>
			{/each}
		</ul>

		<a
			href="#download"
			class="hidden shrink-0 rounded-full border border-[oklch(0.95_0.015_85/0.2)] px-5 py-2 text-sm transition-colors hover:border-[oklch(0.7_0.2_20)] hover:text-[oklch(0.7_0.2_20)] lg:inline-flex"
		>
			Get the app
		</a>

		<button
			type="button"
			class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-[oklch(0.95_0.015_85/0.15)] bg-transparent text-[oklch(0.95_0.015_85)] transition-colors hover:bg-[oklch(0.95_0.015_85/0.05)] lg:hidden"
			aria-label={open ? 'Close menu' : 'Open menu'}
			aria-expanded={open}
			aria-controls="mobile-menu"
			on:click={toggleMenu}
		>
			{#if open}
				<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
					<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
				</svg>
			{:else}
				<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
					<path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
				</svg>
			{/if}
		</button>
	</nav>

	<div
		id="mobile-menu"
		hidden={!open}
		class="max-h-[calc(100dvh-4rem)] overflow-y-auto overscroll-contain bg-[oklch(0.12_0.006_265)] px-5 sm:px-6 pb-8 pt-3 lg:hidden border-b hairline"
	>
		<ul class="flex flex-col mx-auto max-w-7xl">
			{#each [...links, { href: '#download', label: 'Get the app' }] as l, i}
				<li class="border-b hairline">
					<a
						href={l.href}
						on:click={closeMenu}
						class="grid grid-cols-[minmax(0,1fr)_auto] items-baseline gap-4 py-4 font-display text-2xl sm:text-3xl text-[oklch(0.95_0.015_85)] hover:text-[oklch(0.7_0.2_20)]"
					>
						{l.label}
						<span class="eyebrow">0{i + 1}</span>
					</a>
				</li>
			{/each}
		</ul>
	</div>
</header>
