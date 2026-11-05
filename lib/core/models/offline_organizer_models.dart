import 'dart:convert';

/// Represents a user-created folder in the Offline section.
class OfflineFolder {
  final String id;
  final String name;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OfflineFolder({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  OfflineFolder copyWith({
    String? id,
    String? name,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfflineFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? List<String>.from(this.trackIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'trackIds': trackIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory OfflineFolder.fromMap(Map<String, dynamic> map) {
    return OfflineFolder(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Folder',
      trackIds: (map['trackIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory OfflineFolder.fromJson(String source) =>
      OfflineFolder.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents an offline-saved collection (e.g. from a downloaded playlist or album).
class OfflineCollection {
  final String id;
  final String title;
  final String type; // 'playlist' | 'album'
  final String? coverUrl;
  final List<String> requestedTrackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OfflineCollection({
    required this.id,
    required this.title,
    required this.type,
    this.coverUrl,
    required this.requestedTrackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  OfflineCollection copyWith({
    String? id,
    String? title,
    String? type,
    String? coverUrl,
    List<String>? requestedTrackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfflineCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      coverUrl: coverUrl ?? this.coverUrl,
      requestedTrackIds:
          requestedTrackIds ?? List<String>.from(this.requestedTrackIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'coverUrl': coverUrl,
        'requestedTrackIds': requestedTrackIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory OfflineCollection.fromMap(Map<String, dynamic> map) {
    return OfflineCollection(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Collection',
      type: map['type'] as String? ?? 'playlist',
      coverUrl: map['coverUrl'] as String?,
      requestedTrackIds: (map['requestedTrackIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory OfflineCollection.fromJson(String source) =>
      OfflineCollection.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineCollection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Analysis of folder deletion to safeguard against unintentional file deletion.
class FolderDeleteImpact {
  final int totalTracks;
  final int sharedTracksCount;
  final int uniqueTracksCount;
  final List<String> uniqueTrackIds;
  final List<String> sharedTrackIds;

  const FolderDeleteImpact({
    required this.totalTracks,
    required this.sharedTracksCount,
    required this.uniqueTracksCount,
    required this.uniqueTrackIds,
    required this.sharedTrackIds,
  });
}

