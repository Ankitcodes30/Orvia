import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/screens/widgets/curated_playlists_section.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 — Curated Playlists & Festive Content Verification', () {
    // -------------------------------------------------------------
    // 1. BOLLYWOOD HITS
    // -------------------------------------------------------------
    test('Bollywood Hits contains exactly 20 verified playable tracks', () {
      final tracks = CuratedPlaylistsService.getBollywoodTracks();
      expect(tracks.length, equals(20));

      final seenIds = <String>{};
      for (final t in tracks) {
        expect(isStampedId(t.id), isTrue, reason: 'ID must be composite: ${t.id}');
        expect(pluginIdOf(t.id), equals(kDefaultSaavnPluginId));
        expect(t.title, isNotEmpty);
        expect(t.artists, isNotEmpty);
        expect(t.album?.title, isNotEmpty);
        expect((t.durationMs ?? BigInt.zero) > BigInt.zero, isTrue);
        expect(t.thumbnail.url, isNotEmpty);
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
      }

      // Check key audit candidate tracks are present
      final titles = tracks.map((t) => t.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('bom diggy')), isTrue);
      expect(titles.any((t) => t.contains('party shuru')), isTrue);
      expect(titles.any((t) => t.contains('teri baaton')), isTrue);
      expect(titles.any((t) => t.contains('chammak challo')), isTrue);
      expect(titles.any((t) => t.contains('dilbar')), isTrue);
      expect(titles.any((t) => t.contains('mere mehboob')), isTrue);
      expect(titles.any((t) => t.contains('gali gali')), isTrue);
      expect(titles.any((t) => t.contains('chittiyaan kalaiyaan')), isTrue);
      expect(titles.any((t) => t.contains('payal')), isTrue);
      expect(titles.any((t) => t.contains('millionaire')), isTrue);
      expect(titles.any((t) => t.contains('baby doll')), isTrue);
      expect(titles.any((t) => t.contains('munni badnaam')), isTrue);
      expect(titles.any((t) => t.contains('fevicol se')), isTrue);
      expect(titles.any((t) => t.contains('mauja hi mauja')), isTrue);
    });

    // -------------------------------------------------------------
    // 2. MARATHI HITS
    // -------------------------------------------------------------
    test('Marathi Hits contains verified tracks with authentic metadata and zero duplicates', () {
      final tracks = CuratedPlaylistsService.getMarathiTracks();
      expect(tracks.length, greaterThanOrEqualTo(15));

      final seenIds = <String>{};
      for (final t in tracks) {
        expect(isStampedId(t.id), isTrue, reason: 'ID must be composite: ${t.id}');
        expect(pluginIdOf(t.id), equals(kDefaultSaavnPluginId));
        expect(t.title, isNotEmpty);
        expect(t.artists, isNotEmpty);
        expect((t.durationMs ?? BigInt.zero) > BigInt.zero, isTrue);
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
      }

      final titles = tracks.map((t) => t.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('zingaat')), isTrue);
      expect(titles.any((t) => t.contains('gulabi sadi')), isTrue);
      expect(titles.any((t) => t.contains('aika dajiba')), isTrue);
      expect(titles.any((t) => t.contains('sairat zaala ji')), isTrue);
      expect(titles.any((t) => t.contains('kombadi palali')), isTrue);
      expect(titles.any((t) => t.contains('apsara aali')), isTrue);
    });

    // -------------------------------------------------------------
    // 3. INSTRUMENTAL
    // -------------------------------------------------------------
    test('Instrumental Hits contains genuine instrumental recordings and covers', () {
      final tracks = CuratedPlaylistsService.getInstrumentalTracks();
      expect(tracks.length, greaterThanOrEqualTo(12));

      final seenIds = <String>{};
      for (final t in tracks) {
        expect(isStampedId(t.id), isTrue, reason: 'ID must be composite: ${t.id}');
        expect(pluginIdOf(t.id), equals(kDefaultSaavnPluginId));
        expect(t.title, isNotEmpty);
        expect((t.durationMs ?? BigInt.zero) > BigInt.zero, isTrue);
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');

        // Must be genuinely instrumental or cover
        final text = '${t.title} ${t.artists.first.name} ${t.album?.title ?? ""}'.toLowerCase();
        final isInstrumental = text.contains('instrumental') ||
            text.contains('flute') ||
            text.contains('saxophone') ||
            text.contains('sitar') ||
            text.contains('guitar') ||
            text.contains('tabun sutradhar');
        expect(isInstrumental, isTrue, reason: 'Track is not instrumental: ${t.title}');
      }
    });

    // -------------------------------------------------------------
    // 3.B. A.K. MUSIC WORLD VERIFIED INSTRUMENTALS
    // -------------------------------------------------------------
    test('A.K. MUSIC WORLD catalogue contains all 12 verified channel uploads and excludes 404s', () {
      final tracks = CuratedPlaylistsService.getAkMusicWorldTracks();
      expect(tracks.length, equals(12));

      final ids = tracks.map((t) => t.id).toList();
      final expected12VideoIds = [
        'Ha5QlyycMhM',
        'OoOpaG0aoVM',
        'gWb64Q6HX40',
        'N5PRDOKqSUs',
        'MNhJ6obZvh8',
        'ZhmqU8jjgDY',
        'VVUJbVzVosY',
        'v8M12-G3jFc',
        'Pt-DdBr3anQ',
        'oYVgw3xGiaU',
        'SkBKlP4eOBk',
        'O9qpGTKEsYw',
      ];
      final invalid7VideoIds = [
        'uDgbCq4Wq14',
        '2wU-9m-qWzU',
        'hQkM-R0WwX0',
        'qV4b5WbS_vY',
        '9YqW_QZ4X78',
        '6y0t_bY7dKw',
        'wQ4bWzY-q8A',
      ];

      // Assert all 12 recovered video IDs are present exactly once
      for (final vid in expected12VideoIds) {
        expect(ids.where((id) => id.contains(vid)).length, equals(1),
            reason: 'Expected $vid to be present exactly once');
      }

      // Assert the 7 invalid IDs are absent
      for (final vid in invalid7VideoIds) {
        expect(ids.any((id) => id.contains(vid)), isFalse,
            reason: 'Invalid 404 video ID $vid must be absent');
      }

      // Assert Ha5QlyycMhM has the corrected title
      final harShambhu = tracks.firstWhere((t) => t.id.contains('Ha5QlyycMhM'));
      expect(harShambhu.title, contains('Har Shambhu song on piano'));
      expect(harShambhu.title, contains('हर हर शंभू'));
      expect(harShambhu.artists.first.name, equals('A.K. MUSIC WORLD'));

      final kgfTheme = tracks.firstWhere((t) => t.id.contains('N5PRDOKqSUs'));
      expect(
        kgfTheme.title,
        equals(
          'KGF Theme music Official || KGF: :BGM on Piano by A.K. MUSIC WORLD || Yash || KGF: :BGM Tutorial ||',
        ),
      );
      expect(kgfTheme.url, equals('https://www.youtube.com/watch?v=N5PRDOKqSUs'));
      expect(
        kgfTheme.thumbnail.url,
        equals('https://i.ytimg.com/vi/N5PRDOKqSUs/hqdefault.jpg'),
      );
    });

    // -------------------------------------------------------------
    // 4. NAVRATRI SPECIAL APPENDS
    // -------------------------------------------------------------
    test('Navratri Special preserves existing tracks and appends Navlakhay & Pankhida', () {
      final allNavratri = kVerifiedNavratriTracks;
      expect(allNavratri.length, greaterThanOrEqualTo(12));

      final ids = allNavratri.map((e) => e.track.id).toList();
      // Ensure deduplication
      expect(ids.toSet().length, equals(ids.length), reason: 'Duplicate Navratri track IDs found');

      // Pre-existing tracks must be preserved
      final titles = allNavratri.map((e) => e.track.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('tari madh mithi')), isTrue);
      expect(titles.any((t) => t.contains('chogada')), isTrue);
      expect(titles.any((t) => t.contains('dholida')), isTrue);

      // Appended tracks must be present with accurate artist & composite IDs
      final navlakhay = allNavratri.firstWhere(
        (e) => e.track.title.toLowerCase().contains('navalakhay'),
      );
      expect(navlakhay.track.id, equals('$kDefaultSaavnPluginId::l-BQ1Ljo'));
      expect(navlakhay.track.artists.first.name.toLowerCase().contains('kirtidan'), isTrue);

      final pankhida = allNavratri.firstWhere(
        (e) => e.track.title.toLowerCase().contains('pankhida'),
      );
      expect(pankhida.track.id, equals('$kDefaultSaavnPluginId::5wp2uev3'));
      expect(pankhida.track.artists.first.name.toLowerCase().contains('rajesh mishra'), isTrue);
    });

    // -------------------------------------------------------------
    // 5. BHAKTI / DEVOTIONAL APPENDS
    // -------------------------------------------------------------
    test('Bhakti collection preserves structure and appends verified sacred tracks', () {
      final bhaktiTracks = kVerifiedBhaktiTracks;
      expect(bhaktiTracks.length, equals(8));

      final ids = bhaktiTracks.map((t) => t.id).toList();
      expect(ids.toSet().length, equals(ids.length), reason: 'Duplicate Bhakti track IDs found');

      for (final t in bhaktiTracks) {
        expect(isStampedId(t.id), isTrue);
        expect(pluginIdOf(t.id), equals(kDefaultSaavnPluginId));
      }

      final titles = bhaktiTracks.map((t) => t.title.toLowerCase()).toList();
      final artists = bhaktiTracks.map((t) => t.artists.first.name.toLowerCase()).toList();

      // Lakhbir Singh Lakkha matches
      expect(titles.any((t) => t.contains('pyara saja hai')), isTrue);
      expect(titles.any((t) => t.contains('mann ki muradein')), isTrue);
      expect(titles.any((t) => t.contains('maiya ka chola')), isTrue);
      expect(artists.any((a) => a.contains('lakkha')), isTrue);

      // Suresh Wadkar match
      expect(titles.any((t) => t.contains('pooja ki thali')), isTrue);
      expect(artists.any((a) => a.contains('suresh wadkar')), isTrue);

      // Satyam Toriya match
      expect(titles.any((t) => t.contains('path rakho meri maa')), isTrue);
      expect(artists.any((a) => a.contains('satyam toriya')), isTrue);

      // Subhash Soni match
      expect(titles.any((t) => t.contains('chali aa rahi')), isTrue);
      expect(artists.any((a) => a.contains('subhash soni')), isTrue);

      // Rakesh Tiwari match
      expect(titles.any((t) => t.contains('karein bhagat')), isTrue);
      expect(artists.any((a) => a.contains('rakesh tiwari')), isTrue);

      // Manish Agarwal match
      expect(titles.any((t) => t.contains('kalo ki kaal mahakali')), isTrue);
      expect(artists.any((a) => a.contains('manish agrawal')), isTrue);
    });

    // -------------------------------------------------------------
    // 6. DEDUPLICATION LOGIC
    // -------------------------------------------------------------
    test('CuratedPlaylistsService.deduplicate safely removes duplicate track instances', () {
      final sampleTracks = CuratedPlaylistsService.getBollywoodTracks().take(3).toList();
      // Add duplicates
      final duplicatedList = [...sampleTracks, ...sampleTracks, sampleTracks.first];
      expect(duplicatedList.length, equals(7));

      final deduplicated = CuratedPlaylistsService.deduplicate(duplicatedList);
      expect(deduplicated.length, equals(3));
      expect(deduplicated.map((t) => t.id).toSet().length, equals(3));
    });

    // -------------------------------------------------------------
    // 7. COMPACT UI & EXPANSION
    // -------------------------------------------------------------
    testWidgets('CuratedPlaylistsSection renders compact initial limit and expands on Show more',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CuratedPlaylistsSection(
                pluginId: kDefaultSaavnPluginId,
                tileBuilder: (context, track, index, onTap) {
                  return SizedBox(
                    height: 48,
                    child: Text(track.title),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify title & tab chips
      expect(find.text('Curated Playlists'), findsOneWidget);
      expect(find.text('Bollywood Hits (20)'), findsOneWidget);
      expect(find.text('Marathi Hits (18)'), findsOneWidget);
      expect(find.text('Instrumental (18)'), findsOneWidget);

      // Compact initial limit: should show "Show more (16 more)"
      final showMoreFinder = find.textContaining('Show more (16 more)');
      expect(showMoreFinder, findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      // Tap Show more with ensureVisible
      await tester.ensureVisible(showMoreFinder);
      await tester.tap(showMoreFinder);
      await tester.pumpAndSettle();

      // Now should show "Show less"
      expect(find.text('Show less'), findsOneWidget);

      // Switch to Marathi tab
      final marathiTabFinder = find.text('Marathi Hits (18)');
      await tester.ensureVisible(marathiTabFinder);
      await tester.tap(marathiTabFinder);
      await tester.pumpAndSettle();

      // Should reset expansion and show compact view for Marathi (18 - 4 = 14 more)
      expect(find.textContaining('Show more (14 more)'), findsOneWidget);
    });
  });
}
