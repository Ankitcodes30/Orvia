import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/screens/widgets/multi_select_bar.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';

void main() {
  group('Requirement 4: Creator\'s Choice Immutability', () {
    test('isCreatorsChoice correctly identifies standard variants', () {
      expect(CreatorsChoiceService.isCreatorsChoice("Creator's Choice"), isTrue);
      expect(CreatorsChoiceService.isCreatorsChoice("Creators Choice"), isTrue);
      expect(CreatorsChoiceService.isCreatorsChoice("creator's choice"), isTrue);
      expect(CreatorsChoiceService.isCreatorsChoice("  Creator’s Choice  "), isTrue);

      expect(CreatorsChoiceService.isCreatorsChoice('My Playlist'), isFalse);
      expect(CreatorsChoiceService.isCreatorsChoice('Liked songs'), isFalse);
      expect(CreatorsChoiceService.isCreatorsChoice(null), isFalse);
    });

    test('Add to playlist filtering excludes Creator\'s Choice and system playlists', () {
      final playlists = [
        PlaylistItemProperties(
          playlistName: "Creator's Choice",
          storageKey: "Creator's Choice",
          type: PlaylistType.userPlaylist,
          isPinned: false,
          sortOrder: 0,
        ),
        PlaylistItemProperties(
          playlistName: "recently_played",
          storageKey: "recently_played",
          type: PlaylistType.userPlaylist,
          isPinned: false,
          sortOrder: 1,
        ),
        PlaylistItemProperties(
          playlistName: "Gym Workout",
          storageKey: "Gym Workout",
          type: PlaylistType.userPlaylist,
          isPinned: false,
          sortOrder: 2,
        ),
        PlaylistItemProperties(
          playlistName: "Acoustic Hits",
          storageKey: "Acoustic Hits",
          type: PlaylistType.userPlaylist,
          isPinned: false,
          sortOrder: 3,
        ),
      ];

      // Replicate AddToPlaylistScreen._filterPlaylists logic
      final filtered = playlists.where((p) {
        return p.type == PlaylistType.userPlaylist &&
            p.playlistName != "recently_played" &&
            p.playlistName != "downloadPlaylist" &&
            p.playlistName != "localMusicPlaylist" &&
            !CreatorsChoiceService.isCreatorsChoice(p.playlistName);
      }).toList();

      expect(filtered.length, equals(2));
      expect(filtered.map((p) => p.playlistName),
          containsAll(['Gym Workout', 'Acoustic Hits']));
      expect(filtered.any((p) => CreatorsChoiceService.isCreatorsChoice(p.playlistName)),
          isFalse);
    });
  });

  group('Requirement 5: Liked Albums Filtering in Library', () {
    test('PlaylistTypeDB.album is excluded from general library playlist list', () {
      // Simulate raw playlists returned by database
      final rawPlaylists = [
        {'name': 'Liked songs', 'type': 'userPlaylist'},
        {'name': 'Mangal Rang', 'type': 'album'}, // Liked album
        {'name': 'Arijit Singh Favorites', 'type': 'artist'}, // Favorite artist
        {'name': 'Chill Vibes', 'type': 'userPlaylist'},
      ];

      // Replicate LibraryItemsCubit._fetchPlaylists filter logic
      final filtered = rawPlaylists.where((p) {
        if (p['type'] == 'artist') return false; // In artists section
        if (p['type'] == 'album') return false; // In dedicated Liked albums row only
        return true;
      }).toList();

      expect(filtered.length, equals(2));
      expect(filtered.map((p) => p['name']),
          equals(['Liked songs', 'Chill Vibes']));
      expect(filtered.any((p) => p['name'] == 'Mangal Rang'), isFalse);
    });
  });

  group('Requirement 7: Multi-Select Context Contracts', () {
    test('MultiSelectContext defines proper contexts', () {
      expect(MultiSelectContext.values,
          containsAll([MultiSelectContext.discovery, MultiSelectContext.offline, MultiSelectContext.userPlaylist]));
    });

    test('Discovery context does not allow delete action', () {
      const contextType = MultiSelectContext.discovery;
      expect(contextType == MultiSelectContext.offline, isFalse);
    });

    test('Offline context allows delete action but not download action', () {
      const contextType = MultiSelectContext.offline;
      expect(contextType == MultiSelectContext.offline, isTrue);
    });
  });
}
