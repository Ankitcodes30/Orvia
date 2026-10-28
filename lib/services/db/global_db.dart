//DB version 3
import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:Orvia/services/cloud_sync/sync_record_kind.dart';
export 'package:Orvia/services/cloud_sync/sync_record_kind.dart'
    show SyncRecordKind;
part 'global_db.g.dart';

enum ImageLayoutDB {
  square,
  portrait,
  landscape,
  banner,
  circular,
}

enum PlaylistTypeDB {
  userPlaylist,
  album,
  artist,
  remotePlaylist,
}

@embedded
class ArtworkDB {
  late String url;
  String? urlLow;
  String? urlHigh;

  @enumerated
  ImageLayoutDB layout = ImageLayoutDB.square;
}

@embedded
class ArtistSummaryDB {
  String? name;
  ArtworkDB? thumbnail;
  String? url;
  String? mediaId;
  String? subtitle;
}

@embedded
class AlbumSummaryDB {
  String name;
  ArtworkDB? thumbnail;
  String? year;
  String? url;
  List<ArtistSummaryDB>? artists;
  String? mediaId;

  AlbumSummaryDB({
    String? title,
    this.thumbnail,
    this.year,
    this.url,
    this.artists,
    this.mediaId,
  }) : name = title ?? '';
}

@embedded
class RemotePlaylistSummaryDB {
  String name;
  List<ArtistSummaryDB>? artists;
  ArtworkDB? thumbnail;
  String? subtitle;
  AlbumSummaryDB? album;
  String? mediaId;
  String? url;

  RemotePlaylistSummaryDB({
    String? title,
    this.artists,
    this.thumbnail,
    this.subtitle,
    this.album,
    this.mediaId,
    this.url,
  }) : name = title ?? '';
}

@collection
class TrackDB {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String mediaId;

  @Index(type: IndexType.value, caseSensitive: false)
  String title;

  List<ArtistSummaryDB>? artists;
  AlbumSummaryDB? album;
  ArtworkDB? thumbnail;
  int? durationMs;
  String? genre;
  String? language;
  bool isExplicit;

  TrackDB({
    required this.mediaId,
    required this.title,
    this.artists,
    this.album,
    this.thumbnail,
    this.durationMs,
    this.genre,
    this.language,
    this.isExplicit = false,
  });
}

@collection
class PlaylistDB {
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value, caseSensitive: false, unique: true)
  String name;
  String? subtitle;
  String? description;
  ArtworkDB? thumbnail;
  List<ArtistSummaryDB>? artists;
  AlbumSummaryDB? album;
  RemotePlaylistSummaryDB? remotePlaylist;

  @enumerated
  PlaylistTypeDB type;

  @Index()
  int get typeIndex => type.index;

  DateTime createdAt;
  DateTime updatedAt;

  @Index()
  int sortOrder;
  bool isPinned;

  /// Stable cross-device identifier (UUID v4) assigned lazily by the cloud
  /// sync layer. Null for records that have never been synchronized.
  /// Never use the Isar auto-increment [id] for cloud identity — it is
  /// device-local and unstable across restores.
  @Index(type: IndexType.value)
  String? syncId;

  @Backlink(to: 'playlist')
  final entries = IsarLinks<PlaylistEntryDB>();

  PlaylistDB({
    required this.name,
    this.subtitle,
    this.description,
    this.thumbnail,
    this.artists,
    this.album,
    this.remotePlaylist,
    this.type = PlaylistTypeDB.userPlaylist,
    this.sortOrder = 0,
    this.isPinned = false,
    DateTime? createdat,
    DateTime? updatedat,
    this.syncId,
  })  : createdAt = createdat ?? DateTime.now(),
        updatedAt = updatedat ?? DateTime.now();
}

@collection
class PlaylistEntryDB {
  Id id = Isar.autoIncrement;

  final playlist = IsarLink<PlaylistDB>();
  final track = IsarLink<TrackDB>();

  @Index(composite: [CompositeIndex('position')])
  int? playlistId;

  int position;
  DateTime addedAt;

  /// Stable cross-device identifier (UUID v4) assigned lazily by the cloud
  /// sync layer. Null for entries created before sync was enabled.
  @Index(type: IndexType.value)
  String? syncId;

