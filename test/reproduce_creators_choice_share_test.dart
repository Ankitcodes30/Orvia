import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';

void main() {
  group("Creator's Choice & Playlist Sharing Regression Verification", () {
    test("1. Sender-side Creator's Choice has 70 verified tracks and expected metadata", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      expect(tracks.length, equals(70));
      expect(CreatorsChoiceService.playlistName, equals("Creator's Choice"));
      expect(CreatorsChoiceService.playlistDescription, contains("70 curated melodies"));
      
      // Verify first and last track metadata
      expect(tracks.first.title, equals('Naino Ne Baandhi'));
      expect(tracks.first.artists.first.name, equals('Yasser Desai, Arko'));
      expect(tracks.first.id, equals('content-resolver.bloomfactory.jisaavn::GQlvs79S'));
      expect(tracks.last.title, contains('DARKHAAST'));
      expect(tracks.last.id, equals('content-resolver.bloomfactory.ytvideo::LMnJp_dSdnw'));
    });

    test("2. Generated share URL is valid, within size limits, and contains compact v2 payload", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      final uri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: CreatorsChoiceService.playlistName,
        description: CreatorsChoiceService.playlistDescription,
        tracks: tracks,
        artworkUrl: tracks.first.thumbnail.url,
        useAppScheme: false,
      );

      final urlStr = uri.toString();
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('ankitcodes30.github.io'));
      expect(uri.path, equals('/Orvia/playlist'));
      expect(uri.queryParameters['name'], equals("Creator's Choice"));
      expect(uri.queryParameters.containsKey('data'), isTrue);
      
      final dataB64 = uri.queryParameters['data']!;
      final decodedMap = OrviaDeepLinkService.decodePlaylistData(dataB64);
      expect(decodedMap, isNotNull);
      expect(decodedMap!['v'], equals(2));
      expect(decodedMap['tr'], isA<List>());
      expect((decodedMap['tr'] as List).first, isA<List>());

      // Assert link length is reduced and within limits
      // URL length is within max shareable URL length
      expect(urlStr.length, lessThan(7000));
    });

    test("3. Recipient reconstructs all 70 tracks, correct order, and valid playable IDs", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      final uri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: CreatorsChoiceService.playlistName,
        description: CreatorsChoiceService.playlistDescription,
        tracks: tracks,
        artworkUrl: tracks.first.thumbnail.url,
        useAppScheme: false,
      );

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(uri);
      expect(decoded, isNotNull);
      expect(decoded!.title, equals("Creator's Choice"));
      expect(decoded.description, equals(CreatorsChoiceService.playlistDescription));
      expect(decoded.tracks.length, equals(70));

      // Verify song order, identity, and artwork preservation
      for (int i = 0; i < tracks.length; i++) {
        expect(decoded.tracks[i].title, equals(tracks[i].title));
        expect(decoded.tracks[i].id, equals(tracks[i].id));
        expect(decoded.tracks[i].thumbnail.url, equals(tracks[i].thumbnail.url));
        expect(decoded.tracks[i].artists.first.name, equals(tracks[i].artists.first.name));
      }
    });

    test("3b. Legacy v1 payloads decode with 100% backward compatibility", () {
      // Test direct v1 map parsing through decodePlaylistData/parsePlaylistFromUri
      final uri = Uri.parse(
        'https://ankitcodes30.github.io/Orvia/playlist?name=Creator%27s+Choice',
      );
      // Construct a simulated legacy v1 payload
      final legacyTracks = CreatorsChoiceService.getVerifiedTracks();
      final legacyPayload = {
        'v': 1,
        't': "Creator's Choice",
        'd': "Legacy v1 test",
        'art': legacyTracks.first.thumbnail.url,
        'tr': legacyTracks.map((t) => {
          'id': t.id,
          't': t.title,
          'a': t.artists.first.name,
          'al': t.album?.title ?? '',
          'th': t.thumbnail.url,
        }).toList(),
      };
      final jsonStr = jsonEncode(legacyPayload);
      final compressed = GZipCodec(level: 9).encode(utf8.encode(jsonStr));
      final legacyB64 = base64UrlEncode(compressed).replaceAll('=', '');

      final legacyUri = uri.replace(queryParameters: {
        'name': "Creator's Choice",
        'data': legacyB64,
      });

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(legacyUri);
      expect(decoded, isNotNull);
      expect(decoded!.tracks.length, equals(70));
      expect(decoded.tracks.first.title, equals(legacyTracks.first.title));
      expect(decoded.tracks.first.thumbnail.url, equals(legacyTracks.first.thumbnail.url));
      expect(decoded.tracks.last.title, equals(legacyTracks.last.title));
      expect(decoded.tracks.last.thumbnail.url, equals(legacyTracks.last.thumbnail.url));
    });

    test("4. Truncated payload recovers safely with partial notice and avoids empty playlist", () {
      final fileStr = File('full_url.txt').readAsStringSync().trim().replaceAll('`', '');
      final truncatedUri = Uri.parse(fileStr);

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(truncatedUri);
      expect(decoded, isNotNull);
      expect(decoded!.title, equals("Creator's Choice"));
      expect(decoded.description, contains('Partially recovered'));
      // Exactly 39 tracks were complete before truncation in full_url.txt
      expect(decoded.tracks.length, equals(39));
      expect(decoded.tracks.first.title, equals('Naino Ne Baandhi'));
      expect(decoded.tracks.last.title, equals('Vaaroon Forever (From “Mirzapur The Movie”)'));
    });

    test("5. Empty playlist edge case without data is handled safely", () {
      final uri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Empty Playlist',
        tracks: [],
        useAppScheme: false,
      );

      expect(uri.queryParameters.containsKey('data'), isFalse);
      expect(uri.queryParameters['name'], equals('Empty Playlist'));

      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(uri);
      expect(decoded, isNotNull);
      expect(decoded!.tracks.isEmpty, isTrue);
    });

    test("6. Corrupted payload decoding safely returns null from decodePlaylistData and empty playlist from URI parser", () {
      final corrupted = OrviaDeepLinkService.decodePlaylistData('CorruptedDataString123');
      expect(corrupted, isNull);

      final corruptedUri = Uri.parse(
        'https://ankitcodes30.github.io/Orvia/playlist?name=Corrupted&data=CorruptedDataString123',
      );
      final decoded = OrviaDeepLinkService.parsePlaylistFromUri(corruptedUri);
      expect(decoded, isNotNull);
      expect(decoded!.tracks.isEmpty, isTrue);
    });

    test("7. Single song sharing remains untouched and resolves properly", () {
      final track = CreatorsChoiceService.getVerifiedTracks().first;
      final uri = OrviaDeepLinkService.buildTrackDeepLink(track, useAppScheme: false);
      expect(uri.path, equals('/Orvia/track'));
      
      final parsed = OrviaDeepLinkService.parseTrackFromUri(uri);
      expect(parsed, isNotNull);
      expect(parsed!.title, equals(track.title));
      expect(parsed.id, equals(track.id));
    });

    test("8. Cold-start and warm-start deduplication guard works as expected", () async {
      OrviaDeepLinkService.resetForTesting();
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      final uri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: CreatorsChoiceService.playlistName,
        tracks: tracks,
        useAppScheme: true,
      );

      OrviaDeepLinkService.setPendingDeepLink(uri);
      expect(OrviaDeepLinkService.hasPendingDeepLink, isTrue);
      expect(OrviaDeepLinkService.hasHandledColdStartDeepLink, isTrue);

      OrviaDeepLinkService.clearPendingDeepLink();
      expect(OrviaDeepLinkService.hasPendingDeepLink, isFalse);
    });
  });
}
