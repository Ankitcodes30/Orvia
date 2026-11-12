import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:Orvia/services/updater/release_manifest.dart';

/// Status of manifest/artifact digital signature verification.
enum SignatureVerificationStatus {
  verified,
  unsignedAllowed,
  invalidSignature,
  unsupportedAlgorithm,
  missingKey,
  expiredKey,
  malformedSignature,
}

/// Security enforcement profile for application updates.
enum UpdateSecurityProfile {
  /// Strict production profile: requires enrolled production keys and mandatory signatures.
  production,

  /// Transitional profile: verifies signatures when present, allows unsigned releases.
  transitional,

  /// Testing profile: uses isolated RFC 8032 test keys for unit and adversarial testing.
  testing,
}

/// Result of cryptographic signature check.
class SignatureVerificationResult {
  final SignatureVerificationStatus status;
  final String message;
  final String? keyId;

  const SignatureVerificationResult({
    required this.status,
    required this.message,
    this.keyId,
  });

  bool get isApproved =>
      status == SignatureVerificationStatus.verified ||
      status == SignatureVerificationStatus.unsignedAllowed;
}

/// Represents a pinned trusted public key for release validation.
class TrustedPublicKey {
  final String keyId;
  final String algorithm;
  final String publicKeyHex;
  final String description;
  final DateTime? validUntil;
  final bool isTestKey;

  const TrustedPublicKey({
    required this.keyId,
    required this.algorithm,
    required this.publicKeyHex,
    required this.description,
    this.validUntil,
    this.isTestKey = false,
  });

  bool get isExpired =>
      validUntil != null && DateTime.now().toUtc().isAfter(validUntil!);
}

/// Verifies asymmetric release signatures for update platform releases.
class ManifestSignatureVerifier {
  /// Global security policy profile.
  /// Set to [UpdateSecurityProfile.production] for production release.
  static UpdateSecurityProfile activeProfile = UpdateSecurityProfile.production;

  /// Production pinned public keys enrolled by the Release Authority.
  static final List<TrustedPublicKey> productionPublicKeys = [
    const TrustedPublicKey(
      keyId: 'orvia-prod-2026-v1',
      algorithm: 'ed25519',
      publicKeyHex:
          '94c3ada955ed32406ba1f7b2290d75f2b431ec7f37492a172bbcb6485c8a7995',
      description: 'Orvia Production Release Signing Key (Enrolled 2026)',
      validUntil: null,
      isTestKey: false,
    ),
  ];

  /// Isolated development & test vector keys (RFC 8032) for verification test suites.
  static final List<TrustedPublicKey> testPublicKeys = [
    const TrustedPublicKey(
      keyId: 'orvia-dev-test-2026',
      algorithm: 'ed25519',
      publicKeyHex:
          '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      description: 'Orvia Development & Test Verification Key (RFC 8032 Vector)',
      isTestKey: true,
    ),
  ];

  /// Active default trust store based on configured security profile.
  static List<TrustedPublicKey> get trustedPublicKeys {
    if (activeProfile == UpdateSecurityProfile.production) {
      return productionPublicKeys;
    }
    return [...productionPublicKeys, ...testPublicKeys];
  }

