import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/screens/widgets/featured_artists_section.dart';
import 'package:Orvia/services/catalogue/curated_artists_service.dart';
import 'package:Orvia/plugins/utils/media_id.dart';

void main() {
  group('Phase 5 — Iconic Indian Artists Expansion & Verification Tests', () {
    test('1. kFeaturedIndianArtists has exactly 17 artists with original 10 preserved and 7 appended in order', () {
      expect(kFeaturedIndianArtists.length, equals(17));

      final names = kFeaturedIndianArtists.map((a) => a.name).toList();

      // Original 10 preserved in exact order
      expect(names[0], equals('Arijit Singh'));
      expect(names[1], equals('Shreya Ghoshal'));
      expect(names[2], equals('A. R. Rahman'));
      expect(names[3], equals('Lata Mangeshkar'));
      expect(names[4], equals('Kishore Kumar'));
      expect(names[5], equals('Sonu Nigam'));
      expect(names[6], equals('Kumar Sanu'));
      expect(names[7], equals('Neha Kakkar'));
      expect(names[8], equals('Badshah'));
      expect(names[9], equals('Jaya Kishori'));

      // Newly appended 7 in exact required order
      expect(names[10], equals('Mohammed Rafi'));
      expect(names[11], equals('Diljit Dosanjh'));
      expect(names[12], equals('Mukesh'));
      expect(names[13], equals('Udit Narayan'));
      expect(names[14], equals('Asha Bhosle'));
      expect(names[15], equals('Alka Yagnik'));
      expect(names[16], equals('Falguni Pathak'));

      // Zero duplicates in artist IDs or names
      final ids = kFeaturedIndianArtists.map((a) => a.id).toSet();
      expect(ids.length, equals(17));
      expect(names.toSet().length, equals(17));

      // Valid CDN artwork URLs
      for (final artist in kFeaturedIndianArtists) {
        expect(artist.imageUrl, startsWith('https://c.saavncdn.com/artists/'));
        expect(artist.imageUrl, endsWith('.jpg'));
      }
    });

    test('2. Curated tracks exist and have 15 verified tracks for each of the 7 new artists', () {
      final newArtists = [
        'Mohammed Rafi',
        'Diljit Dosanjh',
        'Mukesh',
        'Udit Narayan',
        'Asha Bhosle',
        'Alka Yagnik',
        'Falguni Pathak',
      ];

      for (final name in newArtists) {
        final tracks = CuratedArtistsService.getCuratedTracksForArtist(name);
        expect(tracks, isNotNull, reason: 'Curated tracks missing for $name');
        expect(tracks!.length, equals(15), reason: 'Expected 15 tracks for $name');

        final seenIds = <String>{};
        final seenTitles = <String>{};

        for (final t in tracks) {
          expect(isStampedId(t.id), isTrue, reason: 'Track ID must be stamped: ${t.id}');
          expect(pluginIdOf(t.id), equals(kDefaultSaavnPluginId));
          expect(t.title, isNotEmpty);
          expect(t.artists, isNotEmpty);
          expect(t.album?.title, isNotEmpty);
          expect((t.durationMs ?? BigInt.zero) > BigInt.zero, isTrue);
          expect(t.thumbnail.url, isNotEmpty);
          expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID for $name: ${t.id}');
          expect(seenTitles.add(t.title.toLowerCase()), isTrue, reason: 'Duplicate track title for $name: ${t.title}');
        }
      }
    });
  });
}

