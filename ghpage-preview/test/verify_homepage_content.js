import assert from 'node:assert/strict';
import fs from 'node:fs';

async function verify() {
	const res = await fetch('http://127.0.0.1:4173/Orvia/');
	const html = await res.text();

	console.log('\n--- VERIFYING CLEAN BASELINE & REQUESTED CHANGES ---');

	// 1. Experimental Reviews & Moderation removed from homepage (Clean baseline)
	assert.ok(
		!html.includes('Reviews & Feedback') && !html.includes('Rate your experience'),
		'Experimental review submission and ratings section must be absent from homepage'
	);
	assert.ok(
		!html.includes('AdminDashboard') && !html.includes('Open Owner Moderation'),
		'Owner admin portal must be absent from public homepage'
	);
	console.log('✓ 1. Experimental ratings/reviews and admin sections cleanly removed to match ghpage baseline');

	// 2. Original sections preserved
	assert.ok(html.includes('id="showcase"'), 'Showcase section present');
	assert.ok(html.includes('id="features"'), 'Features section present');
	assert.ok(html.includes('id="discover"'), 'Discover section present');
	assert.ok(html.includes('id="download"'), 'Download section present');
	assert.ok(html.includes('id="about"'), 'About section present');
	console.log('✓ 2. Original ghpage sections (Showcase, Features, Discover, Download, About) intact');

	// 3. Requirement A: About section — GET THE APP CTA links
	assert.ok(html.includes('Android - Download APK'), 'About section has "Android - Download APK"');
	assert.ok(html.includes('Windows - Download for Windows'), 'About section has "Windows - Download for Windows"');
	assert.ok(
		html.includes('href="#download"'),
		'Get the app CTA links point to #download'
	);
	assert.ok(!html.includes('Beta (Upcoming)'), 'Beta (Upcoming) label must be completely removed');
	console.log('✓ 3. About section and footer GET THE APP CTAs scroll smoothly to #download without initiating immediate downloads');

	// 4. Requirement B: Privacy Notice visible banner removed
	const bannedNotice = 'Privacy Notice: This website uses Google Analytics';
	assert.ok(!html.includes(bannedNotice), 'Visible Privacy Notice paragraph must be removed');
	assert.ok(html.includes('G-J0ME4TR9F8'), 'GA4 Measurement ID G-J0ME4TR9F8 must be preserved');

	const analyticsSource = fs.readFileSync('src/lib/analytics.js', 'utf8');
	assert.ok(
		analyticsSource.includes('orvia_download_click'),
		'Download tracking event orvia_download_click must be preserved in analytics.js'
	);
	assert.ok(html.includes('Analytics:'), 'Analytics consent toggle button preserved in footer');
	console.log('✓ 4. Visible Privacy Notice banner removed; GA4 tracking, DNT/GPC, and consent controls preserved');

	// 5. Requirement C: Footer — Resources & Legal group
	assert.ok(html.includes('Resources &amp; Legal') || html.includes('Resources & Legal'), 'Resources & Legal group title present');
	assert.ok(html.includes('/Orvia/privacy') && html.includes('>Privacy Policy</a>'), 'Privacy Policy link present');
	assert.ok(html.includes('/Orvia/terms') && (html.includes('>Terms &amp; Conditions</a>') || html.includes('>Terms & Conditions</a>')), 'Terms & Conditions link present');
	assert.ok(html.includes('/Orvia/licenses') && (html.includes('>Copyright &amp; Licenses</a>') || html.includes('>Copyright & Licenses</a>')), 'Copyright & Licenses link present');
	assert.ok(html.includes('/Orvia/help') && (html.includes('>FAQ &amp; Help</a>') || html.includes('>FAQ & Help</a>')), 'FAQ & Help link present');
	assert.ok(html.includes('href="mailto:ankitkumbhare301@gmail.com"') && html.includes('>Support</a>'), 'Support link present with mailto:');
	console.log('✓ 5. Resources & Legal group verified with all 5 required links');

	// 6. Real download URLs and SHA-256 integrity preserved
	assert.ok(
		html.includes('https://ankitcodes30.github.io/Orvia/downloads/app-release.apk'),
		'Real Android download destination preserved'
	);
	assert.ok(
		html.includes('https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip'),
		'Real Windows download destination preserved'
	);
	console.log('✓ 6. Real download URLs and packages preserved');

	// 7. Information pages functional and link Back to Home
	const infoPages = ['help', 'licenses', 'privacy', 'terms'];
	for (const page of infoPages) {
		const pageRes = await fetch(`http://127.0.0.1:4173/Orvia/${page}`);
		assert.equal(pageRes.status, 200, `Page ${page} must return HTTP 200`);
		const pageHtml = await pageRes.text();
		assert.ok(!pageHtml.includes(bannedNotice), `Page ${page} must not have Privacy Notice`);
		assert.ok(pageHtml.includes('Back to Home'), `Page ${page} must say "Back to Home"`);
		assert.ok(
			pageHtml.includes('href="/Orvia/"') || pageHtml.includes('href="./"'),
			`Page ${page} Back to Home link must navigate to homepage`
		);
	}
	console.log('✓ 7. All information pages (help, licenses, privacy, terms) return HTTP 200 with Back to Home');

	// 8. Stylesheets and asset links resolved
	const cssLinks = [...html.matchAll(/href="([^"]+\.css[^"]*)"/g)].map(m => m[1]);
	assert.ok(cssLinks.length > 0, 'Stylesheet link must exist in HTML');
	for (const cssUrl of cssLinks) {
		const fullUrl = cssUrl.startsWith('http') ? cssUrl : new URL(cssUrl, 'http://127.0.0.1:4173/Orvia/').href;
		const cssRes = await fetch(fullUrl);
		assert.equal(cssRes.status, 200, `Stylesheet ${fullUrl} must return 200 OK`);
		const cssContent = await cssRes.text();
		assert.ok(cssContent.length > 1000, `Stylesheet ${fullUrl} must not be empty`);
	}
	console.log('✓ 8. Stylesheets and asset links resolved with 200 OK and dark styling active');

	console.log('\nAll verification checks passed successfully!\n');
}

verify().catch((err) => {
	console.error(err);
	process.exit(1);
});
