<script>
	import '../app.css';
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { initAnalytics } from '$lib/analytics.js';

	let { children } = $props();

	onMount(() => {
		initAnalytics();
	});
</script>

<svelte:head>
	<link rel="icon" type="image/png" href={`${base}/assets/OrviaFavicon.png`} />
</svelte:head>

<main>
	{@render children?.()}
</main>

<nav style="display:none" aria-hidden="true">
	<a href="{base}/playlist">Playlist</a>
	<a href="{base}/track">Track</a>
	<a href="{base}/p">Short Link</a>
</nav>
