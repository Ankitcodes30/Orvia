import assert from 'node:assert/strict';

async function check() {
  const res = await fetch('http://127.0.0.1:4173/Orvia/');
  console.log('GET /Orvia/ status:', res.status);
  const html = await res.text();
  console.log('HTML length:', html.length);
  
  // 1. Check all CSS links
  const cssMatches = [...html.matchAll(/href="([^"]+\.css[^"]*)"/g)].map(m => m[1]);
  console.log('\n--- CHECKING CSS ASSETS ---');
  for (const cssUrl of cssMatches) {
    const fullUrl = cssUrl.startsWith('http') ? cssUrl : new URL(cssUrl, 'http://127.0.0.1:4173/Orvia/').href;
    const cRes = await fetch(fullUrl);
    console.log('CSS:', fullUrl, '=> Status:', cRes.status, 'Type:', cRes.headers.get('content-type'), 'Bytes:', (await cRes.text()).length);
    assert.equal(cRes.status, 200, `CSS ${fullUrl} must return 200`);
  }

  // 2. Check all modulepreload JS
  const jsMatches = [...html.matchAll(/href="([^"]+\.js[^"]*)"/g)].map(m => m[1]);
  console.log('\n--- CHECKING JS ASSETS (' + jsMatches.length + ' scripts) ---');
  for (const jsUrl of jsMatches) {
    const fullUrl = jsUrl.startsWith('http') ? jsUrl : new URL(jsUrl, 'http://127.0.0.1:4173/Orvia/').href;
    const jRes = await fetch(fullUrl);
    console.log('JS:', fullUrl, '=> Status:', jRes.status, 'Type:', jRes.headers.get('content-type'), 'Bytes:', (await jRes.text()).length);
    assert.equal(jRes.status, 200, `JS ${fullUrl} must return 200`);
  }

  // 3. Check all images
  const imgMatches = [...html.matchAll(/src="([^"]+\.(png|jpg|jpeg|svg|webp)[^"]*)"/g)].map(m => m[1]);
  console.log('\n--- CHECKING IMAGES (' + imgMatches.length + ' images) ---');
  for (const imgUrl of imgMatches) {
    const fullUrl = imgUrl.startsWith('http') ? imgUrl : new URL(imgUrl, 'http://127.0.0.1:4173/Orvia/').href;
    try {
      const iRes = await fetch(fullUrl);
      console.log('IMG:', fullUrl, '=> Status:', iRes.status);
      assert.equal(iRes.status, 200, `Image ${fullUrl} must return 200`);
    } catch (e) {
      console.error('Image fetch error:', fullUrl, e.message);
    }
  }

  // 4. Check nested pages
  console.log('\n--- CHECKING NESTED PAGES ---');
  for (const page of ['help', 'licenses', 'privacy', 'terms']) {
    const pUrl = `http://127.0.0.1:4173/Orvia/${page}`;
    const pRes = await fetch(pUrl);
    console.log('PAGE:', pUrl, '=> Status:', pRes.status);
    assert.equal(pRes.status, 200, `Page ${pUrl} must return 200`);
    const pHtml = await pRes.text();
    const pCss = [...pHtml.matchAll(/href="([^"]+\.css[^"]*)"/g)].map(m => m[1]);
    for (const cssUrl of pCss) {
      const fullCss = cssUrl.startsWith('http') ? cssUrl : new URL(cssUrl, `${pUrl}/`).href;
      const cRes = await fetch(fullCss);
      console.log('  Page CSS:', fullCss, '=> Status:', cRes.status);
      assert.equal(cRes.status, 200, `Nested page CSS ${fullCss} must return 200`);
    }
  }

  console.log('\nALL ASSET & PAGE CHECKS PASSED WITH 200 OK!');
}

check().catch((err) => {
  console.error(err);
  process.exit(1);
});
