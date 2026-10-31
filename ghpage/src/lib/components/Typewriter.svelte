<script>
	import { onMount } from 'svelte';

	export let phrases = [
		'Your music. Your atmosphere.',
		'Made with passion, powered by music.',
		'Pure sound, free and open source.'
	];

	let phraseIndex = 0;
	let currentText = phrases[0];
	let isDeleting = false;
	let prefersReducedMotion = false;
	let timeoutId;

	onMount(() => {
		const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
		prefersReducedMotion = mediaQuery.matches;

		if (prefersReducedMotion) {
			currentText = phrases[0];
			return;
		}

		let charIndex = phrases[0].length;
		currentText = phrases[0];

		function tick() {
			const targetPhrase = phrases[phraseIndex];

			if (isDeleting) {
				charIndex--;
				currentText = targetPhrase.substring(0, charIndex);
			} else {
				charIndex++;
				currentText = targetPhrase.substring(0, charIndex);
			}

			let delay = isDeleting ? 30 : 65;

			if (!isDeleting && charIndex === targetPhrase.length) {
				delay = 2400; // Pause at full phrase
				isDeleting = true;
			} else if (isDeleting && charIndex === 0) {
				isDeleting = false;
				phraseIndex = (phraseIndex + 1) % phrases.length;
				delay = 400; // Pause before typing next
			}

			timeoutId = setTimeout(tick, delay);
		}

		timeoutId = setTimeout(tick, 1800);

		return () => {
			if (timeoutId) clearTimeout(timeoutId);
		};
	});
</script>

<div class="typewriter-container" aria-label={phrases[phraseIndex]}>
	<span class="sr-only">{phrases.join('. ')}</span>
	<span class="typewriter-text" aria-hidden="true">
		{currentText}<span class="caret" class:blink={!prefersReducedMotion}></span>
	</span>
</div>

<style>
	.typewriter-container {
		display: inline-flex;
		align-items: center;
		min-height: 2.2rem;
		margin: 0.2rem 0 0.8rem 0;
	}

	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}

	.typewriter-text {
		font-family: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, sans-serif;
		font-weight: 600;
		font-size: clamp(1.1rem, 3.2vw, 1.55rem);
		letter-spacing: 0.3px;
		line-height: 1.3;
		background: linear-gradient(90deg, #ff8a00, #e52e71, #ff5258);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		display: inline-block;
	}

	.caret {
		display: inline-block;
		width: 3px;
		height: 1.1em;
		background-color: #ff5258;
		margin-left: 4px;
		vertical-align: -0.15em;
		border-radius: 1px;
	}

	.caret.blink {
		animation: blink 0.9s infinite;
	}

	@keyframes blink {
		0%, 100% { opacity: 1; }
		50% { opacity: 0; }
	}

	@media (prefers-reduced-motion: reduce) {
		.caret {
			display: none;
		}
	}
</style>
