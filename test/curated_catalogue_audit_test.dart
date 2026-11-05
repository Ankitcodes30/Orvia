import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';

void main() {
  test("Creator's Choice exposes 70 unique verified catalogue entries", () {
    final tracks = CreatorsChoiceService.getVerifiedTracks();
    expect(tracks, hasLength(70));
    expect(tracks.map((track) => track.id).toSet(), hasLength(70));

    for (final track in tracks) {
      expect(isStampedId(track.id), isTrue, reason: track.title);
      expect(track.title, isNotEmpty);
      expect(track.artists, isNotEmpty);
      expect(track.thumbnail.url, isNotEmpty);
      expect(track.album?.thumbnail?.url, track.thumbnail.url);
      expect(track.artists.first.thumbnail?.url, track.thumbnail.url);
    }

    expect(CreatorsChoiceService.playlistDescription, contains('70 curated melodies'));
    expect(
      CreatorsChoiceService.playlistDescription,
      contains('38 verified classic selections and 32 exclusive YouTube tracks'),
    );
  });

  test('Instrumental Discovery uses unique JioSaavn IDs and consistent artwork', () {
    final tracks = CuratedPlaylistsService.getInstrumentalTracks();
    expect(tracks, hasLength(18));
    expect(tracks.map((track) => track.id).toSet(), hasLength(tracks.length));

    for (final track in tracks) {
      expect(isStampedId(track.id), isTrue, reason: track.title);
      expect(pluginIdOf(track.id), CuratedPlaylistsService.pluginId,
          reason: track.title);
      expect(track.title, isNotEmpty);
      expect(track.artists, isNotEmpty);
      expect(track.thumbnail.url, startsWith('https://c.saavncdn.com/'));
      expect(track.thumbnail.urlLow, track.thumbnail.url);
      expect(track.thumbnail.urlHigh, track.thumbnail.url);
      expect(track.album?.thumbnail?.url, track.thumbnail.url);
      expect(track.artists.first.thumbnail?.url, track.thumbnail.url);
      expect(track.url, isNull,
          reason: 'Saavn playback is resolved from the provider ID');
    }
  });
}
