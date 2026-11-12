import 'dart:developer';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/global_db.dart';

/// Service managing the "Creator's Choice" Library playlist.
/// Contains verified classic melodies along with curated YouTube video selections.
class CreatorsChoiceService {
  static const String playlistName = "Creator's Choice";
  static const String playlistDescription =
      "70 curated melodies, romantic hits, and chillout favorites featuring 38 verified classic selections and 32 exclusive YouTube tracks.";
  static const String legacyPlaylistDescription =
      "Curated playlist of popular melodies, romantic hits, and chillout favorites imported from YouTube playlist PLQHN0Tu_Mcf8.";
  static const String pluginId = kDefaultSaavnPluginId;
  static const String ytPluginId = 'content-resolver.bloomfactory.ytvideo';

  /// Exact 9 track raw IDs removed as requested.
  static const Set<String> kRemovedTrackRawIds = {
    'CmnN3kEf', // I'm Done (Reply Version) — Maan Panu, Shuddhi
    'Tbw8N4Pa', // Baarish — Ash King, Shashaa Tirupati
    'pge252Zj', // Jubin Nautiyal Romantic Mashup 2022 Remix
    'AZpBDVpd', // Sohnea — Miss Pooja
    'y3hPT6ti', // Drive (From F1) — Ed Sheeran
    '9oSuBfuW', // Baatein Kuch Ankahee — Pritam, Adnan Sami
    'nip59QRg', // Anjali Anjali (From "Duet")
    'o0E1yGZk', // Pehli Dafa — Satyajeet Jena
    'RTA9YjKb', // Navratri Garba Mashup 2021 — Aakash Parma, Trupti Gadhvi
  };

  /// Returns whether [name] refers to the built-in "Creator's Choice" playlist.
  static bool isCreatorsChoice(String? name) {
    if (name == null) return false;
    final normalized = name.trim().toLowerCase().replaceAll('’', "'");
    return normalized == playlistName.toLowerCase() ||
        normalized == "creator's choice" ||
        normalized == "creators choice";
  }

  static List<Track> getVerifiedTracks() {
    return List.unmodifiable(_kVerifiedTracks);
  }

