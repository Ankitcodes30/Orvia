import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';

class SpeedDialItem {
  final String id;
  final String title;
  final String subtitle;
  final bool isPlaylist;
  final bool isPinned;
  final List<String> artworkUrls;
  final List<Track> tracks;

  const SpeedDialItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isPlaylist,
    this.isPinned = false,
    required this.artworkUrls,
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'isPlaylist': isPlaylist,
        'isPinned': isPinned,
        'artworkUrls': artworkUrls,
      };

  factory SpeedDialItem.fromJson(
    Map<String, dynamic> json,
    List<Track> fallbackTracks,
  ) {
    return SpeedDialItem(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      isPlaylist: json['isPlaylist'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? true,
      artworkUrls: (json['artworkUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tracks: fallbackTracks,
    );
  }
}

class SpeedDialService {
  static const String _prefKey = 'speed_dial_pinned_items_v1';
  static final ValueNotifier<List<SpeedDialItem>> pinnedItemsNotifier =
      ValueNotifier<List<SpeedDialItem>>([]);
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final settingsDAO = SettingsDAO(DBProvider.db);
      final jsonStr = await settingsDAO.getSettingStr(_prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final verified = CreatorsChoiceService.getVerifiedTracks();
        final items = <SpeedDialItem>[];
        for (final m in decoded) {
          final id = m['id'] as String?;
          if (id != null) {
            final track = verified.firstWhere(
              (t) => t.id == id,
              orElse: () => verified.first,
            );
            items.add(SpeedDialItem.fromJson(m as Map<String, dynamic>, [track]));
          }
        }
        pinnedItemsNotifier.value = items;
        return;
      }
    } catch (_) {}

    // Default seeded pinned item (matching Metrolist screenshot pinned slot)
    final verified = CreatorsChoiceService.getVerifiedTracks();
    final defaultPinned = SpeedDialItem(
      id: 'pinned_creators_choice',
      title: "Creator's Choice",
      subtitle: 'Playlist • Curated',
      isPlaylist: true,
      isPinned: true,
      artworkUrls: verified.take(4).map((t) => t.thumbnail.url).toList(),
      tracks: verified,
    );
    pinnedItemsNotifier.value = [defaultPinned];
    _saveToStorage();
  }

  static bool isPinned(String id) {
    return pinnedItemsNotifier.value.any((item) => item.id == id);
  }

  static Future<void> pinTrack(Track track) async {
    final current = List<SpeedDialItem>.from(pinnedItemsNotifier.value);
    if (current.any((i) => i.id == track.id)) return;

    current.insert(
      0,
      SpeedDialItem(
        id: track.id,
        title: track.title,
        subtitle: track.artists.isNotEmpty ? track.artists.first.name : '',
        isPlaylist: false,
        isPinned: true,
        artworkUrls: [track.thumbnail.url],
        tracks: [track],
      ),
    );
    pinnedItemsNotifier.value = current;
    await _saveToStorage();
  }

  static Future<void> pinPlaylist({
    required String id,
    required String title,
    required List<Track> tracks,
  }) async {
    final current = List<SpeedDialItem>.from(pinnedItemsNotifier.value);
    if (current.any((i) => i.id == id)) return;

    final artList = tracks.take(4).map((t) => t.thumbnail.url).toList();
    current.insert(
      0,
      SpeedDialItem(
        id: id,
        title: title,
        subtitle: '${tracks.length} tracks',
        isPlaylist: true,
        isPinned: true,
        artworkUrls: artList,
        tracks: tracks,
      ),
    );
    pinnedItemsNotifier.value = current;
    await _saveToStorage();
  }

  static Future<void> unpin(String id) async {
    final current = List<SpeedDialItem>.from(pinnedItemsNotifier.value);
    current.removeWhere((i) => i.id == id);
    pinnedItemsNotifier.value = current;
    await _saveToStorage();
  }

  static Future<void> _saveToStorage() async {
    try {
      final jsonList = pinnedItemsNotifier.value.map((i) => i.toJson()).toList();
      final settingsDAO = SettingsDAO(DBProvider.db);
      await settingsDAO.putSettingStr(_prefKey, jsonEncode(jsonList));
    } catch (_) {}
  }
}