  /// Canonical serialization of platform release data for cryptographic signing.
  /// Binds application identity, channel, version, build, platform, sha256, url, size, and date.
  static String canonicalPlatformPayload({
    required String appName,
    required String channel,
    required String version,
    required int buildNumber,
    required String platformKey,
    required ReleasePlatform platform,
    String? publishedAt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('ORVIA-MANIFEST-V1');
    buffer.writeln('app:$appName');
    buffer.writeln('channel:$channel');
    buffer.writeln('version:$version');
    buffer.writeln('build:$buildNumber');
    buffer.writeln('platform:$platformKey');
    buffer.writeln('sha256:${platform.sha256.trim().toLowerCase()}');
    buffer.writeln('url:${platform.downloadUrl.trim()}');
    if (platform.fileSize != null) {
      buffer.writeln('size:${platform.fileSize}');
    }
    if (publishedAt != null && publishedAt.trim().isNotEmpty) {
      buffer.writeln('published:${publishedAt.trim()}');
    }
    return buffer.toString().trimRight();
  }

  /// Evaluates and mathematically verifies the digital signature of a platform release.
  /// - If [enforceSignatures] is true (or [activeProfile] is production), unsigned manifests are strictly rejected.
  /// - If a signature is present, it is rigorously verified mathematically regardless of [enforceSignatures].
  static SignatureVerificationResult verifyPlatformSignature({
    required String appName,
    required String channel,
    required String version,
    required int buildNumber,
    required String platformKey,
    required ReleasePlatform platform,
    String? publishedAt,
    bool enforceSignatures = false,
    List<TrustedPublicKey>? customTrustStore,
  }) {
    final effectiveEnforce =
        enforceSignatures || activeProfile == UpdateSecurityProfile.production;
    final signatureHex = platform.signature?.trim();
    final algorithm =
        platform.signatureAlgorithm?.trim().toLowerCase() ?? 'ed25519';
    final requestedKeyId = platform.keyId?.trim();
    final trustStore = customTrustStore ?? trustedPublicKeys;

    // 1. Unsigned release handling
    if (signatureHex == null || signatureHex.isEmpty) {
      if (effectiveEnforce) {
        return const SignatureVerificationResult(
          status: SignatureVerificationStatus.invalidSignature,
          message:
              'Security Exception: Update release is unsigned and signature enforcement is enabled.',
        );
      }
      return const SignatureVerificationResult(
        status: SignatureVerificationStatus.unsignedAllowed,
        message:
            'Update package is unsigned (allowed under transitional compatibility policy).',
      );
    }

    // 2. Strict algorithm validation (prevent algorithm downgrade attacks)
    if (algorithm != 'ed25519') {
      return SignatureVerificationResult(
        status: SignatureVerificationStatus.unsupportedAlgorithm,
        message:
            'Security Exception: Unsupported signature algorithm "$algorithm". Only "ed25519" is permitted.',
      );
    }

    // 3. Locate matching pinned public key
    if (trustStore.isEmpty) {
      return const SignatureVerificationResult(
        status: SignatureVerificationStatus.missingKey,
        message:
            'Security Exception: No trusted public keys enrolled in trust store to verify release.',
      );
    }

    TrustedPublicKey? matchedKey;

    if (requestedKeyId != null && requestedKeyId.isNotEmpty) {
      for (final key in trustStore) {
        if (key.keyId == requestedKeyId && key.algorithm == 'ed25519') {
          matchedKey = key;
          break;
        }
      }
      if (matchedKey == null) {
        return SignatureVerificationResult(
          status: SignatureVerificationStatus.missingKey,
          message:
              'Security Exception: Pinned public key with key_id "$requestedKeyId" not found in client trust store.',
          keyId: requestedKeyId,
        );
      }
    } else {
      // If no keyId is explicitly requested, search for any matching ed25519 key
      matchedKey = trustStore.firstWhere(
        (k) => k.algorithm == 'ed25519',
        orElse: () => trustStore.first,
      );
    }

    if (matchedKey.isExpired) {
      return SignatureVerificationResult(
        status: SignatureVerificationStatus.expiredKey,
        message:
            'Security Exception: Pinned signing key "${matchedKey.keyId}" expired on ${matchedKey.validUntil}.',
        keyId: matchedKey.keyId,
      );
    }

    // 4. Hex decoding of signature and public key
    Uint8List signatureBytes;
    Uint8List publicKeyBytes;
    try {
      signatureBytes = _hexDecode(signatureHex);
      if (signatureBytes.length != 64) {
        return SignatureVerificationResult(
          status: SignatureVerificationStatus.malformedSignature,
          message:
              'Security Exception: Ed25519 signature must be exactly 64 bytes (got ${signatureBytes.length}).',
          keyId: matchedKey.keyId,
        );
      }
    } catch (e) {
      return SignatureVerificationResult(
        status: SignatureVerificationStatus.malformedSignature,
        message: 'Security Exception: Failed to decode signature hex: $e',
        keyId: matchedKey.keyId,
      );
    }

    try {
      publicKeyBytes = _hexDecode(matchedKey.publicKeyHex);
      if (publicKeyBytes.length != 32) {
        return SignatureVerificationResult(
          status: SignatureVerificationStatus.missingKey,
          message:
              'Security Exception: Pinned public key must be exactly 32 bytes.',
          keyId: matchedKey.keyId,
        );
      }
    } catch (e) {
      return SignatureVerificationResult(
        status: SignatureVerificationStatus.missingKey,
        message: 'Security Exception: Failed to decode public key hex: $e',
        keyId: matchedKey.keyId,
      );
    }

    // 5. Construct canonical message bytes
    final canonicalMessage = canonicalPlatformPayload(
      appName: appName,
      channel: channel,
      version: version,
      buildNumber: buildNumber,
      platformKey: platformKey,
      platform: platform,
      publishedAt: publishedAt,
    );
    final messageBytes = Uint8List.fromList(utf8.encode(canonicalMessage));

    // 6. Mathematical verification of Ed25519 signature (RFC 8032)
    final isValid = _ed25519Verify(
      publicKeyBytes: publicKeyBytes,
      messageBytes: messageBytes,
      signatureBytes: signatureBytes,
    );

    if (!isValid) {
      return SignatureVerificationResult(
        status: SignatureVerificationStatus.invalidSignature,
        message:
            'Security Exception: Cryptographic signature mismatch! Manifest payload was altered or signature is invalid.',
        keyId: matchedKey.keyId,
      );
    }

    log(
      'Release signature successfully verified with key "${matchedKey.keyId}"',
      name: 'ManifestSignatureVerifier',
    );

    return SignatureVerificationResult(
      status: SignatureVerificationStatus.verified,
      message:
          'Signature successfully verified mathematically against trusted public key "${matchedKey.keyId}".',
      keyId: matchedKey.keyId,
    );
  }

  // ---------------------------------------------------------------------------
  // RFC 8032 Pure Dart Ed25519 Signature Verification Implementation
  // ---------------------------------------------------------------------------

  static final BigInt _q = (BigInt.one << 255) - BigInt.from(19);
  static final BigInt _l = (BigInt.one << 252) +
      BigInt.parse('27742317777372353535851937790883648493');
  static final BigInt _d =
      (-BigInt.from(121665) * _inv(BigInt.from(121666))) % _q;
  static final BigInt _i =
      _modPow(BigInt.from(2), (_q - BigInt.one) ~/ BigInt.from(4), _q);

  static BigInt _inv(BigInt x) => _modPow(x, _q - BigInt.two, _q);

  static BigInt _modPow(BigInt base, BigInt exp, BigInt mod) {
    var res = BigInt.one;
    var b = base % mod;
    var e = exp;
    while (e > BigInt.zero) {
      if (e.isOdd) res = (res * b) % mod;
      e >>= 1;
      b = (b * b) % mod;
    }
    return res;
  }

  static final BigInt _by = (BigInt.from(4) * _inv(BigInt.from(5))) % _q;
  static final BigInt _bx = _recoverX(_by, false);
  static final _EdPoint _basePoint =
      _EdPoint(_bx, _by, BigInt.one, (_bx * _by) % _q);

  static BigInt _recoverX(BigInt y, bool sign) {
    if (y >= _q) throw ArgumentError('y >= q');
    final xx = ((y * y - BigInt.one) * _inv(_d * y * y + BigInt.one)) % _q;
    if (xx == BigInt.zero) {
      if (sign) throw ArgumentError('invalid zero x sign');
      return BigInt.zero;
    }
    var x = _modPow(xx, (_q + BigInt.from(3)) ~/ BigInt.from(8), _q);
    if ((x * x - xx) % _q != BigInt.zero) {
      x = (x * _i) % _q;
    }
    if ((x * x - xx) % _q != BigInt.zero) throw ArgumentError('not a square');
    if (x.isOdd != sign) x = (-x) % _q;
    return (x % _q + _q) % _q;
  }

  static _EdPoint _pointAdd(_EdPoint p, _EdPoint q) {
    final a = ((p.y - p.x) * (q.y - q.x)) % _q;
    final b = ((p.y + p.x) * (q.y + q.x)) % _q;
    final c = (BigInt.two * p.t * q.t * _d) % _q;
    final d = (BigInt.two * p.z * q.z) % _q;
    final e = (b - a) % _q;
    final f = (d - c) % _q;
    final g = (d + c) % _q;
    final h = (b + a) % _q;
    return _EdPoint(
      (e * f) % _q,
      (h * g) % _q,
      (g * f) % _q,
      (e * h) % _q,
    );
  }

  static _EdPoint _pointMul(_EdPoint p, BigInt scalar) {
    var res = _EdPoint.zero;
    var temp = p;
    var s = scalar;
    while (s > BigInt.zero) {
      if (s.isOdd) res = _pointAdd(res, temp);
      s >>= 1;
      temp = _pointAdd(temp, temp);
    }
    return res;
  }

  static _EdPoint _decodePoint(Uint8List bytes) {
    if (bytes.length != 32) throw ArgumentError('Invalid point length');
    final sign = (bytes[31] & 0x80) != 0;
    final yBytes = Uint8List.fromList(bytes);
    yBytes[31] &= 0x7f;
    var y = BigInt.zero;
    for (int i = 31; i >= 0; i--) {
      y = (y << 8) | BigInt.from(yBytes[i]);
    }
    final x = _recoverX(y, sign);
    return _EdPoint(x, y, BigInt.one, (x * y) % _q);
  }

  static BigInt _decodeScalar(Uint8List bytes) {
    var s = BigInt.zero;
    for (int i = bytes.length - 1; i >= 0; i--) {
      s = (s << 8) | BigInt.from(bytes[i]);
    }
    return s;
  }

  static bool _ed25519Verify({
    required Uint8List publicKeyBytes,
    required Uint8List messageBytes,
    required Uint8List signatureBytes,
  }) {
    if (publicKeyBytes.length != 32 || signatureBytes.length != 64) return false;
    try {
      final aPoint = _decodePoint(publicKeyBytes);
      final rBytes = signatureBytes.sublist(0, 32);
      final sBytes = signatureBytes.sublist(32, 64);
      final s = _decodeScalar(sBytes);
      if (s >= _l) return false; // S must be strictly less than order l

      final hashInput = Uint8List(32 + 32 + messageBytes.length);
      hashInput.setAll(0, rBytes);
      hashInput.setAll(32, publicKeyBytes);
      hashInput.setAll(64, messageBytes);

      final digest = sha512.convert(hashInput).bytes;
      final k = _decodeScalar(Uint8List.fromList(digest)) % _l;

      final rPoint = _decodePoint(rBytes);

      final sb = _pointMul(_basePoint, s);
      final ka = _pointMul(aPoint, k);
      final rka = _pointAdd(rPoint, ka);

      final x1 = (sb.x * rka.z) % _q;
      final x2 = (rka.x * sb.z) % _q;
      final y1 = (sb.y * rka.z) % _q;
      final y2 = (rka.y * sb.z) % _q;

      return (x1 - x2) % _q == BigInt.zero && (y1 - y2) % _q == BigInt.zero;
    } catch (_) {
      return false;
    }
  }

  static Uint8List _hexDecode(String hex) {
    final clean = hex.replaceAll(' ', '').trim();
    if (clean.length % 2 != 0) throw const FormatException('Invalid hex length');
    final result = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}

class _EdPoint {
  final BigInt x, y, z, t;
  const _EdPoint(this.x, this.y, this.z, this.t);
  static final _EdPoint zero =
      _EdPoint(BigInt.zero, BigInt.one, BigInt.one, BigInt.zero);
}