  static Track _track({
    required String rawId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    final compositeId = '$pluginId::$rawId';
    return Track(
      id: compositeId,
      title: title,
      artists: [
        ArtistSummary(
          id: '',
          name: artist,
          thumbnail: Artwork(url: imageUrl, urlLow: imageUrl, urlHigh: imageUrl, layout: ImageLayout.square),
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: Artwork(url: imageUrl, urlLow: imageUrl, urlHigh: imageUrl, layout: ImageLayout.square),
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(url: imageUrl, urlLow: imageUrl, urlHigh: imageUrl, layout: ImageLayout.square),
      isExplicit: false,
    );
  }

  static Track _ytTrack({
    required String videoId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    final compositeId = '$ytPluginId::$videoId';
    final artwork = Artwork(
      url: imageUrl,
      urlLow: imageUrl,
      urlHigh: 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
      layout: ImageLayout.square,
    );
    return Track(
      id: compositeId,
      title: title,
      artists: [
        ArtistSummary(
          id: '',
          name: artist,
          thumbnail: artwork,
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: artwork,
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: artwork,
      url: 'https://www.youtube.com/watch?v=$videoId',
      isExplicit: false,
    );
  }

  /// Ensures the "Creator's Choice" playlist exists in the user's Library
  /// and is seeded/updated with verified playable tracks without duplication.
  static Future<void> ensurePlaylistExists(PlaylistDAO playlistDao) async {
    try {
      final existing = await playlistDao.getPlaylistByName(playlistName);
      if (existing == null) {
        log('Creating Library playlist "$playlistName"', name: 'CreatorsChoiceService');
        final thumbDb = ArtworkDB()
          ..url = 'assets/images/creators_choice_banner.webp'
          ..urlLow = 'assets/images/creators_choice_banner.webp'
          ..urlHigh = 'assets/images/creators_choice_banner.webp';

        final id = await playlistDao.createPlaylist(
          playlistName,
          description: playlistDescription,
          thumbnail: thumbDb,
        );
        if (id != null) {
          await playlistDao.addTracksToPlaylist(id, _kVerifiedTracks, allowSystem: true);
          log('Seeded $playlistName with ${_kVerifiedTracks.length} verified tracks',
              name: 'CreatorsChoiceService');
        }
      } else {
        // Sync thumbnail and description if needed
        if (existing.thumbnail?.url != 'assets/images/creators_choice_banner.webp' ||
            existing.description != playlistDescription) {
          existing.thumbnail = ArtworkDB()
            ..url = 'assets/images/creators_choice_banner.webp'
            ..urlLow = 'assets/images/creators_choice_banner.webp'
            ..urlHigh = 'assets/images/creators_choice_banner.webp';
          existing.description = playlistDescription;
          await playlistDao.putPlaylist(existing);
        }

        // 1. Remove ONLY the 9 specified tracks if present in existing playlist
        for (final rawId in kRemovedTrackRawIds) {
          final compositeId = '$pluginId::$rawId';
          await playlistDao.removeTrackFromPlaylist(existing.id, compositeId, allowSystem: true);
          await playlistDao.removeTrackFromPlaylist(existing.id, rawId, allowSystem: true);
        }

        // Remove old Tu Jaane Na reprise if present
        await playlistDao.removeTrackFromPlaylist(existing.id, '$pluginId::MpNsN4UT', allowSystem: true);
        await playlistDao.removeTrackFromPlaylist(existing.id, 'MpNsN4UT', allowSystem: true);

        // Remove old Tere Sang Yaara - Aakanksha Sharma Version if present
        await playlistDao.removeTrackFromPlaylist(existing.id, '$pluginId::Ndof-bg0', allowSystem: true);
        await playlistDao.removeTrackFromPlaylist(existing.id, 'Ndof-bg0', allowSystem: true);

        // Remove old Jaadui (non-T-Series), Tere Naina, Vaaroon, and Tainu Khabar Nahi (non-Zee) if present
        for (final rId in ['U_-LFOuj', '_uKO18JI', 'PTNX7k-6', 'PS5hORkK']) {
          await playlistDao.removeTrackFromPlaylist(existing.id, '$pluginId::$rId', allowSystem: true);
          await playlistDao.removeTrackFromPlaylist(existing.id, rId, allowSystem: true);
        }

        // 2. Read existing tracks and avoid adding duplicates
        final existingTracks = await playlistDao.getPlaylistTracks(existing.id);
        final existingMediaIds = existingTracks.map((t) => t.mediaId).toSet();

        // 3. Append missing tracks from _kVerifiedTracks in exact order
        final missingTracks = _kVerifiedTracks
            .where((t) => !existingMediaIds.contains(t.id) &&
                          !existingMediaIds.contains(localIdOf(t.id)))
            .toList();

        if (missingTracks.isNotEmpty) {
          await playlistDao.addTracksToPlaylist(existing.id, missingTracks, allowSystem: true);
          log('Added ${missingTracks.length} new verified tracks to $playlistName',
              name: 'CreatorsChoiceService');
        }
      }
    } catch (e, stack) {
      log('Error ensuring $playlistName playlist: $e',
          error: e, stackTrace: stack, name: 'CreatorsChoiceService');
    }
  }

  static final List<Track> _kVerifiedTracks = [
    _track(rawId: 'GQlvs79S', title: 'Naino Ne Baandhi', artist: 'Yasser Desai, Arko', album: 'Gold', durationSec: 241, imageUrl: 'https://c.saavncdn.com/971/Gold-Hindi-2018-20250617065303-500x500.webp'),
    _track(rawId: 'fme85vQj', title: 'Sab Tera', artist: 'Armaan Malik, Shraddha Kapoor', album: 'Baaghi', durationSec: 228, imageUrl: 'https://c.saavncdn.com/944/Baaghi-Hindi-2016-20220420171003-500x500.webp'),
    _track(rawId: '3x-IwBwd', title: 'Soch Na Sake', artist: 'Arijit Singh, Tulsi Kumar, Amaal Mallik', album: 'Airlift', durationSec: 287, imageUrl: 'https://c.saavncdn.com/451/Airlift-Hindi-2015-500x500.jpg'),
    _track(rawId: 'w6nRvGId', title: 'Dil Se Dil Tak', artist: 'Akashdeep Sengupta, Laqshay Kapoor, Kausar Munir', album: 'Bawaal', durationSec: 301, imageUrl: 'https://c.saavncdn.com/016/Bawaal-Hindi-2023-20230722214515-500x500.webp'),
    _track(rawId: 'bIAmZceU', title: 'I Am In Love', artist: 'Pritam, KK, Dominique', album: 'Once Upon A Time In Mumbaai', durationSec: 285, imageUrl: 'https://c.saavncdn.com/512/Once-Upon-A-Time-In-Mumbaai-Hindi-2010-20241223141749-500x500.webp'),
    _track(rawId: '0rYr57cr', title: 'Saathiyaa', artist: 'Shreya Ghoshal, Ajay Gogavale, Ajay-Atul', album: 'Singham', durationSec: 310, imageUrl: 'https://c.saavncdn.com/470/Singham-Hindi-2011-20221211220044-500x500.webp'),
    _track(rawId: 'Xd9NQgRm', title: 'Jitni Dafa', artist: 'Yasser Desai', album: 'Parmanu', durationSec: 222, imageUrl: 'https://c.saavncdn.com/718/Parmanu-Hindi-2018-20250617070209-500x500.webp'),
    _ytTrack(videoId: 'gIOea2pgfIo', title: 'Tere Sang Yaara - Full Video | Rustom | Akshay Kumar & Ileana D\'cruz | Arko | Manoj M', artist: 'Atif Aslam, Arko', album: 'Rustom', durationSec: 294, imageUrl: 'https://i.ytimg.com/vi/gIOea2pgfIo/hqdefault.jpg'),
    _track(rawId: 'AK3icrxP', title: 'Dil Meri Na Sune (Sameer Khan Version)', artist: 'Manoj Muntashir, Sameer Khan, Himesh Reshammiya', album: 'Genius', durationSec: 236, imageUrl: 'https://c.saavncdn.com/994/Genius-Hindi-2018-20250728123019-500x500.webp'),
    _ytTrack(videoId: 'pGuc4hPhiKw', title: 'Bin Tere - Lyrical Song | I Hate Luv Storys | Sonam Kapoor, Imran Khan | Vishal & Shekhar', artist: 'Vishal & Shekhar', album: 'I Hate Luv Storys', durationSec: 331, imageUrl: 'https://i.ytimg.com/vi/pGuc4hPhiKw/hqdefault.jpg'),
    _track(rawId: 'UleloXwf', title: 'Channa Ve', artist: 'Akhil Sachdeva, Mansheel Gujral', album: 'Bhoot - Part One: The Haunted Ship', durationSec: 211, imageUrl: 'https://c.saavncdn.com/006/Bhoot-Part-One-The-Haunted-Ship-Hindi-2020-20200212161346-500x500.webp'),
    _track(rawId: 'KvSHdENF', title: 'Aankhon Se Batana', artist: 'Dikshant', album: 'Indie Campus Chill Hits', durationSec: 221, imageUrl: 'https://c.saavncdn.com/084/Indie-Campus-Chill-Hits-Hindi-2024-20240627120630-500x500.webp'),
    _track(rawId: 'pdAQnMhS', title: 'Soulmate', artist: 'Badshah, Arijit Singh', album: 'Arijit Singh X Badshah The Biggest Songs 2024', durationSec: 214, imageUrl: 'https://c.saavncdn.com/638/Arijit-Singh-X-Badshah-The-Biggest-Songs-2024-Hindi-2024-20240410215733-500x500.webp'),
    _track(rawId: '68Mzp1yU', title: 'Main Hoon Saath Tere', artist: 'Arijit Singh', album: 'Shaadi Mein Zaroor Aana', durationSec: 280, imageUrl: 'https://c.saavncdn.com/861/Shaadi-Mein-Zaroor-Aana-Hindi-2017-20171024101945-500x500.jpg'),
    _ytTrack(videoId: 'P8PWN1OmZOA', title: 'Tu Jaane Na', artist: 'Pritam, Atif Aslam', album: 'Ajab Prem Ki Ghazab Kahani', durationSec: 337, imageUrl: 'https://i.ytimg.com/vi/P8PWN1OmZOA/hqdefault.jpg'),
    _track(rawId: 'cli-P2pu', title: 'Arz Kiya Hai | Coke Studio Bharat', artist: 'Anuv Jain', album: 'Arz Kiya Hai | Coke Studio Bharat', durationSec: 294, imageUrl: 'https://c.saavncdn.com/504/Arz-Kiya-Hai-Coke-Studio-Bharat-Hindi-2025-20250818054005-500x500.webp'),
    _track(rawId: 'CakwGrU-', title: 'Tenu Na Bol Pawaan', artist: 'Yasser Desai, Jyotica Tangri', album: 'Behen Hogi Teri', durationSec: 295, imageUrl: 'https://c.saavncdn.com/128/Behen-Hogi-Teri-Hindi-2017-500x500.jpg'),
    _track(rawId: 'zIPKC8PK', title: 'Tum Se Hi', artist: 'Pritam, Mohit Chauhan', album: 'Jab We Met', durationSec: 321, imageUrl: 'https://c.saavncdn.com/223/Jab-We-Met-Hindi-2007-20231016162009-500x500.webp'),
    _track(rawId: 'X3JYs0TD', title: 'Paniyon Sa (From "Satyameva Jayate")', artist: 'Tulsi Kumar, Rochak Kohli, Kumaar', album: 'World Music Day', durationSec: 236, imageUrl: 'https://c.saavncdn.com/495/World-Music-Day-Hindi-2025-20260217171350-500x500.webp'),
    _track(rawId: 'eW0aCCuD', title: 'Dil Se Dil Tak (Jhankar Beat)[Remix By Moodyboy]', artist: 'Akashdeep Sengupta, Laqshay Kapoor, Kausar Munir, Suvarna Tiwari', album: 'Bawaal (Re-Mastered) - Jhankar Beats', durationSec: 299, imageUrl: 'https://c.saavncdn.com/167/Bawaal-Re-Mastered-Jhankar-Beats-Hindi-2023-20231020141003-500x500.webp'),
    _track(rawId: 'B-Zsr1IJ', title: 'Suniyan Suniyan', artist: 'Juss, Mixsingh', album: 'Suniyan Suniyan', durationSec: 198, imageUrl: 'https://c.saavncdn.com/121/Suniyan-Suniyan-Punjabi-2024-20240415211002-500x500.webp'),
    _track(rawId: 'PCOr94Xj', title: 'Pee Loon (From "Once Upon A Time In Mumbaai")', artist: 'Mohit Chauhan, Pritam, Irshad Kamil', album: 'Emraan Hashmi Hits', durationSec: 285, imageUrl: 'https://c.saavncdn.com/106/Emraan-Hashmi-Hits-Hindi-2026-20260905191028-500x500.webp'),
    _track(rawId: 'WCpI6Pg8', title: 'Ishq Bulaava', artist: 'Vishal & Shekhar, Sanam Puri, Shipra Goyal', album: 'Hasee Toh Phasee', durationSec: 303, imageUrl: 'https://c.saavncdn.com/479/Hasee-Toh-Phasee-Hindi-2014-20260120201339-500x500.webp'),
    _track(rawId: 'maa6PErt', title: 'Ek Tarfa', artist: 'Darshan Raval', album: 'Ek Tarfa', durationSec: 234, imageUrl: 'https://c.saavncdn.com/750/Ek-Tarfa-Hindi-2020-20260226174102-500x500.webp'),
    _track(rawId: 'XGsFYSzP', title: 'Kali Kali Zulfon Ke', artist: 'Madhur Sharma', album: 'Sufi Romance', durationSec: 350, imageUrl: 'https://c.saavncdn.com/383/Sufi-Romance-Hindi-2025-20251106053812-500x500.webp'),
    _track(rawId: '-p_SOUtI', title: 'Arziyaan', artist: 'Raj-Prakash, Vikrant Bhartiya, Aishwarya Majmudar', album: 'Jigariyaa', durationSec: 287, imageUrl: 'https://c.saavncdn.com/830/Jigariyaa-Hindi-2014-500x500.jpg'),
    _track(rawId: '-ArsLWuq', title: 'Mann Jogiya', artist: 'Arijit Singh, Ishita Vishwakarma', album: 'Pyaar Hai Toh Hai', durationSec: 265, imageUrl: 'https://c.saavncdn.com/781/Pyaar-Hai-Toh-Hai-Hindi-2023-20260302133559-500x500.webp'),
    _track(rawId: '3zFgrvoE', title: 'Maiyya Mainu', artist: 'Sachet Tandon', album: 'Jersey', durationSec: 231, imageUrl: 'https://c.saavncdn.com/799/Jersey-Hindi-2021-20220412145401-500x500.webp'),
    _ytTrack(videoId: 'Km5AQkh58DU', title: 'Tere Naina -  8K/4K Music Video | Shahrukh Khan | Kajol | My Name is Khan | Shafqat Amanat Ali', artist: 'Shafqat Amanat Ali', album: 'My Name is Khan', durationSec: 285, imageUrl: 'https://i.ytimg.com/vi/Km5AQkh58DU/hqdefault.jpg'),
    _track(rawId: 'UuGteRjX', title: 'Main Rahoon Ya Na Rahoon', artist: 'Armaan Malik', album: 'Main Rahoon Ya Na Rahoon', durationSec: 310, imageUrl: 'https://c.saavncdn.com/395/Main-Rahoon-Ya-Na-Rahoon-Hindi-2015-500x500.jpg'),
    _track(rawId: '1EvZOLZA', title: 'Tera Zikr', artist: 'Darshan Raval', album: 'Tera Zikr', durationSec: 210, imageUrl: 'https://c.saavncdn.com/820/Tera-Zikr-Hindi-2017-20171108125619-500x500.webp'),
    _track(rawId: '9_-n9cPL', title: 'Main Rang Sharbaton Ka (Reprise)', artist: 'Arijit Singh, Pritam', album: 'Phata Poster Nikhla Hero', durationSec: 277, imageUrl: 'https://c.saavncdn.com/330/Phata-Poster-Nikhla-Hero-Hindi-2013-20260907165855-500x500.webp'),
    _ytTrack(videoId: 'H2f7MZaw3Yo', title: 'Arijit Singh, Shreya Ghoshal - Samjhawan - Lyric video | Alia B, Varun D | Humpty Sharma Ki Dulhania', artist: 'Arijit Singh, Shreya Ghoshal', album: 'Humpty Sharma Ki Dulhania', durationSec: 265, imageUrl: 'https://i.ytimg.com/vi/H2f7MZaw3Yo/hqdefault.jpg'),
    _track(rawId: 'qZtKBMZ_', title: 'Apna Bana Le', artist: 'Sachin-Jigar, Arijit Singh', album: 'Bhediya', durationSec: 261, imageUrl: 'https://c.saavncdn.com/815/Bhediya-Hindi-2023-20230927155213-500x500.webp'),
    _track(rawId: 'wfTj8NYC', title: 'Tera Mera Rishta - New Version (From "Awarapan 2")', artist: 'Mithoon, Pritam, Sayeed Quadri, Saaj Bhatt, Subodhh Sharma', album: 'Awarapan 2', durationSec: 365, imageUrl: 'https://c.saavncdn.com/820/Awarapan-2-Hindi-2026-20260929184517-500x500.webp'),
    _ytTrack(videoId: 'gQ5qVtoLMk4', title: 'Lyrical Video: Dildara Song | Ra.One | ShahRukh Khan, Kareena Kapoor', artist: 'Shafqat Amanat Ali, Vishal & Shekhar', album: 'Ra.One', durationSec: 270, imageUrl: 'https://i.ytimg.com/vi/gQ5qVtoLMk4/hqdefault.jpg'),
    _track(rawId: '9rUwCeSH', title: 'Mehrama', artist: 'Pritam, Darshan Raval, Antara Mitra', album: 'Love Aaj Kal', durationSec: 249, imageUrl: 'https://c.saavncdn.com/862/Love-Aaj-Kal-Hindi-2020-20200214140423-500x500.webp'),
    _track(rawId: '10rKWWH_', title: 'Saanware', artist: 'Akhil Sachdeva, Kartik Dev', album: 'Saanware', durationSec: 195, imageUrl: 'https://c.saavncdn.com/447/Saanware-Hindi-2024-20240209043139-500x500.webp'),
    _ytTrack(videoId: '09fnyp7aAPk', title: 'Finding Her x Dooron Dooron - Mashup (Full Version) | Kushagra | Paresh Pahuja', artist: 'Shubhadip Dey', album: '', durationSec: 222, imageUrl: 'https://i.ytimg.com/vi/09fnyp7aAPk/hqdefault.jpg'),
    _ytTrack(videoId: 'JTA3bfDSuCw', title: 'Husn X Let Her Go X Choo Lo - Part 2 | @ProdByBharat | Anuv Jain | Passenger | Local Train', artist: 'Bharat Flips', album: '', durationSec: 300, imageUrl: 'https://i.ytimg.com/vi/JTA3bfDSuCw/hqdefault.jpg'),
    _ytTrack(videoId: 'cC0Pn37Z2eo', title: 'Dildara (Stand By Me) x I Like Me Better 💕 | NOW ON SPOTIFY ✨', artist: 'Mittxl', album: '', durationSec: 166, imageUrl: 'https://i.ytimg.com/vi/cC0Pn37Z2eo/hqdefault.jpg'),
    _ytTrack(videoId: 'BVnIWAuCv7M', title: 'Jo Tere Sang X Tere Liye (Synthwave Remix) | ROHAN | Indian Bollywood Synthwave', artist: 'ROHAN', album: '', durationSec: 332, imageUrl: 'https://i.ytimg.com/vi/BVnIWAuCv7M/hqdefault.jpg'),
    _ytTrack(videoId: '1pAB0wrQTLE', title: 'ILLAHI x NIGHT CHANGES (MEGA MASHUP) | Gravero & Happy Pills', artist: 'Gravero', album: '', durationSec: 197, imageUrl: 'https://i.ytimg.com/vi/1pAB0wrQTLE/hqdefault.jpg'),
    _ytTrack(videoId: 'eXgtMnhGrmc', title: 'Aditya Rikhari - Paro (UNPLG\'d)', artist: 'Aditya Rikhari', album: '', durationSec: 70, imageUrl: 'https://i.ytimg.com/vi/eXgtMnhGrmc/hqdefault.jpg'),
    _ytTrack(videoId: 'hWpD_fs8M2A', title: 'Tu Hai(MegaMashup) | Darshan Raval | ROHAN X @VDJJEET | Bollywood Mashup', artist: 'ROHAN', album: '', durationSec: 176, imageUrl: 'https://i.ytimg.com/vi/hWpD_fs8M2A/hqdefault.jpg'),
    _ytTrack(videoId: 'k6BnSIs3XUQ', title: 'Phir Le Aya Dil - Barfi | Pritam | Arijit Singh | Ranbir Kapoor | Priyanka | Ileana D\'Cruz', artist: 'SonyMusicIndiaVEVO', album: '', durationSec: 139, imageUrl: 'https://i.ytimg.com/vi/k6BnSIs3XUQ/hqdefault.jpg'),
    _ytTrack(videoId: 'TVbI55pDdaI', title: 'Tu Hain Toh | Mr. & Mrs. Mahi | Rajkummar Rao, Janhvi Kapoor | Hunny, Bunny, Sagar | Team Jaani', artist: 'Sony Music India', album: '', durationSec: 189, imageUrl: 'https://i.ytimg.com/vi/TVbI55pDdaI/hqdefault.jpg'),
    _ytTrack(videoId: 'OtR5WTTyRjI', title: 'Sudh Budh Khoyi Best Part | Lyrics | Sufiyana Sham | Twin Strings ', artist: 'The Reminiscer ', album: '', durationSec: 120, imageUrl: 'https://i.ytimg.com/vi/OtR5WTTyRjI/hqdefault.jpg'),
    _ytTrack(videoId: '_mwqXnTEHSc', title: 'A.R. Rahman - Tere Bina | Lyrical Song | Aishwarya Rai | Abhishek Bachchan | Guru | Gulzar', artist: 'Sony Music India', album: '', durationSec: 308, imageUrl: 'https://i.ytimg.com/vi/_mwqXnTEHSc/hqdefault.jpg'),
    _ytTrack(videoId: 'FGTv9-oQhIg', title: 'Thodi Der -Full Video | Half Girlfriend | Arjun Kapoor & Shraddha Kapoor | Farhan S & Shreya Ghoshal', artist: 'Zee Music Company', album: '', durationSec: 314, imageUrl: 'https://i.ytimg.com/vi/FGTv9-oQhIg/hqdefault.jpg'),
    _ytTrack(videoId: '9Bmh6vaQt0s', title: 'Saibo - Lyrical Audio | Shor In The City | Radhika Apte, Tusshar Kapoor | Shreya Ghoshal', artist: 'Sony Music India', album: '', durationSec: 201, imageUrl: 'https://i.ytimg.com/vi/9Bmh6vaQt0s/hqdefault.jpg'),
    _ytTrack(videoId: 'qNSv9I0Flac', title: 'Jaadui (Song) Tu Jhoothi Main Makkaar | Ranbir, Shraddha | Pritam | Jubin Nautiyal | Amitabh B', artist: 'T-Series', album: '', durationSec: 227, imageUrl: 'https://i.ytimg.com/vi/qNSv9I0Flac/hqdefault.jpg'),
    _ytTrack(videoId: 'DK_UsATwoxI', title: 'Nazm Nazm - Lyrical | Bareilly Ki Barfi | Kriti Sanon, Ayushmann Khurrana & Rajkummar Rao | Arko', artist: 'Zee Music Company', album: '', durationSec: 235, imageUrl: 'https://i.ytimg.com/vi/DK_UsATwoxI/hqdefault.jpg'),
    _ytTrack(videoId: 'Gigpglm3XNw', title: 'Kaafi Hai Na (Full Video) | Musafir Cafe | Vikrant Massey,Vedika,Mahima | Garvit-Priyansh,Jonita', artist: 'T-Series', album: '', durationSec: 200, imageUrl: 'https://i.ytimg.com/vi/Gigpglm3XNw/hqdefault.jpg'),
    _ytTrack(videoId: 'E_SbwSe15y0', title: 'Ve Haaniyaan - Official Video | Ravi Dubey & Sargun Mehta | Danny | Avvy Sra | Dreamiyata Music', artist: 'Dreamiyata Myusic', album: '', durationSec: 204, imageUrl: 'https://i.ytimg.com/vi/E_SbwSe15y0/hqdefault.jpg'),
    _ytTrack(videoId: 'BcSejVIxB0E', title: 'Ishq Hai (Official Music Video) | Mismatched Season 3 | A Netflix Series | Anurag Saikia', artist: 'Ishtar Music', album: '', durationSec: 122, imageUrl: 'https://i.ytimg.com/vi/BcSejVIxB0E/hqdefault.jpg'),
    _ytTrack(videoId: '6d5SS0gS5bU', title: 'Tainu Khabar Nahi - Arijit Singh | Munjya | Sharvari, Abhay Verma| Sachin-Jigar,Amitabh Bhattacharya', artist: 'Zee Music Company', album: '', durationSec: 158, imageUrl: 'https://i.ytimg.com/vi/6d5SS0gS5bU/hqdefault.jpg'),
    _ytTrack(videoId: 'h1Fxjmg_KL4', title: 'Aisa Banna Sawarna Mubarak Tumhen', artist: 'Anjum Hussain - Topic', album: '', durationSec: 249, imageUrl: 'https://i.ytimg.com/vi/h1Fxjmg_KL4/hqdefault.jpg'),
    _ytTrack(videoId: 'gbcFwOZ6uJI', title: 'Nostalgic Love Mashup | Visual Galaxy | Shah Rukh Khan | Falak Tak | Bollywood Lofi Love Mashup 2023', artist: 'Visual Galaxy', album: '', durationSec: 307, imageUrl: 'https://i.ytimg.com/vi/gbcFwOZ6uJI/hqdefault.jpg'),
    _ytTrack(videoId: 'qfdShSZZxlg', title: 'Tera Fitoor Lyrical - Genius | Utkarsh Sharma, Ishita Chauhan | Arijit Singh | Himesh Reshammiya', artist: 'Tips Official', album: '', durationSec: 333, imageUrl: 'https://i.ytimg.com/vi/qfdShSZZxlg/hqdefault.jpg'),
    _ytTrack(videoId: '0Iu5kQi8lns', title: 'Mahiye Jinna Sohna Official Lyrical Video | Darshan Raval | Lijo George | Dard | Naushad Khan', artist: 'Indie Music Label', album: '', durationSec: 184, imageUrl: 'https://i.ytimg.com/vi/0Iu5kQi8lns/hqdefault.jpg'),
    _ytTrack(videoId: 'V7LwfY5U5WI', title: 'Ranjha – Official Video | Shershaah | Sidharth–Kiara | B Praak | Jasleen Royal | Romy | Anvita Dutt', artist: 'Sony Music India', album: '', durationSec: 193, imageUrl: 'https://i.ytimg.com/vi/V7LwfY5U5WI/hqdefault.jpg'),
    _ytTrack(videoId: 'VAdGW7QDJiU', title: 'JAWAN: Chaleya (Hindi) | Shah Rukh Khan | Nayanthara | Atlee | Anirudh | Arijit S, Shilpa R | Kumaar', artist: 'T-Series', album: '', durationSec: 187, imageUrl: 'https://i.ytimg.com/vi/VAdGW7QDJiU/hqdefault.jpg'),
    _ytTrack(videoId: '7SEFsalTzHQ', title: 'Ishq De Fanniyar - Female', artist: 'Jyotica Tangri, Amjad Nadeem', album: 'Fukrey Returns', durationSec: 180, imageUrl: 'https://i.ytimg.com/vi/7SEFsalTzHQ/hqdefault.jpg'),
    _ytTrack(videoId: 'MVpAAJzPEds', title: 'Chal Wahan Jaate Hain', artist: 'Arijit Singh, Amaal Mallik', album: 'Chal Wahan Jaate Hain', durationSec: 326, imageUrl: 'https://i.ytimg.com/vi/MVpAAJzPEds/hqdefault.jpg'),
    _ytTrack(videoId: 'MJyKN-8UncM', title: 'Shayad', artist: 'Pritam, Arijit Singh', album: 'Love Aaj Kal', durationSec: 190, imageUrl: 'https://i.ytimg.com/vi/MJyKN-8UncM/hqdefault.jpg'),
    _ytTrack(videoId: 'kw4tT7SCmaY', title: 'Coke Studio Season 9 | Afreen Afreen', artist: 'Rahat Fateh Ali Khan, Momina Mustehsan', album: 'Coke Studio Season 9', durationSec: 405, imageUrl: 'https://i.ytimg.com/vi/kw4tT7SCmaY/hqdefault.jpg'),
    _ytTrack(videoId: 'byitAI7kkOM', title: 'Dil Mein Ho Tum (Lyrical)', artist: 'Armaan Malik, Rochak Kohli, Bappi Lahiri', album: 'Why Cheat India', durationSec: 346, imageUrl: 'https://i.ytimg.com/vi/byitAI7kkOM/hqdefault.jpg'),
    _ytTrack(videoId: 'cQq6iLF66Gc', title: 'Alfaaz | Hamza Malik x Zain Zohaib | Official Visualiser', artist: 'Hamza Malik, Zain Zohaib', album: 'Alfaaz', durationSec: 185, imageUrl: 'https://i.ytimg.com/vi/cQq6iLF66Gc/hqdefault.jpg'),
    _ytTrack(videoId: 'LMnJp_dSdnw', title: 'DARKHAAST Full Video Song |  SHIVAAY | Arijit Singh & Sunidhi Chauhan | Ajay Devgn | T-Series', artist: 'Arijit Singh, Sunidhi Chauhan, Mithoon', album: 'Shivaay', durationSec: 432, imageUrl: 'https://i.ytimg.com/vi/LMnJp_dSdnw/hqdefault.jpg'),
  ];
}
