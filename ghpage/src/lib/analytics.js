import { browser } from '$app/environment';

export const GA_MEASUREMENT_ID = 'G-J0ME4TR9F8';

let initialized = false;

/**
 * Checks whether analytics tracking is allowed based on privacy preferences.
 * Honors:
 * - Do Not Track (DNT) browser headers
 * - Global Privacy Control (GPC)
 * - User local opt-out preference in localStorage
 *
 * @returns {boolean}
 */
export function isTrackingAllowed() {
	if (!browser) return false;
	try {
		const dnt = navigator.doNotTrack || window.doNotTrack || navigator.msDoNotTrack;
		if (dnt === '1' || dnt === 'yes') return false;
		if (navigator.globalPrivacyControl === true) return false;
		if (localStorage.getItem('orvia_analytics_optout') === 'true') return false;
	} catch {
		return true;
	}
	return true;
}

/**
 * Updates analytics consent preference in localStorage and window ga-disable flag.
 *
 * @param {boolean} allowed
 */
export function setAnalyticsConsent(allowed) {
	if (!browser) return;
	try {
		if (allowed) {
			localStorage.removeItem('orvia_analytics_optout');
			const dnt = navigator.doNotTrack || window.doNotTrack || navigator.msDoNotTrack;
			const isDnt = dnt === '1' || dnt === 'yes';
			const isGpc = navigator.globalPrivacyControl === true;
			if (!isDnt && !isGpc) {
				window[`ga-disable-${GA_MEASUREMENT_ID}`] = false;
			}
		} else {
			localStorage.setItem('orvia_analytics_optout', 'true');
			window[`ga-disable-${GA_MEASUREMENT_ID}`] = true;
		}
	} catch {}
}

/**
 * Initializes Google Analytics 4 (GA4) conditionally and idempotently.
 *
 * Safe privacy design:
 * - Only runs in the browser.
 * - Enforces Measurement ID: G-J0ME4TR9F8.
 * - Idempotent: checks for existing tag in app.html or DOM; NEVER adds duplicate tags.
 * - Automatically enables IP anonymization.
 * - Immediately disables tracking if DNT, GPC, or local opt-out is detected.
 * - Respects client-side navigation without duplicate page-view events.
 */
export function initAnalytics() {
	if (!browser) return;
	if (initialized) return;

	// Apply privacy consent guard
	if (!isTrackingAllowed()) {
		window[`ga-disable-${GA_MEASUREMENT_ID}`] = true;
	}

	initialized = true;

	// If gtag is already initialized by app.html, ensure dataLayer and exit without injecting duplicate script
	if (typeof window !== 'undefined' && typeof window.gtag === 'function') {
		return;
	}

	// Fallback dynamic script injection if app.html did not load the tag
	if (!document.querySelector(`script[src*="${GA_MEASUREMENT_ID}"]`)) {
		try {
			const script = document.createElement('script');
			script.async = true;
			script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(GA_MEASUREMENT_ID)}`;
			document.head.appendChild(script);

			window.dataLayer = window.dataLayer || [];
			function gtag() {
				window.dataLayer.push(arguments);
			}
			window.gtag = gtag;

			gtag('js', new Date());
			gtag('config', GA_MEASUREMENT_ID, {
				anonymize_ip: true
			});
		} catch (e) {
			// Silently ignore if blocked by privacy or adblock extensions
		}
	}
}

/**
 * Track a custom event in GA4.
 * Strictly avoids sending any personal identifiers, email addresses, passwords, or sensitive data.
 *
 * @param {string} eventName
 * @param {Record<string, any>} [params]
 */
export function trackEvent(eventName, params = {}) {
	if (!browser) return;
	if (!isTrackingAllowed()) return;

	try {
		if (typeof window !== 'undefined' && typeof window.gtag === 'function') {
			window.gtag('event', eventName, params);
		}
	} catch (e) {
		// Ignore tracking failures
	}
}

let lastClickTime = 0;
let lastPlatform = '';

/**
 * Tracks click on an Android APK or Windows ZIP download button.
 *
 * Exact Event Specification:
 * - Android: event `orvia_download_click`, parameter `platform = 'android'`
 * - Windows: event `orvia_download_click`, parameter `platform = 'windows'`
 *
 * Rules:
 * - Tracks user click intent only; never claims confirmed completed download.
 * - Avoids duplicate events for a single click using a 400ms cooldown debounce.
 * - Does not block, stop, or delay the download navigation.
 *
 * @param {'android' | 'windows' | string} platform
 */
export function trackDownloadClick(platform) {
	if (!browser) return;

	const now = Date.now();
	// Cooldown debounce of 400ms prevents duplicate events on accidental rapid double-clicks
	if (platform === lastPlatform && now - lastClickTime < 400) {
		return;
	}
	lastClickTime = now;
	lastPlatform = platform;

	const normalizedPlatform = platform === 'android' ? 'android' : (platform === 'windows' ? 'windows' : String(platform).toLowerCase());

	trackEvent('orvia_download_click', {
		platform: normalizedPlatform
	});
}
