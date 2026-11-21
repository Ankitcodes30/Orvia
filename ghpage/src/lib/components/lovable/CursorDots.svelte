<script>
	import { onMount } from 'svelte';

	let canvas;

	onMount(() => {
		if (!canvas || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		const dpr = Math.min(window.devicePixelRatio || 1, 2);
		let w = 0, h = 0, raf = 0;
		const mouse = { x: -9999, y: -9999 };
		let pts = [];
		const gap = 34;

		const resize = () => {
			w = window.innerWidth;
			h = window.innerHeight;
			canvas.width = w * dpr;
			canvas.height = h * dpr;
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
			pts = [];
			for (let y = gap / 2; y < h; y += gap) {
				for (let x = gap / 2; x < w; x += gap) {
					pts.push({ x, y, ox: x, oy: y });
				}
			}
		};

		const R = 140;
		const tick = () => {
			ctx.clearRect(0, 0, w, h);
			for (const p of pts) {
				const dx = p.ox - mouse.x;
				const dy = p.oy - mouse.y;
				const d = Math.hypot(dx, dy);
				const f = Math.max(0, 1 - d / R);
				const tx = p.ox + (d ? (dx / d) * f * 18 : 0);
				const ty = p.oy + (d ? (dy / d) * f * 18 : 0);
				p.x += (tx - p.x) * 0.15;
				p.y += (ty - p.y) * 0.15;
				const a = 0.06 + f * 0.75;
				ctx.fillStyle = f > 0.02 ? `hsla(${345 + f * 35}, 95%, 65%, ${a})` : `rgba(255,240,230,${a})`;
				ctx.beginPath();
				ctx.arc(p.x, p.y, 0.8 + f * 1.8, 0, Math.PI * 2);
				ctx.fill();
			}
			raf = requestAnimationFrame(tick);
		};

		const move = (e) => {
			mouse.x = e.clientX;
			mouse.y = e.clientY;
		};

		const leave = () => {
			mouse.x = -9999;
			mouse.y = -9999;
		};

		resize();
		tick();

		window.addEventListener('resize', resize);
		window.addEventListener('pointermove', move);
		document.addEventListener('pointerleave', leave);

		return () => {
			cancelAnimationFrame(raf);
			window.removeEventListener('resize', resize);
			window.removeEventListener('pointermove', move);
			document.removeEventListener('pointerleave', leave);
		};
	});
</script>

<canvas bind:this={canvas} aria-hidden="true" class="pointer-events-none fixed inset-0 z-[1]"></canvas>
