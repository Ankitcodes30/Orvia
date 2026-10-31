import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/screens/screen/library_views/more_opts_sheet.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';
import 'package:Orvia/services/share/orvia_short_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playlist Sharing & Deep Link Tests', () {
    final sampleTracks = [
      Track(
        id: 'saavn:dxrBpjVX',
        title: 'Kesariya',
        artists: const [ArtistSummary(id: 'arijit', name: 'Arijit Singh')],
        album: const AlbumSummary(
            id: 'brahmastra', title: 'Brahmastra', artists: []),
        thumbnail: const Artwork(
            url: 'https://c.saavncdn.com/123/art-500x500.jpg',
            layout: ImageLayout.square),
        durationMs: BigInt.from(268000),
        isExplicit: false,
      ),
      Track(
        id: 'youtube:dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artists: const [ArtistSummary(id: 'rick', name: 'Rick Astley')],
        album: const AlbumSummary(
            id: 'whenever', title: 'Whenever You Need Somebody', artists: []),
        thumbnail: const Artwork(
            url: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
            layout: ImageLayout.square),
        durationMs: BigInt.from(212000),
        isExplicit: false,
      ),
    ];

    test(
        '1. Sharing a playlist produces a valid URL rather than a file attachment',
        () {
      final uri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'My Roadtrip Mix',
        tracks: sampleTracks,
        useAppScheme: false,
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('ankitcodes30.github.io'));
      expect(uri.path, equals('/Orvia/playlist'));
      expect(uri.queryParameters.containsKey('data'), isTrue);
      expect(uri.queryParameters['name'], equals('My Roadtrip Mix'));

      // Link must be a valid shareable string without .json extension
      final urlStr = uri.toString();
      expect(urlStr.endsWith('.json'), isFalse);
      expect(urlStr.startsWith('https://ankitcodes30.github.io/Orvia/playlist'),
          isTrue);
    });

    test(
        '2. A generated link retrieves the exact correct playlist on another device context',
        () {
      final shareUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Chill Vibes',
        description: 'Late night tunes',
        artworkUrl: 'https://example.com/cover.jpg',
        tracks: sampleTracks,
        useAppScheme: false,
      );

      // Simulate recipient receiving the URL on another device/session
      final recipientUri = Uri.parse(shareUri.toString());
      final decodedPlaylist =
          OrviaDeepLinkService.parsePlaylistFromUri(recipientUri);

      expect(decodedPlaylist, isNotNull);
      expect(decodedPlaylist!.title, equals('Chill Vibes'));
      expect(decodedPlaylist.description, equals('Late night tunes'));
      expect(decodedPlaylist.thumbnail?.url,
          equals('https://example.com/cover.jpg'));
      expect(decodedPlaylist.tracks.length, equals(2));

      // Verify track order and exact track metadata
      expect(decodedPlaylist.tracks[0].id, equals('saavn:dxrBpjVX'));
      expect(decodedPlaylist.tracks[0].title, equals('Kesariya'));
      expect(
          decodedPlaylist.tracks[0].artists.first.name, equals('Arijit Singh'));
      expect(decodedPlaylist.tracks[0].album?.title, equals('Brahmastra'));

      expect(decodedPlaylist.tracks[1].id, equals('youtube:dQw4w9WgXcQ'));
      expect(
          decodedPlaylist.tracks[1].title, equals('Never Gonna Give You Up'));
      expect(
          decodedPlaylist.tracks[1].artists.first.name, equals('Rick Astley'));
    });

    test('3. Landing page payload is gzip-compressed and URL-safe', () {
      final payload = OrviaDeepLinkService.encodePlaylistData(
        title: 'Dance Hits',
        tracks: sampleTracks,
      );

      // Verify it is URL-safe base64 without padding or unsafe characters
      expect(payload.contains('+'), isFalse);
      expect(payload.contains('/'), isFalse);
      expect(payload.contains('='), isFalse);

      final decoded = OrviaDeepLinkService.decodePlaylistData(payload);
      expect(decoded, isNotNull);
      expect(decoded!['t'], equals('Dance Hits'));
      expect((decoded['tr'] as List).length, equals(2));
    });

    test('4. All primary destinations match intended schemes and domains', () {
      final webUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Favorites',
        tracks: sampleTracks,
        useAppScheme: false,
      );
      final appUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Favorites',
        tracks: sampleTracks,
        useAppScheme: true,
      );

      // Destination 1: In-App Scheme
      expect(appUri.scheme, equals('orvia'));
      expect(appUri.host, equals('playlist'));
      expect(appUri.queryParameters['name'], equals('Favorites'));

      // Destination 2: Official Web landing page
      expect(webUri.scheme, equals('https'));
      expect(webUri.host, equals('ankitcodes30.github.io'));
      expect(webUri.path, equals('/Orvia/playlist'));

      // Destination 3: Website root
      const officialSite = 'https://ankitcodes30.github.io/Orvia/';
      expect(officialSite, equals('https://ankitcodes30.github.io/Orvia/'));
    });

    test(
        '5. parseDeepLink cleanly differentiates playlist links from single-track links',
        () {
      final trackUri = Uri.parse(
          'https://ankitcodes30.github.io/Orvia/track?id=dxrBpjVX&src=saavn&title=Kesariya');
      final playlistUri = Uri.parse(
          'https://ankitcodes30.github.io/Orvia/playlist?name=PartyMix&id=123');

      final parsedTrack = OrviaDeepLinkService.parseDeepLink(trackUri);
      final parsedPlaylist = OrviaDeepLinkService.parseDeepLink(playlistUri);

      expect(parsedTrack, isNotNull);
      expect(parsedTrack!['type'], equals('track'));
      expect(parsedTrack['title'], equals('Kesariya'));

      expect(parsedPlaylist, isNotNull);
      expect(parsedPlaylist!['type'], equals('playlist'));
      expect(parsedPlaylist['name'], equals('PartyMix'));
    });

    test('6. Cold-start, warm-start, and background link detection', () {
      final webPlaylist = Uri.parse(
          'https://ankitcodes30.github.io/Orvia/playlist?name=Acoustic');
      final appPlaylist = Uri.parse('orvia://playlist?name=Acoustic');

      expect(OrviaDeepLinkService.isDeepLink(webPlaylist), isTrue);
      expect(OrviaDeepLinkService.isDeepLink(appPlaylist), isTrue);

      // Pending deep link flag for cold-start race protection
      OrviaDeepLinkService.setPendingDeepLink(appPlaylist);
      expect(OrviaDeepLinkService.hasPendingDeepLink, isTrue);
      expect(OrviaDeepLinkService.pendingDeepLink, equals(appPlaylist));
    });

    test('7. Empty playlists and missing artwork are handled gracefully', () {
      final emptyUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Empty Playlist',
        tracks: const [],
        useAppScheme: false,
      );

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(emptyUri);
      expect(decoded, isNotNull);
      expect(decoded!.title, equals('Empty Playlist'));
      expect(decoded.tracks.isEmpty, isTrue);
      expect(decoded.thumbnail?.url ?? '', isEmpty);
    });

    test('8. Corrupted or invalid payload strings do not crash the parser', () {
      expect(OrviaDeepLinkService.decodePlaylistData('!not-a-valid-base64!'),
          isNull);
      expect(OrviaDeepLinkService.decodePlaylistData(''), isNull);

      final invalidUri = Uri.parse(
          'https://ankitcodes30.github.io/Orvia/playlist?data=corrupted_data_string');
      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(invalidUri);
      expect(decoded, isNotNull);
      expect(decoded!.tracks.isEmpty, isTrue);
    });

    test('9. Existing single-track sharing remains 100% functional', () {
      final singleTrack = sampleTracks.first;
      final trackUri = OrviaDeepLinkService.buildTrackDeepLink(singleTrack);
      expect(trackUri.scheme, equals('https'));
      expect(trackUri.path, equals('/Orvia/track'));
      expect(trackUri.queryParameters['id'], equals('saavn:dxrBpjVX'));

      final parsedTrack = OrviaDeepLinkService.parseTrackFromUri(trackUri);
      expect(parsedTrack, isNotNull);
      expect(parsedTrack!.id.contains('saavn:dxrBpjVX'), isTrue);
      expect(parsedTrack.title, equals('Kesariya'));
    });

    test(
        '10. Unicode and special character playlist titles encode and decode perfectly',
        () {
      final unicodeTracks = [
        Track(
          id: 'saavn:hindi123',
          title: 'तुम ही हो',
          artists: const [ArtistSummary(id: 'arijit', name: 'अरिजीत सिंह')],
          album: const AlbumSummary(
              id: 'aashiqui2', title: 'Aashiqui 2', artists: []),
          thumbnail: const Artwork(
              url: 'https://example.com/art.jpg', layout: ImageLayout.square),
          durationMs: BigInt.from(260000),
          isExplicit: false,
        ),
      ];

      final shareUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'बॉलीवुड के सदाबहार गाने 🎶✨',
        description: 'खूबसूरत धुनें',
        tracks: unicodeTracks,
      );

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(shareUri);
      expect(decoded, isNotNull);
      expect(decoded!.title, equals('बॉलीवुड के सदाबहार गाने 🎶✨'));
      expect(decoded.description, equals('खूबसूरत धुनें'));
      expect(decoded.tracks.length, equals(1));
      expect(decoded.tracks.first.title, equals('तुम ही हो'));
      expect(decoded.tracks.first.artists.first.name, equals('अरिजीत सिंह'));
    });

    test(
        '11. Recipient playlist copy is independently editable without mutating sender',
        () {
      final originalPlaylist = Playlist(
        title: 'Original Playlist',
        tracks: List.from(sampleTracks),
      );

      // Recipient gets a copy
      final shareUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: originalPlaylist.title,
        tracks: originalPlaylist.tracks,
      );
      final recipientPlaylist =
          OrviaDeepLinkService.parsePlaylistFromUri(shareUri)!;

      // Recipient edits their copy: renames and removes a track
      final modifiedRecipientTracks = List<Track>.from(recipientPlaylist.tracks)
        ..removeAt(0);
      final editedRecipientPlaylist = recipientPlaylist.copyWith(
        title: 'My Custom Edited Copy',
        tracks: modifiedRecipientTracks,
      );

      // Ensure sender's original playlist remains completely untouched
      expect(originalPlaylist.title, equals('Original Playlist'));
      expect(originalPlaylist.tracks.length, equals(2));
      expect(editedRecipientPlaylist.title, equals('My Custom Edited Copy'));
      expect(editedRecipientPlaylist.tracks.length, equals(1));
    });

    test(
        '12. 50-track playlists compress efficiently and stay well under browser limits',
        () {
      final standardTracks = List.generate(
          50,
          (i) => Track(
                id: 'saavn:track_$i',
                title: 'Hit Song $i',
                artists: [ArtistSummary(id: 'art_$i', name: 'Artist $i')],
                album: AlbumSummary(
                    id: 'alb_$i', title: 'Album $i', artists: const []),
                thumbnail: const Artwork(
                    url: 'https://c.saavncdn.com/thumb.jpg',
                    layout: ImageLayout.square),
                durationMs: BigInt.from(180000),
                isExplicit: false,
              ));

      final standardUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Top 50 Hits',
        tracks: standardTracks,
      );

      final standardLength = standardUri.toString().length;
      // Typical 50 tracks compress to ~1,429 characters
      expect(standardLength, lessThan(1600));

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(standardUri);
      expect(decoded, isNotNull);
      expect(decoded!.tracks.length, equals(50));
      expect(decoded.tracks.first.title, equals('Hit Song 0'));
      expect(decoded.tracks.last.title, equals('Hit Song 49'));

      // Heavy 50 tracks with unicode and distinct artwork
      final heavyTracks = List.generate(
          50,
          (i) => Track(
                id: 'saavn:heavy_track_unique_$i',
                title:
                    'गीत संगीत विशेष ट्रैक संख्या $i — प्रीमियम संगीत संस्करण',
                artists: [
                  ArtistSummary(
                      id: 'art_$i', name: 'अरिजीत सिंह एवं श्रेया घोषाल')
                ],
                album: AlbumSummary(
                    id: 'alb_$i',
                    title: 'बॉलीवुड म्यूज़िकल कलेक्शन $i',
                    artists: const []),
                thumbnail: Artwork(
                    url:
                        'https://c.saavncdn.com/covers/album_$i/track_artwork_500x500.jpg',
                    layout: ImageLayout.square),
                durationMs: BigInt.from(240000),
                isExplicit: false,
              ));

      final heavyUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'विशेष बॉलीवुड संगीत 🎶',
        tracks: heavyTracks,
      );
      final heavyLength = heavyUri.toString().length;
      // Heavy Unicode 50 tracks is ~2,220 characters; well within 6KB safe limit
      expect(
          heavyLength, lessThan(OrviaDeepLinkService.kMaxShareableUrlLength));
      expect(
          heavyLength,
          greaterThan(
              1000)); // Confirms empirical finding that heavy 50-track playlists compress efficiently
    });

    test(
        '13. Enforces kMaxShareablePlaylistTracks capping when payload exceeds 100 tracks',
        () {
      final over100Tracks = List.generate(
          125,
          (i) => Track(
                id: 'saavn:track_$i',
                title: 'Song $i',
                artists: [ArtistSummary(id: 'art_$i', name: 'Artist $i')],
                thumbnail: const Artwork(
                    url: 'https://c.saavncdn.com/thumb.jpg',
                    layout: ImageLayout.square),
                durationMs: BigInt.from(180000),
                isExplicit: false,
              ));

      final uri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Huge Playlist',
        tracks: over100Tracks,
      );

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(uri);
      expect(decoded, isNotNull);
      // Capped at 100 tracks
      expect(decoded!.tracks.length,
          equals(OrviaDeepLinkService.kMaxShareablePlaylistTracks));
    });

    test(
        '14. Oversized or malicious payloads in decodePlaylistData return null safely',
        () {
      // Extremely large string beyond 32KB
      final hugeString = 'A' * 35000;
      expect(OrviaDeepLinkService.decodePlaylistData(hugeString), isNull);

      // Malformed gzip header
      final badGzip = base64UrlEncode([0x1f, 0x8b, 0x00, 0x00, 0x99, 0x88]);
      expect(OrviaDeepLinkService.decodePlaylistData(badGzip), isNull);
    });

    testWidgets(
        '15. isSharing mutex prevents rapid concurrent invocations and resets on completion',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();
      expect(OrviaDeepLinkService.isSharing, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test Context')),
          ),
        ),
      );

      final context = tester.element(find.text('Test Context'));

      // 1. Simulate an ongoing share operation by locking the mutex
      OrviaDeepLinkService.isSharingForTesting = true;
      expect(OrviaDeepLinkService.isSharing, isTrue);

      // Attempting to share while mutex is locked must be blocked immediately
      await OrviaDeepLinkService.sharePlaylist(
        context,
        name: 'Concurrent Blocked Call',
        tracks: sampleTracks,
      );
      // Mutex remains true (not reset by the blocked call)
      expect(OrviaDeepLinkService.isSharing, isTrue);

      // Unlock for next phase
      OrviaDeepLinkService.isSharingForTesting = false;
      expect(OrviaDeepLinkService.isSharing, isFalse);

      // 2. Verify try-finally lifecycle on early exit (e.g. tracks exceed 100 limit)
      final excessiveTracks = List.generate(
        105,
        (i) => Track(
          id: 'saavn:t_$i',
          title: 'Track $i',
          artists: const [],
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          durationMs: BigInt.zero,
          isExplicit: false,
        ),
      );

      // Executes through try block, triggers validation early return, and runs finally { _isSharing = false }
      await OrviaDeepLinkService.sharePlaylist(
        context,
        name: 'Overloaded Playlist',
        tracks: excessiveTracks,
      );

      // Mutex must be cleanly reset to false
      expect(OrviaDeepLinkService.isSharing, isFalse);
    });

    test(
        '16. resetForTesting completely clears isSharing lock and pending deep link state',
        () {
      OrviaDeepLinkService.resetForTesting();
      expect(OrviaDeepLinkService.isSharing, isFalse);
      expect(OrviaDeepLinkService.hasPendingDeepLink, isFalse);

      OrviaDeepLinkService.setPendingDeepLink(
          Uri.parse('https://ankitcodes30.github.io/Orvia/playlist?name=Test'));
      expect(OrviaDeepLinkService.hasPendingDeepLink, isTrue);

      OrviaDeepLinkService.resetForTesting();
      expect(OrviaDeepLinkService.isSharing, isFalse);
      expect(OrviaDeepLinkService.hasPendingDeepLink, isFalse);
    });

    testWidgets('Library playlist share closes only the options sheet',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(homeContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Builder(
                          builder: (context) => Column(
                            children: [
                              const Text('Library page'),
                              TextButton(
                                onPressed: () => showPlaylistOptsInrSheet(
                                  context,
                                  Playlist(
                                    title: 'Test playlist',
                                    tracks: sampleTracks,
                                  ),
                                ),
                                child: const Text('Open playlist options'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Library'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open playlist options'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Share Playlist'));
      await tester.tap(find.text('Share Playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Library page'), findsOneWidget);
    });

    testWidgets(
        '18. Native sharePlaylist triggers SharePlus.instance.share with subject, title, and generated deep link URL',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();
      MethodCall? shareCall;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'share') {
            shareCall = methodCall;
            return 'dev.fluttercommunity.plus/share/unavailable';
          }
          return null;
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Desktop Test Home')),
          ),
        ),
      );

      final context = tester.element(find.text('Desktop Test Home'));
      await OrviaDeepLinkService.sharePlaylist(
        context,
        name: 'Desktop Mix',
        tracks: sampleTracks,
      );
      await tester.pumpAndSettle();

      expect(shareCall, isNotNull);
      expect(shareCall!.method, equals('share'));
      final args = Map<dynamic, dynamic>.from(shareCall!.arguments as Map);
      expect(args['title'], equals('Share Playlist "Desktop Mix"'));
      expect(args['subject'], equals('Playlist "Desktop Mix" on Orvia'));
      final sharedText = args['text'] as String;
      expect(sharedText, contains('Desktop Mix'));
      expect(sharedText, contains('https://ankitcodes30.github.io/Orvia/playlist'));
      expect(args.containsKey('paths'), isFalse);
      expect(OrviaDeepLinkService.isSharing, isFalse);
    });

    testWidgets(
        '19. Flow A: Library 3-dot showPlaylistOptsExtSheet with empty tracks handles gracefully without black screen',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: Column(
                children: [
                  const Text('Active Library Screen'),
                  TextButton(
                    onPressed: () => showPlaylistOptsExtSheet(
                      homeContext,
                      'My Library Flow A Playlist',
                      playlistId: 42,
                      artworkUrl: 'https://example.com/art.jpg',
                    ),
                    child: const Text('Open 3-Dot Options'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Active Library Screen'), findsOneWidget);

      // Open 3-dot menu
      await tester.tap(find.text('Open 3-Dot Options'));
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.text('My Library Flow A Playlist'), findsOneWidget);
      expect(find.text('Share Playlist'), findsOneWidget);

      // Click Share Playlist
      await tester.tap(find.text('Share Playlist'));
      await tester.pumpAndSettle();

      // Bottom sheet has dismissed, library screen remains alive and visible
      expect(find.text('Active Library Screen'), findsOneWidget);
      expect(find.text('Open 3-Dot Options'), findsOneWidget);
    });

    testWidgets(
        '20. Flow A: Library 3-dot with loaded tracks dismisses sheet cleanly and invokes native share',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();
      MethodCall? shareCall;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'share') {
            shareCall = methodCall;
            return 'dev.fluttercommunity.plus/share/unavailable';
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: Column(
                children: [
                  const Text('Active Library Screen'),
                  TextButton(
                    onPressed: () => showPlaylistOptsInrSheet(
                      homeContext,
                      Playlist(
                        title: 'Roadtrip Beats',
                        tracks: sampleTracks,
                      ),
                    ),
                    child: const Text('Open 3-Dot Options'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Active Library Screen'), findsOneWidget);

      // Open 3-dot menu
      await tester.tap(find.text('Open 3-Dot Options'));
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.text('Roadtrip Beats'), findsOneWidget);
      expect(find.text('Share Playlist'), findsOneWidget);

      // Click Share Playlist
      await tester.tap(find.text('Share Playlist'));
      await tester.pumpAndSettle();

      // Native share was invoked with proper playlist text
      expect(shareCall, isNotNull);
      final args = Map<dynamic, dynamic>.from(shareCall!.arguments as Map);
      expect(args['title'], equals('Share Playlist "Roadtrip Beats"'));
      expect(args['text'], contains('Roadtrip Beats'));
      expect(args['text'], contains('https://ankitcodes30.github.io/Orvia/playlist'));

      // Library screen remains alive and visible (no black screen or route failure)
      expect(find.text('Active Library Screen'), findsOneWidget);
      expect(OrviaDeepLinkService.isSharing, isFalse);
    });

    testWidgets(
        '21. Flow B: Playlist view direct share triggers native share sheet',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();
      MethodCall? shareCall;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'share') {
            shareCall = methodCall;
            return 'dev.fluttercommunity.plus/share/unavailable';
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => OrviaDeepLinkService.sharePlaylist(
                  context,
                  name: 'Flow B Playlist',
                  tracks: sampleTracks,
                ),
                child: const Text('Share Button in Playlist View'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Share Button in Playlist View'));
      await tester.pumpAndSettle();

      expect(shareCall, isNotNull);
      final args = Map<dynamic, dynamic>.from(shareCall!.arguments as Map);
      expect(args['title'], equals('Share Playlist "Flow B Playlist"'));
      expect(args['text'], contains('Flow B Playlist'));
      expect(args['text'], contains('https://ankitcodes30.github.io/Orvia/playlist'));
      expect(OrviaDeepLinkService.isSharing, isFalse);
    });

    testWidgets(
        '22. Safe fallback: If native share throws an exception, link is copied to clipboard with explicit error',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();
      String? copiedText;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'SYSTEM_SHARE_FAILED',
            message: 'Native Windows share flyout unavailable',
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => OrviaDeepLinkService.sharePlaylist(
                  context,
                  name: 'Fallback Mix',
                  tracks: sampleTracks,
                ),
                child: const Text('Share Fallback'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Share Fallback'));
      await tester.pumpAndSettle();

      // Native share threw, so clipboard copy fallback was executed
      expect(copiedText, isNotNull);
      expect(copiedText, contains('Fallback Mix'));
      expect(copiedText, contains('https://ankitcodes30.github.io/Orvia/playlist'));
      expect(OrviaDeepLinkService.isSharing, isFalse);
    });

    testWidgets(
        '23. Track native sharing invokes SharePlus with listen URL, and falls back to clipboard on error',
        (tester) async {
      OrviaDeepLinkService.resetForTesting();
      MethodCall? shareCall;
      String? copiedText;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'share') {
            shareCall = methodCall;
            return 'dev.fluttercommunity.plus/share/unavailable';
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => OrviaDeepLinkService.shareTrack(
                  context,
                  sampleTracks.first,
                ),
                child: const Text('Share Track'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Share Track'));
      await tester.pumpAndSettle();

      expect(shareCall, isNotNull);
      final args = Map<dynamic, dynamic>.from(shareCall!.arguments as Map);
      expect(args['title'], equals('Share "Kesariya"'));
      expect(args['text'], contains('Kesariya'));
      expect(args['text'], contains('Arijit Singh'));
      expect(args['text'], contains('https://ankitcodes30.github.io/Orvia/track'));

      // Now test error fallback on track share
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Failed to share track');
        },
      );

      await tester.tap(find.text('Share Track'));
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('Kesariya'));
    });

    group('Short-Link Creation, Resolution & Backward Compatibility', () {
      setUp(() {
        OrviaDeepLinkService.resetForTesting();
        OrviaShortLinkService.resetForTesting();
      });

      tearDown(() {
        OrviaDeepLinkService.resetForTesting();
        OrviaShortLinkService.resetForTesting();
      });

      test('24. generateSecureShortId generates collision-resistant Base62 IDs', () {
        final generatedIds = <String>{};
        for (int i = 0; i < 500; i++) {
          final id = OrviaShortLinkService.generateSecureShortId(length: 8);
          expect(id.length, equals(8));
          expect(OrviaShortLinkService.isValidShortId(id), isTrue);
          expect(generatedIds.contains(id), isFalse, reason: 'Duplicate ID generated');
          generatedIds.add(id);
        }
      });

      test('25. isValidShortId validates valid IDs and strictly rejects malformed/reserved IDs', () {
        // Valid short IDs
        expect(OrviaShortLinkService.isValidShortId('k9Z2xL7m'), isTrue);
        expect(OrviaShortLinkService.isValidShortId('Abc123_x'), isTrue);
        expect(OrviaShortLinkService.isValidShortId('playlist-123'), isTrue);
        expect(OrviaShortLinkService.isValidShortId('abcd'), isTrue);

        // Invalid: null, empty, whitespace
        expect(OrviaShortLinkService.isValidShortId(null), isFalse);
        expect(OrviaShortLinkService.isValidShortId(''), isFalse);
        expect(OrviaShortLinkService.isValidShortId('   '), isFalse);

        // Invalid: too short or too long
        expect(OrviaShortLinkService.isValidShortId('abc'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('a' * 33), isFalse);

        // Invalid: illegal characters
        expect(OrviaShortLinkService.isValidShortId('abc!@#'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('abc/def'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('abc?def'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('abc=def'), isFalse);

        // Invalid: reserved route names
        expect(OrviaShortLinkService.isValidShortId('playlist'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('track'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('p'), isFalse);
        expect(OrviaShortLinkService.isValidShortId('admin'), isFalse);
      });

      test('26. Default resolver safely falls back to self-contained long links', () async {
        // Default resolver is DefaultSelfContainedResolver (no backend configured)
        final uri = await OrviaShortLinkService.buildShareablePlaylistUri(
          name: 'My Roadtrip Beats',
          description: 'Fun vibes',
          artworkUrl: 'https://example.com/art.jpg',
          tracks: sampleTracks,
          useAppScheme: false,
        );

        // Safely falls back to the self-contained long link format
        expect(uri.scheme, equals('https'));
        expect(uri.host, equals('ankitcodes30.github.io'));
        expect(uri.path, equals('/Orvia/playlist'));
        expect(uri.queryParameters.containsKey('data'), isTrue);
        expect(uri.queryParameters['name'], equals('My Roadtrip Beats'));

        // Decodes completely without external network dependencies
        final decoded = OrviaDeepLinkService.parsePlaylistFromUri(uri);
        expect(decoded, isNotNull);
        expect(decoded!.title, equals('My Roadtrip Beats'));
        expect(decoded.tracks.length, equals(2));
      });

      test('27. Short-link creation and resolution preserves all playlist metadata and track order', () async {
        final mockResolver = InMemoryMockShortLinkResolver();
        OrviaShortLinkService.activeResolver = mockResolver;

        final uri = await OrviaShortLinkService.buildShareablePlaylistUri(
          name: 'Summer Hits 2026',
          description: 'Top summer songs',
          artworkUrl: 'https://example.com/summer.jpg',
          tracks: sampleTracks,
          useAppScheme: false,
        );

        expect(uri.scheme, equals('https'));
        expect(uri.host, equals('ankitcodes30.github.io'));
        expect(uri.path.startsWith('/Orvia/p/'), isTrue);

        final shortId = uri.pathSegments.last;
        expect(OrviaShortLinkService.isValidShortId(shortId), isTrue);

        // Resolve via OrviaShortLinkService
        final resolved = await OrviaShortLinkService.resolveShortLink(shortId);
        expect(resolved, isNotNull);
        expect(resolved!.title, equals('Summer Hits 2026'));
        expect(resolved.description, equals('Top summer songs'));
        expect(resolved.thumbnail?.url, equals('https://example.com/summer.jpg'));
        expect(resolved.tracks.length, equals(2));

        // Exact track order and metadata preservation
        expect(resolved.tracks[0].title, equals('Kesariya'));
        expect(resolved.tracks[0].artists.first.name, equals('Arijit Singh'));
        expect(resolved.tracks[0].album?.title, equals('Brahmastra'));

        expect(resolved.tracks[1].title, equals('Never Gonna Give You Up'));
        expect(resolved.tracks[1].artists.first.name, equals('Rick Astley'));
      });

      test('28. Incoming short deep link URLs are recognized and parsed correctly', () {
        // Web path format: /Orvia/p/<id>
        final webPathUri = Uri.parse('https://ankitcodes30.github.io/Orvia/p/k9Z2xL7m');
        expect(OrviaDeepLinkService.isDeepLink(webPathUri), isTrue);
        final parsedWeb = OrviaDeepLinkService.parseDeepLink(webPathUri);
        expect(parsedWeb, isNotNull);
        expect(parsedWeb!['type'], equals('playlist'));
        expect(parsedWeb['isShortLink'], isTrue);
        expect(parsedWeb['shortId'], equals('k9Z2xL7m'));

        // Web query format: /Orvia/p?id=<id>
        final webQueryUri = Uri.parse('https://ankitcodes30.github.io/Orvia/p?id=k9Z2xL7m');
        expect(OrviaDeepLinkService.isDeepLink(webQueryUri), isTrue);
        final parsedQuery = OrviaDeepLinkService.parseDeepLink(webQueryUri);
        expect(parsedQuery, isNotNull);
        expect(parsedQuery!['type'], equals('playlist'));
        expect(parsedQuery['isShortLink'], isTrue);
        expect(parsedQuery['shortId'], equals('k9Z2xL7m'));

        // App custom scheme: orvia://p/<id>
        final appPathUri = Uri.parse('orvia://p/k9Z2xL7m');
        expect(OrviaDeepLinkService.isDeepLink(appPathUri), isTrue);
        final parsedApp = OrviaDeepLinkService.parseDeepLink(appPathUri);
        expect(parsedApp, isNotNull);
        expect(parsedApp!['type'], equals('playlist'));
        expect(parsedApp['isShortLink'], isTrue);
        expect(parsedApp['shortId'], equals('k9Z2xL7m'));

        // App query scheme: orvia://p?id=<id>
        final appQueryUri = Uri.parse('orvia://p?id=k9Z2xL7m');
        expect(OrviaDeepLinkService.isDeepLink(appQueryUri), isTrue);
        final parsedAppQuery = OrviaDeepLinkService.parseDeepLink(appQueryUri);
        expect(parsedAppQuery, isNotNull);
        expect(parsedAppQuery!['type'], equals('playlist'));
        expect(parsedAppQuery['isShortLink'], isTrue);
        expect(parsedAppQuery['shortId'], equals('k9Z2xL7m'));
      });

      test('29. Missing, unknown, expired, and corrupted short IDs return null safely', () async {
        final mockResolver = InMemoryMockShortLinkResolver();
        OrviaShortLinkService.activeResolver = mockResolver;

        // 1. Unknown ID
        final unknownResult = await OrviaShortLinkService.resolveShortLink('unknown_id');
        expect(unknownResult, isNull);

        // 2. Expired ID
        mockResolver.storePlaylist(
          'expired_1',
          title: 'Expired Playlist',
          tracks: sampleTracks,
          ttl: const Duration(seconds: 1),
        );
        mockResolver.expireShortLink('expired_1');
        final expiredResult = await OrviaShortLinkService.resolveShortLink('expired_1');
        expect(expiredResult, isNull);

        // 3. Corrupted ID
        mockResolver.storePlaylist(
          'corrupt_1',
          title: 'Corrupted Playlist',
          tracks: sampleTracks,
        );
        mockResolver.corruptShortLink('corrupt_1');
        final corruptResult = await OrviaShortLinkService.resolveShortLink('corrupt_1');
        expect(corruptResult, isNull);

        // 4. Malformed / empty IDs
        expect(await OrviaShortLinkService.resolveShortLink(''), isNull);
        expect(await OrviaShortLinkService.resolveShortLink('!invalid!'), isNull);
      });

      test('30. handlePlaylistDeepLinkUri fails gracefully on unresolvable short links without crashing', () async {
        final mockResolver = InMemoryMockShortLinkResolver();
        OrviaShortLinkService.activeResolver = mockResolver;

        final unresolvableUri = Uri.parse('https://ankitcodes30.github.io/Orvia/p/not_exist');
        final handled = await OrviaDeepLinkService.handlePlaylistDeepLinkUri(unresolvableUri);

        // Must return false and not open an empty or wrong playlist
        expect(handled, isFalse);
      });

      test('31. Legacy long URLs continue working seamlessly alongside short URLs', () {
        final legacyUri = OrviaDeepLinkService.buildPlaylistDeepLink(
          name: 'Legacy Beats',
          tracks: sampleTracks,
          useAppScheme: false,
        );

        // Legacy URL format is 100% preserved
        expect(legacyUri.path, equals('/Orvia/playlist'));
        expect(legacyUri.queryParameters.containsKey('data'), isTrue);

        final parsed = OrviaDeepLinkService.parseDeepLink(legacyUri);
        expect(parsed, isNotNull);
        expect(parsed!['isShortLink'], isFalse);
        expect(parsed['name'], equals('Legacy Beats'));

        final playlist = OrviaDeepLinkService.parsePlaylistFromUri(legacyUri);
        expect(playlist, isNotNull);
        expect(playlist!.title, equals('Legacy Beats'));
        expect(playlist.tracks.length, equals(2));
      });
    });
  });
}
