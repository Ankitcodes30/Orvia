/// Represents a semantic version adhering to the Semantic Versioning 2.0.0 specification,
/// with explicit support for Android / application build numbers (versionCode).
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final int buildNumber;
  final String? buildMetadata;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.buildNumber = 0,
    this.buildMetadata,
  });

  /// Parse a version string such as:
  /// - "3.0.4"
  /// - "v3.0.4+1"
  /// - "2.11.6+171"
  /// - "v3.1.0-preview.1+2"
  /// - "v3.1.0-beta.2"
  ///
  /// Rejects malformed versions safely (returns null) if:
  /// - The string is empty or contains non-numeric segments in major/minor/patch
  /// - Segments contain negative numbers or empty components (e.g. "3..4")
  /// - More than 3 segments are present in version core (e.g. "3.0.4.1")
  /// - Pre-release identifiers contain invalid characters
  static AppVersion? tryParse(String versionStr, [String? explicitBuildStr]) {
    String trimmed = versionStr.trim();
    if (trimmed.isEmpty) return null;

    // Strip optional leading 'v' or 'V'
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      trimmed = trimmed.substring(1).trim();
      if (trimmed.isEmpty) return null;
    }

    // 1. Separate build metadata (separated by '+')
    String? rawBuildMetadata;
    int parsedBuildNumber = 0;

    if (trimmed.contains('+')) {
      final plusIndex = trimmed.indexOf('+');
      rawBuildMetadata = trimmed.substring(plusIndex + 1).trim();
      trimmed = trimmed.substring(0, plusIndex).trim();
      if (rawBuildMetadata.isEmpty) return null;

      // Extract leading integer from build metadata if present
      final match = RegExp(r'^(\d+)').firstMatch(rawBuildMetadata);
      if (match != null) {
        parsedBuildNumber = int.tryParse(match.group(1)!) ?? 0;
      }
    }

    // Explicit build parameter (e.g. from PackageInfo.buildNumber) overrides inline if valid
    if (explicitBuildStr != null && explicitBuildStr.trim().isNotEmpty) {
      final explicitParsed = int.tryParse(explicitBuildStr.trim());
      if (explicitParsed != null && explicitParsed >= 0) {
        parsedBuildNumber = explicitParsed;
      }
    }

    // 2. Separate pre-release tag (separated by '-')
    String? preReleaseTag;
    if (trimmed.contains('-')) {
      final dashIndex = trimmed.indexOf('-');
      preReleaseTag = trimmed.substring(dashIndex + 1).trim();
      trimmed = trimmed.substring(0, dashIndex).trim();

      if (preReleaseTag.isEmpty) return null;

      // Validate each dot-separated identifier in pre-release tag
      final preIdentifiers = preReleaseTag.split('.');
      for (final id in preIdentifiers) {
        if (id.isEmpty) return null; // Empty identifier like "alpha..1"
        if (!RegExp(r'^[0-9A-Za-z-]+$').hasMatch(id)) {
          return null; // Invalid characters in pre-release identifier
        }
      }
    }

    // 3. Parse core version numbers (major.minor.patch)
    final parts = trimmed.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    // Every segment must be strictly non-negative digits
    final digitRegex = RegExp(r'^\d+$');

    if (!digitRegex.hasMatch(parts[0])) return null;
    final major = int.tryParse(parts[0]);
    if (major == null || major < 0) return null;

    int minor = 0;
    if (parts.length > 1) {
      if (!digitRegex.hasMatch(parts[1])) return null;
      final m = int.tryParse(parts[1]);
      if (m == null || m < 0) return null;
      minor = m;
    }

    int patch = 0;
    if (parts.length > 2) {
      if (!digitRegex.hasMatch(parts[2])) return null;
      final p = int.tryParse(parts[2]);
      if (p == null || p < 0) return null;
      patch = p;
    }

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preReleaseTag,
      buildNumber: parsedBuildNumber,
      buildMetadata: rawBuildMetadata,
    );
  }

  /// Strictly compares version precedence according to SemVer 2.0.0 (Section 11).
  ///
  /// CRITICAL SEMVER SPECIFICATION RULE (Section 10):
  /// "Build metadata MUST be ignored when determining version precedence."
  /// Thus, versions that differ only in build metadata (e.g. 3.0.4+0 vs 3.0.4+1)
  /// have the exact same precedence and return 0.
  ///
  /// To compare application updates considering Android build numbers ([versionCode]),
  /// use [compareAppRelease].
  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // SemVer 2.0.0 rule: A normal release has higher precedence than a pre-release version
    // e.g. 1.0.0 > 1.0.0-alpha
    if (preRelease == null && other.preRelease != null) return 1;
    if (preRelease != null && other.preRelease == null) return -1;
    if (preRelease != null && other.preRelease != null) {
      return _comparePreRelease(preRelease!, other.preRelease!);
    }

    // Build metadata MUST NOT affect pure SemVer precedence
    return 0;
  }

  /// Compares application releases for in-app / Android update evaluation.
  ///
  /// 1. First evaluates pure SemVer precedence (major, minor, patch, pre-release).
  /// 2. If SemVer versions are equal and [checkBuildNumber] is true (default),
  ///    evaluates Android build numbers ([versionCode]).
  ///    e.g., v3.0.4+1 is an update over v3.0.4+0.
  int compareAppRelease(AppVersion other, {bool checkBuildNumber = true}) {
    final semVerCmp = compareTo(other);
    if (semVerCmp != 0) return semVerCmp;

    if (checkBuildNumber) {
      return buildNumber.compareTo(other.buildNumber);
    }
    return 0;
  }

  /// Whether this version represents a newer application update over [current].
  bool isAppUpdateOver(AppVersion current, {bool checkBuildNumber = true}) {
    return compareAppRelease(current, checkBuildNumber: checkBuildNumber) > 0;
  }

  /// Dot-separated pre-release comparison according to SemVer 2.0.0 Section 11:
  /// - Identifiers consisting of only digits are compared numerically.
  /// - Identifiers with letters or hyphens are compared lexically in ASCII sort order.
  /// - Numeric identifiers always have lower precedence than non-numeric identifiers.
  /// - A larger set of pre-release fields has higher precedence than a smaller set if previous fields are equal.
  static int _comparePreRelease(String a, String b) {
    final aParts = a.split('.');
    final bParts = b.split('.');
    final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;

    for (int i = 0; i < maxLen; i++) {
      if (i >= aParts.length) return -1; // a has fewer fields -> a < b
      if (i >= bParts.length) return 1;  // b has fewer fields -> a > b

      final aSub = aParts[i];
      final bSub = bParts[i];

      final aNum = int.tryParse(aSub);
      final bNum = int.tryParse(bSub);

      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else if (aNum != null && bNum == null) {
        // Numeric identifiers always have lower precedence than non-numeric
        return -1;
      } else if (aNum == null && bNum != null) {
        return 1;
      } else {
        final cmp = aSub.compareTo(bSub);
        if (cmp != 0) return cmp;
      }
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          preRelease == other.preRelease;

  @override
  int get hashCode =>
      major.hashCode ^
      minor.hashCode ^
      patch.hashCode ^
      (preRelease?.hashCode ?? 0);

  @override
  String toString() {
    final pre = preRelease != null ? '-$preRelease' : '';
    final meta = buildMetadata != null
        ? '+$buildMetadata'
        : (buildNumber > 0 ? '+$buildNumber' : '');
    return '$major.$minor.$patch$pre$meta';
  }
}