  PlaylistEntryDB({
    this.playlistId,
    this.position = 0,
    DateTime? addedAtOverride,
    this.syncId,
  }) : addedAt = addedAtOverride ?? DateTime.now();

  void syncPlaylistId() {
    playlistId = playlist.value?.id;
  }
}

@collection
class NotificationsDB {
  Id id = Isar.autoIncrement;

  String title;
  String body;

  @Index()
  String type;

  String? url;
  String? payload;

  @Index()
  DateTime? time;

  NotificationsDB({
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.url,
    this.payload,
  });
}

@collection
class LyricsDB {
  Id id = Isar.autoIncrement;

  String sourceId;

  @Index(composite: [CompositeIndex('sourceId')], unique: true, replace: true)
  String mediaID;

  String plainLyrics;
  String title;
  String artist;
  String source;
  String? album;
  int? offset;
  int? duration;
  String? url;
  String? syncedLyrics;

  LyricsDB({
    required this.sourceId,
    required this.mediaID,
    required this.plainLyrics,
    required this.title,
    required this.artist,
    required this.source,
    this.album,
    this.offset,
    this.duration,
    this.syncedLyrics,
    this.url,
  });
}

@collection
class SearchHistoryDB {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String query;

  @Index()
  DateTime lastSearched;

  SearchHistoryDB({
    required this.query,
    required this.lastSearched,
  });

  Map<String, dynamic> toMap() => {
        'query': query,
        'lastSearched': lastSearched.millisecondsSinceEpoch,
      };

  factory SearchHistoryDB.fromMap(Map<String, dynamic> map) => SearchHistoryDB(
        query: (map['query'] as String?) ?? '',
        lastSearched:
            DateTime.fromMillisecondsSinceEpoch(map['lastSearched'] as int),
      );

  String toJson() => json.encode(toMap());

  factory SearchHistoryDB.fromJson(String source) =>
      SearchHistoryDB.fromMap(json.decode(source) as Map<String, dynamic>);
}

@collection
class DownloadDB {
  Id id = Isar.autoIncrement;

  String fileName;
  String filePath;
  DateTime? lastDownloaded;

  @Index(unique: true, replace: true)
  String mediaId;

  DownloadDB({
    required this.fileName,
    required this.filePath,
    required this.lastDownloaded,
    required this.mediaId,
  });
}

@collection
class AppSettingsStrDB {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String settingName;

  String settingValue;
  String? settingValue2;
  DateTime? lastUpdated;

  AppSettingsStrDB({
    required this.settingName,
    required this.settingValue,
    this.settingValue2,
    this.lastUpdated,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsStrDB &&
        other.settingName == settingName &&
        other.settingValue == settingValue;
  }

  @override
  int get hashCode => Object.hash(settingName, settingValue);

  Map<String, dynamic> toMap() => {
        'settingName': settingName,
        'settingValue': settingValue,
        'settingValue2': settingValue2,
        'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
      };

  factory AppSettingsStrDB.fromMap(Map<String, dynamic> map) =>
      AppSettingsStrDB(
        settingName: (map['settingName'] as String?) ?? '',
        settingValue: (map['settingValue'] as String?) ?? '',
        settingValue2: map['settingValue2'] as String?,
        lastUpdated: map['lastUpdated'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int)
            : null,
      );

  String toJson() => json.encode(toMap());

  factory AppSettingsStrDB.fromJson(String source) =>
      AppSettingsStrDB.fromMap(json.decode(source) as Map<String, dynamic>);
}

@collection
class AppSettingsBoolDB {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String settingName;

  bool settingValue;

  AppSettingsBoolDB({
    required this.settingName,
    required this.settingValue,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsBoolDB &&
        other.settingName == settingName &&
        other.settingValue == settingValue;
  }

  @override
  int get hashCode => Object.hash(settingName, settingValue);

  Map<String, dynamic> toMap() => {
        'settingName': settingName,
        'settingValue': settingValue,
      };

  factory AppSettingsBoolDB.fromMap(Map<String, dynamic> map) =>
      AppSettingsBoolDB(
        settingName: (map['settingName'] as String?) ?? '',
        settingValue: (map['settingValue'] as bool?) ?? false,
      );

  String toJson() => json.encode(toMap());

  factory AppSettingsBoolDB.fromJson(String source) =>
      AppSettingsBoolDB.fromMap(json.decode(source) as Map<String, dynamic>);
}

@collection
class PlaybackHistoryDB {
  Id id = Isar.autoIncrement;

