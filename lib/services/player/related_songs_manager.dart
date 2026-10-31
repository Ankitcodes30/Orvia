import 'dart:developer';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/player/player_engine.dart';
import 'package:Orvia/services/plugin/plugin_service.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:rxdart/rxdart.dart';

class RelatedSongsManager {
  final BehaviorSubject<List<Track>> relatedSongs =
      BehaviorSubject<List<Track>>.seeded([]);
  final PluginService _pluginService;
  final Set<String> _fetchedTrackIds = <String>{};

  int _requestGeneration = 0;
  String? _referenceTrackId;
  String? _referenceLocalId;
  String? _pluginId;
  String? _nextPageToken;
  bool _isFetching = false;
  bool _isExhausted = false;

  // Callbacks
  Function(List<Track> items, {bool atLast})? onAddQueueItems;

  static final _kNonMusicPatterns = RegExp(
    r'\b(trailer|teaser|full movie|reaction|review|vlog|episode|ep\s*\d+|part\s*\d+|scene|comedy scene|short film|highlight|press meet|interview|roast|unboxing|prank)\b',
    caseSensitive: false,
  );

  static final _kNonMusicAuthors = RegExp(
    r'\b(sony liv|slayy point|set india|colors tv|star plus|netflix|prime video|zeetv|sab tv|taarak mehta)\b',
    caseSensitive: false,
  );

  static bool _isMusicTrack(Track track) {
    final title = track.title.toLowerCase();
    if (_kNonMusicPatterns.hasMatch(title)) return false;

    for (final a in track.artists) {
      if (_kNonMusicAuthors.hasMatch(a.name.toLowerCase())) return false;
    }
    return true;
  }

  RelatedSongsManager(this._pluginService);

  Future<void> checkForRelatedSongs({
    required Track currentMedia,
    required List<Track> queue,
    required int currentPlayingIdx,
    required LoopMode loopMode,
    bool isFromPlaylist = false,
  }) async {
    log("Checking for related songs: ${queue.isNotEmpty && (queue.length - currentPlayingIdx) < 2}",
        name: "RelatedSongsManager");

    bool autoPlay = true;
    if (DBProvider.isInitialized) {
      try {
        final setting =
            await SettingsDAO(DBProvider.db).getSettingBool(SettingKeys.autoPlay);
        if (setting != null) autoPlay = setting;
      } catch (_) {}
    }
    if (!autoPlay) return;

    // For playlist and album queues, never inject artist recommendations.
    if (isFromPlaylist) {
      return;
    }

    final shouldQueueMore = queue.isNotEmpty &&
        (queue.length - currentPlayingIdx) <= 2 &&
        loopMode != LoopMode.all;
    if (!shouldQueueMore) {
      return;
    }

    final parts = tryParseMediaId(currentMedia.id);
    if (parts == null) {
      return;
    }

    if (parts.pluginId == kLocalPluginId) {
      clearRelatedSongs();
      return;
    }

    _syncReferenceState(
      trackId: currentMedia.id,
      pluginId: parts.pluginId,
      localId: parts.localId,
    );

    final gen = _requestGeneration;

    if (relatedSongs.value.isEmpty) {
      await _fetchNextRadioPage();
    }
    if (_requestGeneration != gen) return;

    await loadRelatedSongs(
        queue: queue, currentPlayingIdx: currentPlayingIdx, loopMode: loopMode);
    if (_requestGeneration != gen) return;

    if (relatedSongs.value.isEmpty) {
      await _fetchNextRadioPage();
      if (_requestGeneration != gen) return;
      await loadRelatedSongs(
        queue: queue,
        currentPlayingIdx: currentPlayingIdx,
        loopMode: loopMode,
      );
    }
  }

  Future<void> loadRelatedSongs({
    required List<Track> queue,
    required int currentPlayingIdx,
    required LoopMode loopMode,
  }) async {
    if (relatedSongs.value.isNotEmpty &&
        (queue.length - currentPlayingIdx) < 3 &&
        loopMode != LoopMode.all) {
      final items = List<Track>.from(relatedSongs.value);
      relatedSongs.add([]);
      onAddQueueItems?.call(items, atLast: true);
    }
  }

  void clearRelatedSongs() {
    _requestGeneration++;
    relatedSongs.add([]);
    _fetchedTrackIds.clear();
    _referenceTrackId = null;
    _referenceLocalId = null;
    _pluginId = null;
    _nextPageToken = null;
    _isFetching = false;
    _isExhausted = false;
  }

  void _syncReferenceState({
    required String trackId,
    required String pluginId,
    required String localId,
  }) {
    if (_referenceTrackId == trackId && _pluginId == pluginId) {
      return;
    }

    _requestGeneration++;
    relatedSongs.add([]);
    _fetchedTrackIds.clear();
    _referenceTrackId = trackId;
    _referenceLocalId = localId;
    _pluginId = pluginId;
    _nextPageToken = null;
    _isFetching = false;
    _isExhausted = false;
  }

  Future<void> _fetchNextRadioPage() async {
    if (_isFetching ||
        _isExhausted ||
        _pluginId == null ||
        _referenceLocalId == null) {
      return;
    }

    final capturedGen = _requestGeneration;
    final capturedPluginId = _pluginId!;
    final capturedLocalId = _referenceLocalId!;

    _isFetching = true;
    try {
      final response = await _pluginService.execute(
        pluginId: capturedPluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.getRadioTracks(
            id: capturedLocalId,
            pageToken: _nextPageToken,
          ),
        ),
      );

      // Discard stale or superseded request response.
      if (_requestGeneration != capturedGen ||
          _referenceLocalId != capturedLocalId ||
          _pluginId != capturedPluginId) {
        log('Discarding stale radio response (gen $capturedGen != $_requestGeneration)',
            name: 'RelatedSongsManager');
        return;
      }

      response.when(
        moreTracks: (pagedTracks) {
          final uniqueTracks = pagedTracks.items.where((track) {
            return _isMusicTrack(track) && _fetchedTrackIds.add(track.id);
          }).toList(growable: false);

          if (uniqueTracks.isNotEmpty) {
            relatedSongs.add([...relatedSongs.value, ...uniqueTracks]);
            log(
              'Buffered ${uniqueTracks.length} related songs',
              name: 'RelatedSongsManager',
            );
          }

          _nextPageToken = pagedTracks.nextPageToken;
          _isExhausted =
              pagedTracks.nextPageToken == null && uniqueTracks.isEmpty;
        },
        trackDetails: (_) {},
        albumDetails: (_) {},
        artistDetails: (_) {},
        playlistDetails: (_) {},
        streams: (_) {},
        search: (_) {},
        moreAlbums: (_) {},
        homeSections: (_) {},
        loadMoreItems: (_) {},
        charts: (_) {},
        chartDetails: (_) {},
        segments: (_) {},
        lyricsResult: (_) {},
        lyricsSearchResults: (_) {},
        lyricsById: (_, __) {},
        suggestions: (_) {},
        canHandle: (_) {},
        collectionInfo: (_) {},
        importTracks: (_) {},
        ack: () {},
      );
    } catch (e) {
      log('Failed to get related songs: $e', name: 'RelatedSongsManager');
    } finally {
      _isFetching = false;
    }
  }

  void dispose() {
    relatedSongs.close();
  }
}
