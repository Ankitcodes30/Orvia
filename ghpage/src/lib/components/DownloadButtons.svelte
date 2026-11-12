<script>
	import { trackDownloadClick } from '$lib/analytics.js';

	const androidDownloadLink = "https://ankitcodes30.github.io/Orvia/downloads/app-release.apk";
	const windowsDownloadLink = "https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip";
	const releasesPageLink = "https://github.com/Ankitcodes30/Orvia/releases";
	const sourceforgeLink = "https://sourceforge.net/projects/orvia/files/";

	export let downloads = [
		{
			platform: 'android',
			icon: 'fa-brands fa-android',
			name: 'Android APK',
			href: androidDownloadLink,
			size: '52.0 MB · Direct Download'
		},
		{
			platform: 'windows',
			icon: 'fa-brands fa-windows',
			name: 'Windows ZIP',
			href: windowsDownloadLink,
			size: '37.8 MB · Direct Download'
		},
		{
			platform: 'linux',
			icon: 'fa-brands fa-linux',
			name: 'Linux / Other',
			href: sourceforgeLink,
			size: 'Builds'
		}
	];

	let showIntegrity = false;

	function toggleIntegrity() {
		showIntegrity = !showIntegrity;
	}
</script>

<div class="download-section">
	<!-- Top row of platform download buttons -->
	<div class="download-buttons">
		{#each downloads as download}
			<a
				href={download.href}
				class="download-btn"
				target="_blank"
				rel="noopener noreferrer"
				on:click={() => trackDownloadClick(download.platform)}
			>
				<i class={download.icon}></i>
				<div class="btn-text">
					<span class="btn-name">{download.name}</span>
					<small class="btn-size">{download.size}</small>
				</div>
			</a>
		{/each}
	</div>

	<!-- Concise visible direct download and destination note -->
	<p class="download-subnote">
		<i class="fa-solid fa-circle-check text-green"></i>
		Download buttons provide verified direct downloads for Android and Windows. Packages are signed and verified with SHA-256 integrity checksums.
	</p>

	<!-- Checksums & Verification Toggle -->
	<div class="integrity-toggle-container">
		<button class="integrity-toggle-btn" on:click={toggleIntegrity}>
			<i class="fa-solid fa-shield-halved"></i>
			<span>{showIntegrity ? 'Hide SHA-256 Checksums & Notes' : 'View Verified SHA-256 Checksums & Notes'}</span>
		</button>
	</div>

	{#if showIntegrity}
		<div class="integrity-card">
			<h4><i class="fa-solid fa-circle-check text-green"></i> Release v3.0.7+8 Verified Notes & SHA-256</h4>
			<p class="install-tip"><i class="fa-solid fa-circle-info"></i> Release v3.0.7+8 binaries are verified and served directly. Checksums below match the exact published packages.</p>
			<div class="checksum-row">
				<strong>Android Release APK (v3.0.7+8 · 52.0 MB):</strong>
				<code>E0F9FA4C463835700957CEFA1A7C5BC9CECB36297BB2AD8D17F5979AFDDD7754</code>
				<p class="install-tip"><i class="fa-solid fa-certificate"></i> Signing: Official Production Release Key (CN=Ankit Kumbhare, O=Orvia).</p>
				<p class="install-tip"><i class="fa-solid fa-gear"></i> Android Install: Enable "Install unknown apps" from browser settings if prompted.</p>
			</div>
			<div class="checksum-row">
				<strong>Windows Portable ZIP (v3.0.7+8 · 37.8 MB):</strong>
				<code>BC87EB35123F49C7512519EF50AE6D8BC72129227AFE0FC3A621E31D48B90CFA</code>
				<p class="install-tip"><i class="fa-brands fa-windows"></i> Windows Install: Extract the ZIP archive completely, then launch <code>orvia.exe</code>.</p>
			</div>
		</div>
	{/if}

	<!-- Larger buttons for Official GitHub Releases and SourceForge Direct Download -->
	<div class="custom-download-buttons">
		<a
			href={releasesPageLink}
			class="custom-btn"
			target="_blank"
			rel="noopener noreferrer"
			on:click={() => trackDownloadClick('github', 'GitHub Releases', releasesPageLink)}
		>
			<i class="fa-brands fa-github"></i>
			<div class="button-info">
				<span>GitHub Releases</span>
				<small>View release packages on GitHub</small>
			</div>
		</a>
		<a
			href={sourceforgeLink}
			class="custom-btn"
			target="_blank"
			rel="noopener noreferrer"
			on:click={() => trackDownloadClick('sourceforge', 'SourceForge Mirror', sourceforgeLink)}
		>
			<img src="https://a.fsdn.com/con/img/sandiego/svg/originals/sf-icon-orange-no_sf.svg" alt="SourceForge Logo" class="sourceforge-icon">
			<div class="button-info">
				<span>SourceForge Mirror</span>
				<small>Alternative open-source mirror</small>
			</div>
		</a>
	</div>
</div>

<style>
	.download-section { 
		/* reduce bottom margin so following section (About) sits closer on mobile */
		margin-bottom: 1rem; 
		/* Add horizontal padding to prevent elements from touching the screen edges */
		padding: 0 1rem;
	}
	
	.download-buttons { 
		display: flex; 
		gap: 1rem; 
		justify-content: center; 
		flex-wrap: wrap;
	}
	
	.download-btn { 
		padding: 0.8rem 1.2rem; 
		background: rgba(255, 255, 255, 0.08); 
		border: 2px solid rgba(255, 255, 255, 0.15); 
		border-radius: 12px; 
		backdrop-filter: blur(12px); 
		display: flex; 
		align-items: center; 
		justify-content: center; 
		gap: 8px; 
		transition: all .3s ease; 
		/* Allow buttons to grow and shrink flexibly from a base size */
		flex: 1 1 120px;
		max-width: 150px; /* Prevent buttons from becoming too wide on larger screens */
		text-decoration: none;
		color: #ffffff;
		font-weight: 500;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}
	
	.download-btn:hover { 
		background: rgba(255, 255, 255, 0.15);
		border-color: rgba(255, 255, 255, 0.3); 
		box-shadow: 0 6px 20px rgba(255, 255, 255, 0.2);
		transform: translateY(-2px) scale(1.02);
	}
	
	.download-btn i { 
		font-size: 1.3rem; 
		color: #ffffff; 
		text-shadow: 0 0 8px rgba(255, 255, 255, 0.4);
	}
	
	.btn-text {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		line-height: 1.2;
	}

	.btn-name {
		font-size: 0.9rem;
		font-weight: 600;
		color: #ffffff;
		text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.6);
	}

	.btn-size {
		font-size: 0.72rem;
		color: rgba(255, 255, 255, 0.65);
		font-weight: 400;
	}

	.download-subnote {
		margin: 0.8rem auto 0;
		font-size: 0.78rem;
		color: rgba(255, 255, 255, 0.75);
		text-align: center;
		max-width: 620px;
		line-height: 1.4;
	}

	.download-subnote i {
		color: #ffb74d;
		margin-right: 4px;
	}

	.integrity-toggle-container {
		display: flex;
		justify-content: center;
		margin-top: 1rem;
	}

	.integrity-toggle-btn {
		background: transparent;
		border: 1px dashed rgba(255, 255, 255, 0.3);
		color: rgba(255, 255, 255, 0.85);
		padding: 0.45rem 1rem;
		border-radius: 20px;
		font-size: 0.8rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: all 0.2s ease;
	}

	.integrity-toggle-btn:hover {
		border-color: rgba(255, 255, 255, 0.6);
		color: #ffffff;
		background: rgba(255, 255, 255, 0.05);
	}

	.integrity-card {
		background: rgba(16, 11, 33, 0.5);
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 12px;
		padding: 1.2rem;
		margin-top: 1rem;
		max-width: 650px;
		margin-left: auto;
		margin-right: auto;
		text-align: left;
		backdrop-filter: blur(10px);
	}

	.integrity-card h4 {
		margin: 0 0 0.8rem 0;
		font-size: 0.95rem;
		color: #ffffff;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.text-green {
		color: #4CAF50;
	}

	.checksum-row {
		margin-bottom: 0.8rem;
	}

	.checksum-row:last-child {
		margin-bottom: 0;
	}

	.checksum-row strong {
		display: block;
		font-size: 0.82rem;
		color: #e0e0e0;
		margin-bottom: 3px;
	}

	.checksum-row code {
		display: block;
		background: rgba(0, 0, 0, 0.4);
		padding: 0.4rem 0.6rem;
		border-radius: 6px;
		font-size: 0.72rem;
		color: #80cbc4;
		word-break: break-all;
		font-family: monospace;
	}

	.install-tip {
		margin: 4px 0 0 0;
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.7);
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.custom-download-buttons {
		display: flex;
		gap: 1.5rem;
		justify-content: center;
		margin-top: 2rem;
		flex-wrap: wrap;
		direction: row;
	}

	/* A common, professional style for the custom GitHub and SourceForge buttons */
	.custom-btn {
		display: flex;
		align-items: center;
		justify-content: flex-start;
		gap: 1rem;
		/* Use the same translucent panel styling as other sections to avoid a 'disabled' solid block look */
		background: rgba(16, 11, 33, 0.15);
		border: 1px solid rgba(255,255,255,0.06);
		color: #fff;
		padding: 0.8rem 1.2rem;
		border-radius: 8px;
		box-shadow: 0 6px 20px rgba(0, 0, 0, 0.25);
		text-decoration: none;
		transition: transform 0.3s ease, box-shadow 0.3s ease;
		/* Flexible sizing for different screens */
		flex: 1 1 280px;
		max-width: 260px;
		min-height: 56px; /* slightly smaller min height */
		box-sizing: border-box; /* Ensures padding is included in the total width/height */
	}

	.custom-btn:hover {
		box-shadow: 0 8px 28px rgba(0, 0, 0, 0.45);
		transform: translateY(-4px);
	}

	.custom-btn .fa-github,
	.custom-btn .fa-box-archive {
		font-size: 1.8rem;
	}

	.sourceforge-icon {
		width: 32px;
		height: 32px;
	}

	/* Common class for the text content inside custom buttons */
	.button-info {
		display: flex;
		flex-direction: column;
		text-align: left;
	}

	.button-info span {
		font-size: 1rem;
		font-weight: bold;
	}

	.button-info small {
		font-size: 0.8rem;
		color: #aaa;
	}

	/* --- Responsive Adjustments --- */

	/* For Tablets */
	@media (max-width: 768px) {
		.custom-btn {
			/* Adjust flexible basis for tablets */
			flex-basis: 260px;
		}
	}
	
	/* For Mobile Phones */
	@media (max-width: 640px) {
		.download-section {
			padding: 0 0.5rem; /* Reduce side padding on small screens */
		}

		.download-buttons {
			gap: 0.5rem; /* Make the gap smaller */
		}
		
		.download-btn {
			padding: 0.6rem 1rem;
			flex-basis: 100px; /* Adjust size for mobile */
		}
		
		.download-btn i { font-size: 1.1rem; }
		.download-btn span { font-size: 0.8rem; }

		/* Stack the custom buttons vertically on mobile and reduce their top margin */
		.custom-download-buttons {
			flex-direction: column;
			gap: 0.8rem;
			/* Ensure the container and its children stretch properly */
			align-items: stretch;
			margin-top: 1rem; /* reduce space above download buttons */
		}
		
		.custom-btn {
			width: 100%;
			max-width: none;
			/* When stacked vertically, don't let buttons flex-grow and stretch the height */
			flex: 0 0 auto;
		}
	}
</style>
