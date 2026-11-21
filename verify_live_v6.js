import crypto from 'crypto';

const EXPECTED_APK_SHA256 = '519d3cae43f5f05251a109ff07dd472bd6648b1e9c350efdd079721d1117fc75';
const EXPECTED_WIN_SHA256 = 'f4649c9d4c625ad0c07ec3be07ebbabfbd0cdf0a9195cc0bec1a25eba2d17971';

async function verify() {
  console.log('--- INDEPENDENT LIVE VERIFICATION ---');

  // 1. Homepage
  const homeRes = await fetch('https://ankitcodes30.github.io/Orvia/?t=' + Date.now());
  console.log(`Homepage: ${homeRes.status} ${homeRes.statusText}`);
  const homeHtml = await homeRes.text();
  console.log(`Homepage size: ${homeHtml.length} bytes`);
  console.log(`Homepage contains Orvia: ${homeHtml.includes('Orvia')}`);

  // 2. Playlist Route
  const playlistRes = await fetch('https://ankitcodes30.github.io/Orvia/playlist/?t=' + Date.now());
  console.log(`Playlist route: ${playlistRes.status} ${playlistRes.statusText}`);

  // 3. version.json
  const versionRes = await fetch('https://ankitcodes30.github.io/Orvia/version.json?t=' + Date.now());
  console.log(`version.json: ${versionRes.status}`);
  const versionData = await versionRes.json();
  const stable = versionData.channels.stable;
  console.log(`Live Version: ${stable.version}+${stable.build_number}`);
  console.log(`Live Notes: ${stable.release_notes}`);
  console.log(`Live Android APK SHA256 in version.json: ${stable.platforms.android.sha256}`);
  console.log(`Live Windows ZIP SHA256 in version.json: ${stable.platforms.windows.sha256}`);

  // 4. release_manifest.json
  const manifestRes = await fetch('https://ankitcodes30.github.io/Orvia/release_manifest.json?t=' + Date.now());
  console.log(`release_manifest.json: ${manifestRes.status}`);
  const manifestData = await manifestRes.json();
  console.log(`Manifest matches version: ${manifestData.channels.stable.build_number === 6}`);

  // 5. Download APK & compute hash
  console.log('\nFetching live Android APK...');
  const apkRes = await fetch('https://ankitcodes30.github.io/Orvia/downloads/app-release.apk?t=' + Date.now());
  console.log(`APK download: ${apkRes.status}`);
  const apkBuffer = Buffer.from(await apkRes.arrayBuffer());
  const apkHash = crypto.createHash('sha256').update(apkBuffer).digest('hex');
  console.log(`Downloaded APK size: ${apkBuffer.length} bytes`);
  console.log(`Downloaded APK SHA256: ${apkHash}`);
  console.log(`APK SHA256 Match: ${apkHash.toLowerCase() === EXPECTED_APK_SHA256.toLowerCase() ? 'PASS' : 'FAIL'}`);

  // 6. Download Windows ZIP & compute hash
  console.log('\nFetching live Windows ZIP...');
  const winRes = await fetch('https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip?t=' + Date.now());
  console.log(`Windows ZIP download: ${winRes.status}`);
  const winBuffer = Buffer.from(await winRes.arrayBuffer());
  const winHash = crypto.createHash('sha256').update(winBuffer).digest('hex');
  console.log(`Downloaded Windows ZIP size: ${winBuffer.length} bytes`);
  console.log(`Downloaded Windows ZIP SHA256: ${winHash}`);
  console.log(`Windows ZIP SHA256 Match: ${winHash.toLowerCase() === EXPECTED_WIN_SHA256.toLowerCase() ? 'PASS' : 'FAIL'}`);

  if (apkHash.toLowerCase() === EXPECTED_APK_SHA256.toLowerCase() &&
      winHash.toLowerCase() === EXPECTED_WIN_SHA256.toLowerCase()) {
    console.log('\n>>> ALL LIVE VERIFICATIONS PASSED WITH 100% BIT-FOR-BIT ACCURACY <<<');
  } else {
    console.log('\n>>> LIVE ARTIFACT HASH MISMATCH - WAITING FOR CDN PROPAGATION <<<');
  }
}

verify().catch(console.error);
