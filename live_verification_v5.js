const https = require('https');
const crypto = require('crypto');

function fetch(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return resolve(fetch(res.headers.location));
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({
        statusCode: res.statusCode,
        headers: res.headers,
        body: Buffer.concat(chunks)
      }));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function verify() {
  console.log('Verifying Live GitHub Pages Deployment...');

  // 1. Version JSON
  const vRes = await fetch('https://ankitcodes30.github.io/Orvia/version.json');
  console.log('version.json HTTP Status:', vRes.statusCode);
  const versionData = JSON.parse(vRes.body.toString('utf8'));
  console.log('Live Version:', versionData.channels.stable.version);
  console.log('Live Build Number:', versionData.channels.stable.build_number);
  console.log('Live Android APK SHA-256 in manifest:', versionData.channels.stable.platforms.android.sha256);
  console.log('Live Windows ZIP SHA-256 in manifest:', versionData.channels.stable.platforms.windows.sha256);

  // 2. Release Manifest JSON
  const mRes = await fetch('https://ankitcodes30.github.io/Orvia/release_manifest.json');
  console.log('release_manifest.json HTTP Status:', mRes.statusCode);

  // 3. Playlist route
  const pRes = await fetch('https://ankitcodes30.github.io/Orvia/playlist/');
  console.log('playlist/ HTTP Status:', pRes.statusCode);
  const pBody = pRes.body.toString('utf8');
  console.log('Playlist page contains Orvia:', pBody.includes('Orvia'));

  // 4. Android APK download
  console.log('Fetching live APK...');
  const apkRes = await fetch('https://ankitcodes30.github.io/Orvia/downloads/app-release.apk');
  console.log('APK HTTP Status:', apkRes.statusCode);
  console.log('APK Content Length:', apkRes.body.length);
  const apkHash = crypto.createHash('sha256').update(apkRes.body).digest('hex');
  console.log('APK Downloaded SHA-256:', apkHash);
  const expectedApkHash = '9ff945659ff1ce305aaee3ea1ff435d576bf601d6a0af2081258d6d69ae7525f';
  console.log('APK Hash Matches:', apkHash === expectedApkHash ? 'MATCH (PASS)' : 'MISMATCH (FAIL)');

  // 5. Windows ZIP download
  console.log('Fetching live Windows ZIP...');
  const winRes = await fetch('https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip');
  console.log('Windows ZIP HTTP Status:', winRes.statusCode);
  console.log('Windows ZIP Content Length:', winRes.body.length);
  const winHash = crypto.createHash('sha256').update(winRes.body).digest('hex');
  console.log('Windows ZIP Downloaded SHA-256:', winHash);
  const expectedWinHash = '63e2bea931b56752535baf3312c96640098484bc3c5a3e5b8daac74fd34989ce';
  console.log('Windows ZIP Hash Matches:', winHash === expectedWinHash ? 'MATCH (PASS)' : 'MISMATCH (FAIL)');
}

verify().catch(e => {
  console.error('Verification error:', e);
  process.exit(1);
});
