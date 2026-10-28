/// Configuration constants for the cloud-sync subsystem.
///
/// Pure Dart — no Flutter, Firebase, or Isar imports — so that the merge
/// engine and its tests stay free of heavy dependencies.
library sync_config;

/// Schema version of the cloud document layout.
///
/// Bump when the cloud representation changes. Devices running an older
/// schema refuse to pull newer snapshots (see [MergeEngine]) and surface a
/// sync error instead of guessing at unknown fields.
const int kCloudSyncSchemaVersion = 1;

/// Well-known cloud document id used for the "Liked" playlist's favourites
/// bookkeeping. Favourites are synced through a dedicated collection rather
/// than as playlist entries, so this id is only referenced in documentation.
const String kLikedPlaylistName = 'Liked';

/// Settings keys that are safe and meaningful to synchronize.
///
/// Excluded on purpose (device-specific or environment-specific):
/// - `downloadPath`, `backupPath`   — absolute local file paths.
/// - `localMusicFolders`, `localMusicAutoScan`, `localMusicLastScan` — local FS.
/// - `lastQueueState`               — session resume state, per-device.
/// - All plugin-related ids (`homePluginId`, `searchPluginId`, …) — the
///   installed plugin set differs per device; a synced id pointing at a
///   missing plugin already degrades gracefully, but silently propagating
///   plugin selection across devices is more confusing than helpful in v1.
/// - `repositoriesBootstrapped`, `pluginRepositoryLastSync` — install state.
/// - `appSetupCompleted`, `readChangelogs` — per-device onboarding state.
/// - `autoBackup`, `lastBackupTimestamp` — local backup loop state.
const Set<String> kSyncableSettingKeys = {
  // ── Playback & media ──
  'streamQuality',
  'downloadQuality',
  'autoPlaySimilarItems',
  'autoResolveUnavailableTracks',
  'crossfadeDuration',
  // ── Equalizer ──
  'eqEnabled',
  'eqBandGains',
  'eqPreset',
  'eqSource',
  // ── UI & app behaviour ──
  'languageCode',
  'autoGetCountry',
  'countryCode',
  'chartShowMap',
  'auto_slide_charts',
  'auto_update_notify',
  // ── Lyrics & history ──
  'autoSaveLyrics',
  'autoHistoryCleanupTime',
  // ── Last.FM preferences (connection itself is NOT synced) ──
  'lastFMUIPicks',
  'lastFMScrobble',
};

/// Maximum length for playlist names pushed to the cloud (Firestore and
/// security-rule sanity limit).
const int kMaxSyncPlaylistNameLength = 200;

/// Firestore document/collection layout:
///
/// ```
/// users/{uid}/meta/doc                    → {schemaVersion, updatedAt}
/// users/{uid}/playlists/{syncId}          → playlist metadata (+ deletedAt?)
/// users/{uid}/playlists/{syncId}/entries/{entryId} → entries (+ deletedAt?)
/// users/{uid}/favourites/{mediaId}        → {addedAt, deletedAt?}
/// users/{uid}/settings/{key}              → {value, updatedAt}
/// ```
///
/// Notes:
/// - `mediaId` uses Orvia's composite `"{pluginId}::{localId}"` format which
///   never contains `/`, so it is always a legal Firestore document id.
/// - Deletions are represented as inline tombstones (`deletedAt`) so that a
///   deletion can propagate without losing ordering information.
class CloudSyncPaths {
  CloudSyncPaths._();

  static String metaDoc(String uid) => 'users/$uid/meta/doc';
  static String playlistsCol(String uid) => 'users/$uid/playlists';
  static String playlistDoc(String uid, String syncId) =>
      'users/$uid/playlists/$syncId';
  static String entriesCol(String uid, String syncId) =>
      'users/$uid/playlists/$syncId/entries';
  static String entryDoc(String uid, String syncId, String entryId) =>
      'users/$uid/playlists/$syncId/entries/$entryId';
  static String favouritesCol(String uid) => 'users/$uid/favourites';
  static String favouriteDoc(String uid, String mediaId) =>
      'users/$uid/favourites/$mediaId';
  static String settingsCol(String uid) => 'users/$uid/settings';
  static String settingDoc(String uid, String key) =>
      'users/$uid/settings/$key';
}
