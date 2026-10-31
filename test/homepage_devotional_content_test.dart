import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/plugins/blocs/content/content_bloc.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';

void main() {
  group('Homepage section normalization', () {
    Section section(String id, String title) => Section(
          id: id,
          title: title,
          cardType: CardType.carousel,
          items: const [],
        );

    test('removes extra trend sections and preserves remaining provider order',
        () {
      final result = deduplicateHomeSections([
        section('trend-1', 'Trending Now'),
        section('release', 'New Releases'),
        section('trend-2', 'Trending Songs'),
        section('charts', 'Top Charts'),
        section('release-duplicate', ' new releases '),
      ]);

      expect(
        result.map((item) => item.title).toList(),
        ['Trending Now', 'New Releases', 'Top Charts'],
      );
    });

    test('retains untitled sections without changing their relative order', () {
      final result = deduplicateHomeSections([
        section('first', 'First'),
        section('untitled-1', ''),
        section('untitled-2', '  '),
        section('last', 'Last'),
      ]);

      expect(result.map((item) => item.id).toList(),
          ['first', 'untitled-1', 'untitled-2', 'last']);
    });
  });

  group('Bhakti provider refresh', () {
    test('pre-seeded curated tracks do not count as loaded provider results',
        () {
      expect(shouldFetchBhaktiTracks(hasProviderResults: false), isTrue);
      expect(shouldFetchBhaktiTracks(hasProviderResults: true), isFalse);
    });
  });

  test('Navratri artwork is available on track, album, and artist metadata',
      () {
    for (final item in kVerifiedNavratriTracks) {
      final track = item.track;
      expect(track.thumbnail.url, isNotEmpty, reason: track.title);
      expect(track.album?.thumbnail?.url, equals(track.thumbnail.url),
          reason: track.title);
      expect(track.artists.first.thumbnail?.url, equals(track.thumbnail.url),
          reason: track.title);
      expect(track.thumbnail.urlLow, isNotEmpty, reason: track.title);
      expect(track.thumbnail.urlHigh, isNotEmpty, reason: track.title);
    }
  });
}
