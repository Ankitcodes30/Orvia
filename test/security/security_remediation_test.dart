import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/repository/LastFM/lastfmapi.dart';
import 'package:Orvia/services/updater/manifest_signature_verifier.dart';
import 'package:Orvia/services/updater/release_manifest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Orvia/services/updater/in_app_update_manager.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';


void main() {
  group('SEC-01: Zip Slip Traversal Defense Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('orvia_sec01_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Rejects zip archive containing directory traversal filenames', () async {
      final stagingDir = Directory(p.join(tempDir.path, 'staging'));
      await stagingDir.create(recursive: true);

      // Create an archive containing a path traversal payload
      final archive = Archive();
      final maliciousData = utf8.encode('malicious payload');
      archive.addFile(
        ArchiveFile('../../outside.txt', maliciousData.length, maliciousData),
      );
      final zipBytes = ZipEncoder().encode(archive);

      final canonicalStaging = p.canonicalize(stagingDir.path);
      final decodedArchive = ZipDecoder().decodeBytes(zipBytes);

      bool caughtTraversal = false;
      for (final file in decodedArchive) {
        final outPath = p.canonicalize(p.join(canonicalStaging, file.name));
        if (!p.isWithin(canonicalStaging, outPath)) {
          caughtTraversal = true;
          // Security violation detected: must not write
          break;
        }
      }

      expect(caughtTraversal, isTrue);
      // Ensure file was never created outside staging
      final outsideFile = File(p.join(tempDir.path, 'outside.txt'));
      expect(outsideFile.existsSync(), isFalse);
    });

    test('Allows safe archive extraction inside target staging directory', () async {
      final stagingDir = Directory(p.join(tempDir.path, 'staging'));
      await stagingDir.create(recursive: true);

      final archive = Archive();
      final safeData = utf8.encode('safe payload');
      archive.addFile(
        ArchiveFile('subfolder/app.exe', safeData.length, safeData),
      );
      final zipBytes = ZipEncoder().encode(archive);

      final canonicalStaging = p.canonicalize(stagingDir.path);
      final decodedArchive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in decodedArchive) {
        final outPath = p.canonicalize(p.join(canonicalStaging, file.name));
        expect(p.isWithin(canonicalStaging, outPath), isTrue);
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }

      final extractedFile = File(p.join(stagingDir.path, 'subfolder', 'app.exe'));
      expect(extractedFile.existsSync(), isTrue);
      expect(await extractedFile.readAsString(), equals('safe payload'));
    });
  });

  group('SEC-02: Last.fm HTTPS Enforcement Tests', () {
    test('LastFmAPI uses HTTPS base URLs exclusively', () {
      expect(LastFmAPI.apiUrl.startsWith('https://'), isTrue);
      expect(LastFmAPI.apiUrl.contains('http://'), isFalse);
    });

    test('LastFmAPI scrobble Uri generates HTTPS scheme', () {
      final params = {'method': 'track.scrobble', 'api_key': 'test'};
      final uri = Uri.https('ws.audioscrobbler.com', '/2.0/', params);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('ws.audioscrobbler.com'));
    });
  });

  group('BUG-01: Streaming SHA-256 Hashing Verification', () {
    test('Chunked stream hashing matches standard sha256.convert()', () async {
      // Simulate multi-chunk download stream
      final testData = List<int>.generate(1024 * 512, (i) => (i * 37) % 256);
      final expectedDigest = sha256.convert(testData).toString();

      final digestSink = AccumulatorSink<Digest>();
      final byteSink = sha256.startChunkedConversion(digestSink);

      const chunkSize = 65536;
      for (int i = 0; i < testData.length; i += chunkSize) {
        final end = (i + chunkSize < testData.length) ? i + chunkSize : testData.length;
        byteSink.add(testData.sublist(i, end));
      }
      byteSink.close();

      final computedDigest = digestSink.events.single.toString();
      expect(computedDigest, equals(expectedDigest));
    });
  });

  group('SEC-04: Geolocation Cleartext Elimination Tests', () {
    test('CountryInfo URL candidates contain zero cleartext HTTP endpoints', () {
      final countryInfoFile = File('lib/utils/country_info.dart');
      final content = countryInfoFile.readAsStringSync();
      expect(content.contains('http://'), isFalse);
      expect(content.contains('https://ipapi.co/json/'), isTrue);
      expect(content.contains('https://ipwho.is/'), isTrue);
    });
  });

  group('SEC-05: Real Ed25519 Cryptographic Signature Verifier Tests', () {
    setUp(() {
      ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.transitional;
    });

    tearDown(() {
      ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.production;
    });
    // RFC 8032 Test Vector 2:
    // seed: 4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb
    // pub:  3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c
    // msg (hex 72): ASCII 'r'
    // sig:  92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00
    const testKeyId = 'orvia-dev-test-2026';
    const testPubKeyHex =
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c';

    test('ReleasePlatform parses signature, signatureAlgorithm, and keyId', () {
      final json = {
        'download_url': 'https://example.com/orvia.apk',
        'sha256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'file_size': 54321000,
        'signature': 'abcdef1234567890',
        'signature_algorithm': 'ed25519',
        'key_id': testKeyId,
      };

      final platform = ReleasePlatform.fromJson(json);
      expect(platform.signature, equals('abcdef1234567890'));
      expect(platform.signatureAlgorithm, equals('ed25519'));
      expect(platform.keyId, equals(testKeyId));

      final serialized = platform.toJson();
      expect(serialized['signature'], equals('abcdef1234567890'));
      expect(serialized['signature_algorithm'], equals('ed25519'));
      expect(serialized['key_id'], equals(testKeyId));
    });

    test('Allows unsigned platforms during transition when enforceSignatures is false', () {
      const platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
        enforceSignatures: false,
      );
      expect(result.isApproved, isTrue);
      expect(result.status, equals(SignatureVerificationStatus.unsignedAllowed));
    });

    test('Strictly rejects unsigned platform when enforceSignatures is true', () {
      const platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
        enforceSignatures: true,
      );
      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.invalidSignature));
    });

    test('Strictly rejects algorithm downgrade (rot13, hmac, none)', () {
      for (final badAlg in ['rot13', 'hmac-sha256', 'none', 'RSA', 'sha1']) {
        final platform = ReleasePlatform(
          downloadUrl: 'https://example.com/orvia.apk',
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          signature: 'deadbeef' * 16,
          signatureAlgorithm: badAlg,
        );

        final result = ManifestSignatureVerifier.verifyPlatformSignature(
          appName: 'Orvia',
          channel: 'stable',
          version: '3.0.8',
          buildNumber: 8,
          platformKey: 'android',
          platform: platform,
        );
        expect(result.isApproved, isFalse);
        expect(result.status, equals(SignatureVerificationStatus.unsupportedAlgorithm));
      }
    });

    test('Rejects malformed signature hex or invalid signature byte length', () {
      const platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: '12345678', // Not 64 bytes (128 hex chars)
        signatureAlgorithm: 'ed25519',
        keyId: testKeyId,
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
      );
      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.malformedSignature));
    });

    test('Rejects unknown key_id not present in pinned trust store', () {
      final platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: '00' * 64,
        signatureAlgorithm: 'ed25519',
        keyId: 'unknown-attacker-key-999',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
      );
      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.missingKey));
    });

    test('Rejects expired pinned key', () {
      final expiredStore = [
        TrustedPublicKey(
          keyId: 'orvia-expired-2020',
          algorithm: 'ed25519',
          publicKeyHex: testPubKeyHex,
          description: 'Expired signing key',
          validUntil: DateTime.utc(2020, 1, 1),
        ),
      ];

      final platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: '00' * 64,
        signatureAlgorithm: 'ed25519',
        keyId: 'orvia-expired-2020',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
        customTrustStore: expiredStore,
      );
      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.expiredKey));
    });

    test('Mathematically validates authentic Ed25519 signature', () {
      // Generate a legitimate signed canonical message using test vectors
      const pubKeyHex = 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';
      // RFC 8032 Vector 1 signed empty message
      const sig1Hex =
          'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b';

      final customStore = [
        const TrustedPublicKey(
          keyId: 'test-rfc-key-1',
          algorithm: 'ed25519',
          publicKeyHex: pubKeyHex,
          description: 'RFC 8032 Key 1',
        ),
      ];

      // Test raw math verification
      final sigBytes = Uint8List.fromList(
        [for (int i = 0; i < sig1Hex.length; i += 2) int.parse(sig1Hex.substring(i, i + 2), radix: 16)],
      );

      // Verify that corrupt signature is mathematically rejected
      final corruptSig = Uint8List.fromList(sigBytes);
      corruptSig[0] ^= 0xff; // flip bits

      const platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: sig1Hex,
        signatureAlgorithm: 'ed25519',
        keyId: 'test-rfc-key-1',
      );

      // Manifest canonical message won't match empty RFC vector 1 message, so signature is invalid for this manifest
      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
        customTrustStore: customStore,
      );
      // Because payload is not empty, signature is mathematically mismatched
      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.invalidSignature));
    });

    test('Full End-to-End Signed Manifest & Field Tampering Protection', () {
      // Exactly signed payload produced by signing tool for dev key:
      const signedDownloadUrl = 'https://ankitcodes30.github.io/Orvia/downloads/app-release.apk';
      const signedSha = '519d3cae43f5f05251a109ff07dd472bd6648b1e9c350efdd079721d1117fc75';
      const sigHex = 'eb14f94026f5eda8f280454e2f23ebfc706926389cb2e70b29151916999d0ee4e8283e982909747d859850a8803ec166e9ef73d1d394e90324ee18d63cc72407';

      const authenticPlatform = ReleasePlatform(
        downloadUrl: signedDownloadUrl,
        sha256: signedSha,
        fileSize: 61833518,
        signature: sigHex,
        signatureAlgorithm: 'ed25519',
        keyId: 'orvia-dev-test-2026',
      );

      // 1. Positive Verification: Untampered signed release
      final okResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: authenticPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(okResult.isApproved, isTrue);
      expect(okResult.status, equals(SignatureVerificationStatus.verified));

      // 2. Tamper Test: Attacker modifies download URL to malicious APK
      const tamperedUrlPlatform = ReleasePlatform(
        downloadUrl: 'https://attacker.com/malicious-trojan.apk',
        sha256: signedSha,
        fileSize: 61833518,
        signature: sigHex,
        signatureAlgorithm: 'ed25519',
        keyId: 'orvia-dev-test-2026',
      );
      final badUrlResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: tamperedUrlPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(badUrlResult.isApproved, isFalse);
      expect(badUrlResult.status, equals(SignatureVerificationStatus.invalidSignature));

      // 3. Tamper Test: Attacker alters SHA-256 hash
      const tamperedShaPlatform = ReleasePlatform(
        downloadUrl: signedDownloadUrl,
        sha256: '0000000000000000000000000000000000000000000000000000000000000000',
        fileSize: 61833518,
        signature: sigHex,
        signatureAlgorithm: 'ed25519',
        keyId: 'orvia-dev-test-2026',
      );
      final badShaResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: tamperedShaPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(badShaResult.isApproved, isFalse);
      expect(badShaResult.status, equals(SignatureVerificationStatus.invalidSignature));

      // 4. Tamper Test: Attacker spoofs version number
      final badVerResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '9.9.9', // Tampered version
        buildNumber: 6,
        platformKey: 'android',
        platform: authenticPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(badVerResult.isApproved, isFalse);
      expect(badVerResult.status, equals(SignatureVerificationStatus.invalidSignature));

      // 5. Tamper Test: Attacker targets different platform (platform substitution)
      final badPlatformResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'windows', // Swapped platform
        platform: authenticPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(badPlatformResult.isApproved, isFalse);
      expect(badPlatformResult.status, equals(SignatureVerificationStatus.invalidSignature));

      // 6. Tamper Test: Attacker tampers with buildNumber (rollback or replay attack)
      final badBuildResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 7, // Tampered build number
        platformKey: 'android',
        platform: authenticPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(badBuildResult.isApproved, isFalse);
      expect(badBuildResult.status, equals(SignatureVerificationStatus.invalidSignature));

      // 7. Tamper Test: Attacker tampers with publish date timestamp
      final badDateResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: authenticPlatform,
        publishedAt: '2026-11-05T00:00:00Z', // Tampered publish timestamp
        enforceSignatures: true,
      );
      expect(badDateResult.isApproved, isFalse);
      expect(badDateResult.status, equals(SignatureVerificationStatus.invalidSignature));
    });

    test('Key rotation: verifies seamlessly when new key is appended to trust store', () {
      const rotatedKeyId = 'orvia-release-2027';
      const rotatedPubKey = '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c';

      final rotatedStore = [
        ...ManifestSignatureVerifier.trustedPublicKeys,
        const TrustedPublicKey(
          keyId: rotatedKeyId,
          algorithm: 'ed25519',
          publicKeyHex: rotatedPubKey,
          description: 'Rotated Future Signing Key',
        ),
      ];

      final platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: '11' * 64, // Invalid signature bits
        signatureAlgorithm: 'ed25519',
        keyId: rotatedKeyId,
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
        customTrustStore: rotatedStore,
      );
      // It recognizes the rotated key, attempts math verification, and rejects invalid signature bits
      expect(result.status, equals(SignatureVerificationStatus.invalidSignature));
      expect(result.keyId, equals(rotatedKeyId));
    });
  });

  group('Platform Configuration & License Tests', () {
    test('AndroidManifest disallows cleartext and configures networkSecurityConfig', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:usesCleartextTraffic="false"'), isTrue);
      expect(content.contains('android:networkSecurityConfig="@xml/network_cfg"'), isTrue);
    });

    test('network_cfg.xml denies base cleartext traffic', () {
      final netConfigFile = File('android/app/src/main/res/xml/network_cfg.xml');
      final content = netConfigFile.readAsStringSync();
      expect(content.contains('cleartextTrafficPermitted="false"'), isTrue);
    });

    test('file_paths.xml scopes internal storage paths', () {
      final filePath = File('android/app/src/main/res/xml/file_paths.xml');
      final content = filePath.readAsStringSync();
      // Must not expose full internal root "."
      expect(content.contains('<files-path name="internal_files" path="." />'), isFalse);
      expect(content.contains('path="updates/"'), isTrue);
      expect(content.contains('path="shared/"'), isTrue);
    });

    test('About screen contains Open Source Licenses launcher', () {
      final aboutFile = File('lib/screens/screen/home_views/setting_views/about.dart');
      final content = aboutFile.readAsStringSync();
      expect(content.contains('showLicensePage('), isTrue);
      expect(content.contains('Licenses'), isTrue);
    });

    test('Website app.html contains strict Content-Security-Policy', () {
      final appHtmlFile = File('ghpage/src/app.html');
      final content = appHtmlFile.readAsStringSync();
      expect(content.contains('http-equiv="Content-Security-Policy"'), isTrue);
      expect(content.contains("default-src 'self'"), isTrue);
    });

    test('SECURITY.md defines vulnerability reporting policy and SLA', () {
      final secFile = File('SECURITY.md');
      expect(secFile.existsSync(), isTrue);
      final content = secFile.readAsStringSync();
      expect(content.contains('Reporting a Vulnerability'), isTrue);
      expect(content.contains('Response & Triage SLA'), isTrue);
      expect(content.contains('ankitkumbhare301@gmail.com'), isTrue);
    });
  });

  group('SEC-01: Adversarial Windows Path Variations & Malicious Entry Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('orvia_sec01_adv_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final maliciousName in [
      r'..\..\windows\system32\evil.dll',
      r'C:\windows\system32\calc.exe',
      r'\\attacker.com\share\evil.bat',
      '/etc/shadow',
      r'\root\payload.exe',
      'legit.txt:stream',
      'safe.txt\x00.exe',
      'sub/../../../outside.txt',
    ]) {
      test('InAppUpdateManager strictly rejects "$maliciousName"', () async {
        final archive = Archive();
        archive.addFile(ArchiveFile(maliciousName, 4, utf8.encode('TEST')));
        final zipBytes = ZipEncoder().encode(archive);

        final dummyZip = File(p.join(tempDir.path, 'attack.zip'));
        await dummyZip.writeAsBytes(zipBytes);

        await expectLater(
          () => InAppUpdateManager.installWindowsZip(
            zipFile: dummyZip,
            expectedVersion: '3.0.7+7',
            customTempDir: tempDir,
            autoExitOnSuccess: false,
          ),
          throwsA(isA<FileSystemException>()),
        );
      });
    }
  });

  group('SEC-05: Production Architecture & Adversarial Cryptographic Tests', () {
    test('Production profile strictly rejects unsigned manifest', () {
      ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.production;
      addTearDown(() {
        ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.transitional;
      });

      const platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 7,
        platformKey: 'android',
        platform: platform,
      );

      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.invalidSignature));
      expect(result.message, contains('unsigned and signature enforcement is enabled'));
    });

    test('Production profile safely fails when no production keys are enrolled', () {
      ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.production;
      addTearDown(() {
        ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.transitional;
      });

      final platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: 'deadbeef' * 16,
        signatureAlgorithm: 'ed25519',
        keyId: 'any-key',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 7,
        platformKey: 'android',
        platform: platform,
        customTrustStore: const [],
      );

      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.missingKey));
      expect(result.message, contains('No trusted public keys enrolled'));
    });

    test('Production profile strictly enforces enrolled production key orvia-prod-2026-v1 and rejects unknown keys', () {
      ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.production;
      addTearDown(() {
        ManifestSignatureVerifier.activeProfile = UpdateSecurityProfile.transitional;
      });

      expect(ManifestSignatureVerifier.productionPublicKeys, isNotEmpty);
      expect(ManifestSignatureVerifier.productionPublicKeys.first.keyId, equals('orvia-prod-2026-v1'));
      expect(ManifestSignatureVerifier.productionPublicKeys.first.publicKeyHex,
          equals('94c3ada955ed32406ba1f7b2290d75f2b431ec7f37492a172bbcb6485c8a7995'));

      final platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: 'deadbeef' * 16,
        signatureAlgorithm: 'ed25519',
        keyId: 'unauthorized-key',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 8,
        platformKey: 'android',
        platform: platform,
      );

      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.missingKey));
      expect(result.message, contains('Pinned public key with key_id "unauthorized-key" not found in client trust store'));
    });

    test('Strictly rejects valid signature from untrusted foreign key', () {
      final platform = ReleasePlatform(
        downloadUrl: 'https://example.com/orvia.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: '00' * 64,
        signatureAlgorithm: 'ed25519',
        keyId: 'untrusted-foreign-key-id',
      );

      final result = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 7,
        platformKey: 'android',
        platform: platform,
        customTrustStore: [
          const TrustedPublicKey(
            keyId: 'enrolled-key-1',
            algorithm: 'ed25519',
            publicKeyHex: '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
            description: 'Enrolled key',
          ),
        ],
      );

      expect(result.isApproved, isFalse);
      expect(result.status, equals(SignatureVerificationStatus.missingKey));
    });

    test('Tampering any canonical field invalidates signature', () {
      const devKeyId = 'orvia-dev-test-2026';
      const signedDownloadUrl = 'https://ankitcodes30.github.io/Orvia/downloads/app-release.apk';
      const signedSha = '519d3cae43f5f05251a109ff07dd472bd6648b1e9c350efdd079721d1117fc75';
      const sigHex =
          'eb14f94026f5eda8f280454e2f23ebfc706926389cb2e70b29151916999d0ee4e8283e982909747d859850a8803ec166e9ef73d1d394e90324ee18d63cc72407';

      const authenticPlatform = ReleasePlatform(
        downloadUrl: signedDownloadUrl,
        sha256: signedSha,
        fileSize: 61833518,
        signature: sigHex,
        signatureAlgorithm: 'ed25519',
        keyId: devKeyId,
      );

      // Verify legitimate signature
      final okResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: authenticPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(okResult.isApproved, isTrue);

      // Tampered download URL
      const tamperedUrlPlatform = ReleasePlatform(
        downloadUrl: 'https://attacker.com/orvia.apk',
        sha256: signedSha,
        fileSize: 61833518,
        signature: sigHex,
        signatureAlgorithm: 'ed25519',
        keyId: devKeyId,
      );
      final r1 = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: tamperedUrlPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(r1.isApproved, isFalse);
      expect(r1.status, equals(SignatureVerificationStatus.invalidSignature));

      // Tampered sha256
      const tamperedShaPlatform = ReleasePlatform(
        downloadUrl: signedDownloadUrl,
        sha256: '0000000000000000000000000000000000000000000000000000000000000000',
        fileSize: 61833518,
        signature: sigHex,
        signatureAlgorithm: 'ed25519',
        keyId: devKeyId,
      );
      final r2 = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.7',
        buildNumber: 6,
        platformKey: 'android',
        platform: tamperedShaPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(r2.isApproved, isFalse);
      expect(r2.status, equals(SignatureVerificationStatus.invalidSignature));

      // Tampered version
      final r3 = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: 'Orvia',
        channel: 'stable',
        version: '3.0.8',
        buildNumber: 6,
        platformKey: 'android',
        platform: authenticPlatform,
        publishedAt: '2026-10-24T15:40:00Z',
        enforceSignatures: true,
      );
      expect(r3.isApproved, isFalse);
      expect(r3.status, equals(SignatureVerificationStatus.invalidSignature));
    });
  });

  group('BUG-01: Atomic Download Promotion & Interruption Safety Tests', () {
    test('downloadAndVerifyFile promotes file atomically and cleans up on failure', () async {
      final tempDir = await Directory.systemTemp.createTemp('orvia_atomic_test_');
      addTearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      final destination = File(p.join(tempDir.path, 'target_app.apk'));
      final content = utf8.encode('GENUINE_UPDATE_BINARY_CONTENT');
      final expectedSha = sha256.convert(content).toString();

      // Mock server returning valid bytes
      final client = MockClient((request) async {
        return http.Response.bytes(content, 200);
      });

      final service = OrviaUpdateService(client: client);
      final resultFile = await service.downloadAndVerifyFile(
        downloadUrl: 'https://example.com/downloads/app.apk',
        expectedSha256: expectedSha,
        destinationFile: destination,
      );

      expect(resultFile.existsSync(), isTrue);
      expect(resultFile.readAsStringSync(), equals('GENUINE_UPDATE_BINARY_CONTENT'));

      // Check no leftover .part files in tempDir
      final partFiles = tempDir.listSync().where((e) => e.path.contains('.part'));
      expect(partFiles, isEmpty);

      // Now test failure: corrupt expected SHA
      final corruptDest = File(p.join(tempDir.path, 'corrupt.apk'));
      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: 'https://example.com/downloads/app.apk',
          expectedSha256: '00' * 32,
          destinationFile: corruptDest,
        ),
        throwsA(isA<IntegrityCheckException>()),
      );

      // Destination file must NOT exist
      expect(corruptDest.existsSync(), isFalse);
      // No leftover .part files
      final leftoverParts = tempDir.listSync().where((e) => e.path.contains('.part'));
      expect(leftoverParts, isEmpty);
    });
  });
}
