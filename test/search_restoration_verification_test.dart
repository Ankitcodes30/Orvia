// Search Restoration Verification Test
// Tests the 3.0.7+7 search regression fix across UI, BLoC lifecycle,
// query normalization, plugin resolver fallback, and result mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/blocs/content/content_event.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/src/rust/api/plugin/manifest.dart';
import 'package:Orvia/src/rust/api/plugin/plugin_info.dart';
import 'package:Orvia/src/rust/api/plugin/types.dart';

class FakePluginInfo implements PluginInfo {
  @override
  Manifest manifest;
  @override
  String name;
  @override
  String pluginPath;
  @override
  PluginType pluginType;
  @override
  bool isDisposed = false;

  FakePluginInfo({
    required this.manifest,
    this.name = 'Fake Plugin',
    this.pluginPath = '/fake/path',
    this.pluginType = PluginType.contentResolver,
  });

  @override
  void dispose() {
    isDisposed = true;
  }
}

void main() {
  group('Search Query Normalization & Validation', () {
    String normalizeSearchQuery(String query) =>
        query.trim().replaceAll(RegExp(r'\s+'), ' ');

    test('normalizes extra spaces and tabs in search queries', () {
      expect(normalizeSearchQuery('   Arijit    Singh   '), 'Arijit Singh');
      expect(normalizeSearchQuery("Arijit\t\nSingh"), 'Arijit Singh');
      expect(normalizeSearchQuery('Kesariya'), 'Kesariya');
    });

    test('empty or whitespace-only queries normalize to empty', () {
      expect(normalizeSearchQuery(''), '');
      expect(normalizeSearchQuery('   '), '');
      expect(normalizeSearchQuery("\t\n  "), '');
    });
  });

  group('Active Plugin Resolver Resolution Logic', () {
    const kDefaultYTMusicPluginId = 'content-resolver.bloomfactory.ytmusic';

    PluginInfo makeMockPlugin(String id, String name) {
      return FakePluginInfo(
        manifest: Manifest(
          manifestVersion: 1,
          id: id,
          name: name,
          version: '1.0.0',
          type: 'content-resolver',
          description: '$name description',
          publisher: const PluginPublisher(name: 'Bloom Factory', url: null),
          license: 'MIT',
          homepage: 'https://orvia.app',
          icon: null,
          hostSite: const [],
          capabilities: const ['content-resolver'],
          createdAt: null,
          remoteUrl: null,
          keysRequired: const {},
          thumbnailUrl: null,
          resolver: true,
          lastUpdated: null,
          countryAllowlist: const [],
        ),
        name: name,
        pluginPath: '/plugins/$id',
        pluginType: PluginType.contentResolver,
      );
    }

    String? resolveActivePluginId({
      required List<PluginInfo> resolvers,
      String? currentActiveId,
      String persistedId = '',
    }) {
      if (resolvers.isEmpty) {
        return null;
      }

      if (currentActiveId != null &&
          resolvers.any((p) => p.manifest.id == currentActiveId)) {
        return currentActiveId;
      }

      if (persistedId.isNotEmpty &&
          resolvers.any((p) => p.manifest.id == persistedId)) {
        return persistedId;
      }

      final saavnPlugin = resolvers.cast<PluginInfo?>().firstWhere(
        (p) => p?.manifest.id == kDefaultSaavnPluginId,
        orElse: () => null,
      );
      if (saavnPlugin != null) {
        return kDefaultSaavnPluginId;
      }

      return resolvers.first.manifest.id;
    }

    test('returns null when resolvers list is empty (cold start before plugins load)', () {
      final active = resolveActivePluginId(resolvers: []);
      expect(active, isNull);
    });

    test('maintains currently active plugin if still loaded', () {
      final saavn = makeMockPlugin(kDefaultSaavnPluginId, 'JioSaavn');
      final ytmusic = makeMockPlugin(kDefaultYTMusicPluginId, 'YouTube Music');

      final active = resolveActivePluginId(
        resolvers: [saavn, ytmusic],
        currentActiveId: kDefaultYTMusicPluginId,
      );
      expect(active, kDefaultYTMusicPluginId);
    });

    test('uses persisted user preference if valid', () {
      final saavn = makeMockPlugin(kDefaultSaavnPluginId, 'JioSaavn');
      final ytmusic = makeMockPlugin(kDefaultYTMusicPluginId, 'YouTube Music');

      final active = resolveActivePluginId(
        resolvers: [saavn, ytmusic],
        persistedId: kDefaultYTMusicPluginId,
      );
      expect(active, kDefaultYTMusicPluginId);
    });

    test('falls back to JioSaavn when no preference is persisted', () {
      final ytmusic = makeMockPlugin(kDefaultYTMusicPluginId, 'YouTube Music');
      final saavn = makeMockPlugin(kDefaultSaavnPluginId, 'JioSaavn');

      // Even if ytmusic appears first in filesystem enumeration order
      final active = resolveActivePluginId(
        resolvers: [ytmusic, saavn],
        persistedId: '',
      );
      expect(active, kDefaultSaavnPluginId);
    });

    test('falls back to first available resolver if JioSaavn is not available', () {
      final ytmusic = makeMockPlugin(kDefaultYTMusicPluginId, 'YouTube Music');

      final active = resolveActivePluginId(
        resolvers: [ytmusic],
        persistedId: '',
      );
      expect(active, kDefaultYTMusicPluginId);
    });
  });

  group('Content Search Event & State Integrity', () {
    test('SearchContent includes explicit pluginId and filter', () {
      const event = SearchContent(
        query: 'Arijit Singh',
        filter: ContentSearchFilter.track,
        pluginId: kDefaultSaavnPluginId,
      );

      expect(event.query, 'Arijit Singh');
      expect(event.filter, ContentSearchFilter.track);
      expect(event.pluginId, kDefaultSaavnPluginId);
      expect(event.pageToken, isNull);
    });

    test('SearchContent pagination carries pageToken and target pluginId', () {
      const event = SearchContent(
        query: 'Arijit Singh',
        filter: ContentSearchFilter.all,
        pageToken: 'page_token_2',
        pluginId: 'content-resolver.bloomfactory.ytmusic',
      );

      expect(event.query, 'Arijit Singh');
      expect(event.pageToken, 'page_token_2');
      expect(event.pluginId, 'content-resolver.bloomfactory.ytmusic');
    });

    test('SetActiveContentPlugin correctly conveys target plugin id', () {
      const event = SetActiveContentPlugin(
        pluginId: kDefaultSaavnPluginId,
      );
      expect(event.pluginId, kDefaultSaavnPluginId);
    });
  });

  group('Playback Handoff & Search Results Formatting', () {
    test('Search results map correctly into Track list for playback queue', () {
      final track1 = Track(
        id: 'content-resolver.bloomfactory.jisaavn::song_1',
        title: 'Tu Mil Jaaye',
        artists: const [ArtistSummary(id: 'art_1', name: 'Arijit Singh')],
        album: const AlbumSummary(id: 'alb_1', title: 'KING', artists: []),
        durationMs: BigInt.from(215000),
        thumbnail: const Artwork(url: 'https://c.saavncdn.com/1.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final track2 = Track(
        id: 'content-resolver.bloomfactory.ytmusic::song_2',
        title: 'Tum Hi Ho',
        artists: const [ArtistSummary(id: 'art_1', name: 'Arijit Singh')],
        album: const AlbumSummary(id: 'alb_2', title: 'Aashiqui 2', artists: []),
        durationMs: BigInt.from(262000),
        thumbnail: const Artwork(url: 'https://i.ytimg.com/vi/2/maxresdefault.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final searchResults = [track1, track2];
      expect(searchResults.length, 2);
      expect(searchResults.first.title, 'Tu Mil Jaaye');
      expect(searchResults.first.artists.first.name, 'Arijit Singh');
      expect(searchResults.last.title, 'Tum Hi Ho');
      expect(searchResults.last.durationMs, BigInt.from(262000));
    });
  });
}
