<script>
	import CursorDots from '$lib/components/lovable/CursorDots.svelte';
	import Nav from '$lib/components/lovable/Nav.svelte';
	import Hero from '$lib/components/lovable/Hero.svelte';
	import Showcase from '$lib/components/lovable/Showcase.svelte';
	import Features from '$lib/components/lovable/Features.svelte';
	import Discover from '$lib/components/lovable/Discover.svelte';
	import Download from '$lib/components/lovable/Download.svelte';
	import About from '$lib/components/lovable/About.svelte';
	import Footer from '$lib/components/lovable/Footer.svelte';
</script>

<svelte:head>
	<title>Orvia — Your music. Your atmosphere.</title>
	<meta
		name="description"
		content="Orvia is an ad-free music player designed around the way you listen. Coming to Android and Windows."
	/>
	<meta property="og:title" content="Orvia — Your music. Your atmosphere." />
	<meta property="og:description" content="An ad-free music player designed around the way you listen." />
	<meta property="og:type" content="website" />
	<meta name="twitter:card" content="summary_large_image" />
</svelte:head>

<a
	href="#main"
	class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-[oklch(0.95_0.015_85)] focus:px-4 focus:py-2 focus:text-[#0a0b0e]"
>
	Skip to content
</a>

<CursorDots />
<Nav />

<div id="main">
	<Hero />
	<Showcase />
	<Features />
	<Discover />
	<Download />
	<About />
</div>

<Footer />