  final track = IsarLink<TrackDB>();

  @Index()
  DateTime playedAt;

  PlaybackHistoryDB({
    TrackDB? trackObj,
    required this.playedAt,
  }) {
    if (trackObj != null) {
      track.value = trackObj;
    }
  }
}

@collection
class CacheEntryDB {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String key;

  @Index()
  String value;

  String? blob;
  DateTime? lastUpdated;

  @Index()
  DateTime? ttl;

  CacheEntryDB({
    required this.key,
    required this.value,
    this.blob,
    this.lastUpdated,
    this.ttl,
  });

  @ignore
  bool get isExpired => ttl != null && DateTime.now().isAfter(ttl!);
}

/// Persists plugin key-value storage entries to Isar.
///
/// Rust plugin storage is in-memory (for instant sync WASM reads).
/// This collection mirrors it persistently so data survives app restarts.
/// On startup, all entries are preloaded back into Rust via [pluginStoragePreload].
///
/// Composite key format: `"{pluginId}/{key}"`.
@collection
class PluginStorageEntity {
  Id id = Isar.autoIncrement;

  /// Composite key: `"{pluginId}/{key}"`.
  @Index(unique: true, replace: true)
  late String compositeKey;

  /// The plugin that owns this entry.
  @Index()
  late String pluginId;

  /// The storage key within the plugin's namespace.
  late String key;

  /// The stored value (arbitrary string — plugins may store JSON).
  late String value;

  /// Last time this entry was written.
  DateTime updatedAt;

  PluginStorageEntity({
    required this.pluginId,
    required this.key,
    required this.value,
    required this.updatedAt,
  }) : compositeKey = '$pluginId/$key';
}

// ── Cloud sync bookkeeping ────────────────────────────────────────────────────
// These collections record sync metadata ONLY. They never contain user media
// or credentials. Local playlist/entry/favourite/settings data stays in the
// original collections; here we track what has been pushed/applied per record.
// [SyncRecordKind] lives in `lib/services/cloud_sync/sync_record_kind.dart`
// and is re-exported from here for convenience.

/// Per-record synchronization state for the local store.
///
/// - [lastPushedHash] detects local edits (content changed since last push).
/// - [lastAppliedAt] suppresses echoes of our own cloud writes coming back
///   through Firestore listeners.
/// - A row's existence means "this record has been synced at least once";
///   deletion of a row (after pushing a cloud tombstone) is how local
///   deletions are detected.
@collection
class SyncStateDB {
  Id id = Isar.autoIncrement;

  /// Composite-unique key of the record: Isar id for playlists/entries (as
  /// string), mediaId for favourites, settings key for settings.
  @Index(unique: true, replace: true, composite: [CompositeIndex('kind')])
  late String localKey;

  @enumerated
  late SyncRecordKind kind;

  /// Cloud document id (playlist/entry syncId, mediaId, or settings key).
  late String cloudId;

  /// SHA-256 of the record content at the last successful push.
  late String lastPushedHash;

  DateTime? lastPushedAt;

  /// Cloud `updatedAt` of the last record applied FROM the cloud.
  DateTime? lastAppliedAt;

  SyncStateDB({
    required this.localKey,
    required this.kind,
    required this.cloudId,
    required this.lastPushedHash,
    this.lastPushedAt,
    this.lastAppliedAt,
  });
}

/// Ledger of records adopted (downloaded) from a specific account's cloud.
///
/// Used to prevent cross-account contamination on account switching: records
/// adopted from account A are held back from being pushed into account B's
/// cloud if B's cloud does not already contain them. Guest-native records
/// (created locally before any sign-in) have no adoption rows and are always
/// eligible for migration upload.
@collection
class SyncAdoptionDB {
  Id id = Isar.autoIncrement;

  /// Cloud record key (playlist/entry syncId, mediaId, or settings key).
  @Index(unique: true, replace: true, composite: [CompositeIndex('kind')])
  late String recordKey;

  @enumerated
  late SyncRecordKind kind;

  @Index()
  late String uid;

  late DateTime adoptedAt;

  SyncAdoptionDB({
    required this.recordKey,
    required this.kind,
    required this.uid,
    required this.adoptedAt,
  });
}
