import 'dart:developer';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/global_db.dart';

/// Service managing the "Creator's Choice" Library playlist.
/// Sourced from YouTube playlist PLQHN0Tu_Mcf8 and matched to genuine,
/// verified playable tracks on the supported JioSaavn content provider.
class CreatorsChoiceService {
  static const String playlistName = "Creator's Choice";
  static const String playlistDescription =
      "Curated playlist of popular melodies, romantic hits, and chillout favorites imported from YouTube playlist PLQHN0Tu_Mcf8.";
  static const String pluginId = kDefaultSaavnPluginId;

  static List<Track> getVerifiedTracks() {
    return _kVerifiedTracks;
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

  /// Ensures the "Creator's Choice" playlist exists in the user's Library
  /// and is seeded with the verified playable tracks without duplication.
  static Future<void> ensurePlaylistExists(PlaylistDAO playlistDao) async {
    try {
      final existing = await playlistDao.getPlaylistByName(playlistName);
      if (existing == null) {
        log('Creating Library playlist "$playlistName"', name: 'CreatorsChoiceService');
        final firstThumb = _kVerifiedTracks.first.thumbnail;
        final thumbDb = ArtworkDB()
          ..url = firstThumb.url
          ..urlLow = firstThumb.urlLow
          ..urlHigh = firstThumb.urlHigh;

        final id = await playlistDao.createPlaylist(
          playlistName,
          description: playlistDescription,
          thumbnail: thumbDb,
        );
        if (id != null) {
          await playlistDao.addTracksToPlaylist(id, _kVerifiedTracks);
          log('Seeded $playlistName with ${_kVerifiedTracks.length} verified tracks',
              name: 'CreatorsChoiceService');
        }
      } else {
        final entries = await playlistDao.getPlaylistEntries(existing.id);
        if (entries.isEmpty) {
          await playlistDao.addTracksToPlaylist(existing.id, _kVerifiedTracks);
          log('Populated existing empty $playlistName with ${_kVerifiedTracks.length} verified tracks',
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
    _track(rawId: '9oSuBfuW', title: 'Baatein Kuch Ankahee', artist: 'Pritam, Adnan Sami', album: 'Life In A Metro', durationSec: 277, imageUrl: 'https://c.saavncdn.com/457/Life-In-A-Metro-Hindi-2007-20220321185258-500x500.webp'),
    _track(rawId: '3x-IwBwd', title: 'Soch Na Sake', artist: 'Arijit Singh, Tulsi Kumar, Amaal Mallik', album: 'Airlift', durationSec: 287, imageUrl: 'https://c.saavncdn.com/451/Airlift-Hindi-2015-500x500.jpg'),
    _track(rawId: 'w6nRvGId', title: 'Dil Se Dil Tak', artist: 'Akashdeep Sengupta, Laqshay Kapoor, Kausar Munir', album: 'Bawaal', durationSec: 301, imageUrl: 'https://c.saavncdn.com/016/Bawaal-Hindi-2023-20230722214515-500x500.webp'),
    _track(rawId: 'bIAmZceU', title: 'I Am In Love', artist: 'Pritam, KK, Dominique', album: 'Once Upon A Time In Mumbaai', durationSec: 285, imageUrl: 'https://c.saavncdn.com/512/Once-Upon-A-Time-In-Mumbaai-Hindi-2010-20241223141749-500x500.webp'),
    _track(rawId: '0rYr57cr', title: 'Saathiyaa', artist: 'Shreya Ghoshal, Ajay Gogavale, Ajay-Atul', album: 'Singham', durationSec: 310, imageUrl: 'https://c.saavncdn.com/470/Singham-Hindi-2011-20221211220044-500x500.webp'),
    _track(rawId: 'Xd9NQgRm', title: 'Jitni Dafa', artist: 'Yasser Desai', album: 'Parmanu', durationSec: 222, imageUrl: 'https://c.saavncdn.com/718/Parmanu-Hindi-2018-20250617070209-500x500.webp'),
    _track(rawId: 'nip59QRg', title: 'Anjali Anjali (From "Duet")', artist: 'S. P. Balasubrahmanyam, K. S. Chithra', album: 'Love Notes of A. R. Rahman', durationSec: 483, imageUrl: 'https://c.saavncdn.com/505/Love-Notes-of-A-R-Rahman-Tamil-2017-20201124145944-500x500.webp'),
    _track(rawId: 'Ndof-bg0', title: 'Tere Sang Yaara - Aakanksha Sharma Version', artist: 'Manoj Muntashir, Aakanksha Sharma', album: 'Rustom', durationSec: 240, imageUrl: 'https://c.saavncdn.com/340/Rustom-Hindi-2018-20250617070806-500x500.webp'),
    _track(rawId: 'AK3icrxP', title: 'Dil Meri Na Sune (Sameer Khan Version)', artist: 'Manoj Muntashir, Sameer Khan, Himesh Reshammiya', album: 'Genius', durationSec: 236, imageUrl: 'https://c.saavncdn.com/994/Genius-Hindi-2018-20250728123019-500x500.webp'),
    _track(rawId: 'U_-LFOuj', title: 'Jaadui', artist: 'Pritam, Jubin Nautiyal, Amitabh Bhattacharya', album: 'Tu Jhoothi Main Makkaar', durationSec: 222, imageUrl: 'https://c.saavncdn.com/903/Tu-Jhoothi-Main-Makkaar-Hindi-2023-20230316165419-500x500.webp'),
    _track(rawId: 'UleloXwf', title: 'Channa Ve', artist: 'Akhil Sachdeva, Mansheel Gujral', album: 'Bhoot - Part One: The Haunted Ship', durationSec: 211, imageUrl: 'https://c.saavncdn.com/006/Bhoot-Part-One-The-Haunted-Ship-Hindi-2020-20200212161346-500x500.webp'),
    _track(rawId: 'KvSHdENF', title: 'Aankhon Se Batana', artist: 'Dikshant', album: 'Indie Campus Chill Hits', durationSec: 221, imageUrl: 'https://c.saavncdn.com/084/Indie-Campus-Chill-Hits-Hindi-2024-20240627120630-500x500.webp'),
    _track(rawId: 'pdAQnMhS', title: 'Soulmate', artist: 'Badshah, Arijit Singh', album: 'Arijit Singh X Badshah The Biggest Songs 2024', durationSec: 214, imageUrl: 'https://c.saavncdn.com/638/Arijit-Singh-X-Badshah-The-Biggest-Songs-2024-Hindi-2024-20240410215733-500x500.webp'),
    _track(rawId: '68Mzp1yU', title: 'Main Hoon Saath Tere', artist: 'Arijit Singh', album: 'Shaadi Mein Zaroor Aana', durationSec: 280, imageUrl: 'https://c.saavncdn.com/861/Shaadi-Mein-Zaroor-Aana-Hindi-2017-20171024101945-500x500.jpg'),
    _track(rawId: 'MpNsN4UT', title: 'Tu Jaane Na (Reprise)', artist: 'Pritam, Soham', album: 'Ajab Prem Ki Ghazab Kahani', durationSec: 333, imageUrl: 'https://c.saavncdn.com/792/Ajab-Prem-Ki-Ghazab-Kahani-Hindi-2009-20260907165855-500x500.webp'),
    _track(rawId: 'cli-P2pu', title: 'Arz Kiya Hai | Coke Studio Bharat', artist: 'Anuv Jain', album: 'Arz Kiya Hai | Coke Studio Bharat', durationSec: 294, imageUrl: 'https://c.saavncdn.com/504/Arz-Kiya-Hai-Coke-Studio-Bharat-Hindi-2025-20250818054005-500x500.webp'),
    _track(rawId: 'o0E1yGZk', title: 'Pehli Dafa', artist: 'Satyajeet Jena', album: 'Pehli Dafa', durationSec: 320, imageUrl: 'https://c.saavncdn.com/161/Pehli-Dafa-Hindi-2026-20260127063726-500x500.webp'),
    _track(rawId: 'CakwGrU-', title: 'Tenu Na Bol Pawaan', artist: 'Yasser Desai, Jyotica Tangri', album: 'Behen Hogi Teri', durationSec: 295, imageUrl: 'https://c.saavncdn.com/128/Behen-Hogi-Teri-Hindi-2017-500x500.jpg'),
    _track(rawId: 'zIPKC8PK', title: 'Tum Se Hi', artist: 'Pritam, Mohit Chauhan', album: 'Jab We Met', durationSec: 321, imageUrl: 'https://c.saavncdn.com/223/Jab-We-Met-Hindi-2007-20231016162009-500x500.webp'),
    _track(rawId: 'X3JYs0TD', title: 'Paniyon Sa (From "Satyameva Jayate")', artist: 'Tulsi Kumar, Rochak Kohli, Kumaar', album: 'World Music Day', durationSec: 236, imageUrl: 'https://c.saavncdn.com/495/World-Music-Day-Hindi-2025-20260217171350-500x500.webp'),
    _track(rawId: 'eW0aCCuD', title: 'Dil Se Dil Tak (Jhankar Beat)[Remix By Moodyboy]', artist: 'Akashdeep Sengupta, Laqshay Kapoor, Kausar Munir, Suvarna Tiwari', album: 'Bawaal (Re-Mastered) - Jhankar Beats', durationSec: 299, imageUrl: 'https://c.saavncdn.com/167/Bawaal-Re-Mastered-Jhankar-Beats-Hindi-2023-20231020141003-500x500.webp'),
    _track(rawId: 'B-Zsr1IJ', title: 'Suniyan Suniyan', artist: 'Juss, Mixsingh', album: 'Suniyan Suniyan', durationSec: 198, imageUrl: 'https://c.saavncdn.com/121/Suniyan-Suniyan-Punjabi-2024-20240415211002-500x500.webp'),
    _track(rawId: 'PCOr94Xj', title: 'Pee Loon (From "Once Upon A Time In Mumbaai")', artist: 'Mohit Chauhan, Pritam, Irshad Kamil', album: 'Emraan Hashmi Hits', durationSec: 285, imageUrl: 'https://c.saavncdn.com/106/Emraan-Hashmi-Hits-Hindi-2026-20260905191028-500x500.webp'),
    _track(rawId: 'WCpI6Pg8', title: 'Ishq Bulaava', artist: 'Vishal & Shekhar, Sanam Puri, Shipra Goyal', album: 'Hasee Toh Phasee', durationSec: 303, imageUrl: 'https://c.saavncdn.com/479/Hasee-Toh-Phasee-Hindi-2014-20260120201339-500x500.webp'),
    _track(rawId: 'maa6PErt', title: 'Ek Tarfa', artist: 'Darshan Raval', album: 'Ek Tarfa', durationSec: 234, imageUrl: 'https://c.saavncdn.com/750/Ek-Tarfa-Hindi-2020-20260226174102-500x500.webp'),
    _track(rawId: 'XGsFYSzP', title: 'Kali Kali Zulfon Ke', artist: 'Madhur Sharma', album: 'Sufi Romance', durationSec: 350, imageUrl: 'https://c.saavncdn.com/383/Sufi-Romance-Hindi-2025-20251106053812-500x500.webp'),
    _track(rawId: 'y3hPT6ti', title: 'Drive (From F1® The Movie) (From F1® The Movie)', artist: 'Ed Sheeran', album: 'Drive (From F1® The Movie)', durationSec: 187, imageUrl: 'https://c.saavncdn.com/912/Drive-From-F1-The-Movie-English-2025-20250618233033-500x500.webp'),
    _track(rawId: '-p_SOUtI', title: 'Arziyaan', artist: 'Raj-Prakash, Vikrant Bhartiya, Aishwarya Majmudar', album: 'Jigariyaa', durationSec: 287, imageUrl: 'https://c.saavncdn.com/830/Jigariyaa-Hindi-2014-500x500.jpg'),
    _track(rawId: '-ArsLWuq', title: 'Mann Jogiya', artist: 'Arijit Singh, Ishita Vishwakarma', album: 'Pyaar Hai Toh Hai', durationSec: 265, imageUrl: 'https://c.saavncdn.com/781/Pyaar-Hai-Toh-Hai-Hindi-2023-20260302133559-500x500.webp'),
    _track(rawId: '3zFgrvoE', title: 'Maiyya Mainu', artist: 'Sachet Tandon', album: 'Jersey', durationSec: 231, imageUrl: 'https://c.saavncdn.com/799/Jersey-Hindi-2021-20220412145401-500x500.webp'),
    _track(rawId: '_uKO18JI', title: 'Tere Naina', artist: 'Shankar Mahadevan, Shreya Ghoshal', album: 'Chandni Chowk To China', durationSec: 255, imageUrl: 'https://c.saavncdn.com/532/Chandni-Chowk-To-China-Hindi-2008-20221122102840-500x500.webp'),
    _track(rawId: 'UuGteRjX', title: 'Main Rahoon Ya Na Rahoon', artist: 'Armaan Malik', album: 'Main Rahoon Ya Na Rahoon', durationSec: 310, imageUrl: 'https://c.saavncdn.com/395/Main-Rahoon-Ya-Na-Rahoon-Hindi-2015-500x500.jpg'),
    _track(rawId: 'AZpBDVpd', title: 'Sohnea', artist: 'Miss Pooja', album: 'Sohnea', durationSec: 269, imageUrl: 'https://c.saavncdn.com/269/Sohnea-Punjabi-2017-500x500.jpg'),
    _track(rawId: '1EvZOLZA', title: 'Tera Zikr', artist: 'Darshan Raval', album: 'Tera Zikr', durationSec: 210, imageUrl: 'https://c.saavncdn.com/820/Tera-Zikr-Hindi-2017-20171108125619-500x500.webp'),
    _track(rawId: 'pge252Zj', title: 'Jubin Nautiyal Romantic Mashup 2022(Remix By Dj Abhi India)', artist: 'Jubin Nautiyal, Rocky-Shiv, Tanishk Bagchi, Bharat Goel, Meet Bros, Shardul Rathod, Rochak Kohli, Ami Mishra', album: 'Jubin Nautiyal Romantic Mashup 2022', durationSec: 337, imageUrl: 'https://c.saavncdn.com/366/Jubin-Nautiyal-Romantic-Mashup-2022-Hindi-2022-20221014181007-500x500.webp'),
    _track(rawId: '9_-n9cPL', title: 'Main Rang Sharbaton Ka (Reprise)', artist: 'Arijit Singh, Pritam', album: 'Phata Poster Nikhla Hero', durationSec: 277, imageUrl: 'https://c.saavncdn.com/330/Phata-Poster-Nikhla-Hero-Hindi-2013-20260907165855-500x500.webp'),
    _track(rawId: 'PTNX7k-6', title: 'Vaaroon Forever (From “Mirzapur The Movie”)', artist: 'Anand Bhaskar, Romy, Shreya Ghoshal, Ginny Diwan', album: 'Vaaroon Forever (From “Mirzapur The Movie”)', durationSec: 252, imageUrl: 'https://c.saavncdn.com/381/Vaaroon-Forever-From-Mirzapur-The-Movie-Hindi-2026-20260817160523-500x500.webp'),
    _track(rawId: 'qZtKBMZ_', title: 'Apna Bana Le', artist: 'Sachin-Jigar, Arijit Singh', album: 'Bhediya', durationSec: 261, imageUrl: 'https://c.saavncdn.com/815/Bhediya-Hindi-2023-20230927155213-500x500.webp'),
    _track(rawId: 'wfTj8NYC', title: 'Tera Mera Rishta - New Version (From "Awarapan 2")', artist: 'Mithoon, Pritam, Sayeed Quadri, Saaj Bhatt, Subodhh Sharma', album: 'Awarapan 2', durationSec: 365, imageUrl: 'https://c.saavncdn.com/820/Awarapan-2-Hindi-2026-20260929184517-500x500.webp'),
    _track(rawId: 'PS5hORkK', title: 'Tainu Khabar Nahi', artist: 'Sachin-Jigar, Arijit Singh, Amitabh Bhattacharya', album: 'Heartbeats Bollywood', durationSec: 188, imageUrl: 'https://c.saavncdn.com/195/Heartbeats-Bollywood-Hindi-2026-20260813104641-500x500.webp'),
    _track(rawId: '9rUwCeSH', title: 'Mehrama', artist: 'Pritam, Darshan Raval, Antara Mitra', album: 'Love Aaj Kal', durationSec: 249, imageUrl: 'https://c.saavncdn.com/862/Love-Aaj-Kal-Hindi-2020-20200214140423-500x500.webp'),
    _track(rawId: 'RTA9YjKb', title: 'Navratri Garba Mashup 2021', artist: 'Aakash Parmar, Trupti Gadhvi', album: 'Navratri Garba Mashup 2021', durationSec: 497, imageUrl: 'https://c.saavncdn.com/480/Navratri-Garba-Mashup-2021-Gujarati-2026-20260603074028-500x500.webp'),
    _track(rawId: 'CmnN3kEf', title: 'I\'m Done (Reply Version)', artist: 'Maan Panu, Shuddhi', album: 'I\'m Done (Reply Version)', durationSec: 156, imageUrl: 'https://c.saavncdn.com/471/I-m-Done-Reply-Version-Hindi-2026-20260116115143-500x500.webp'),
    _track(rawId: 'Tbw8N4Pa', title: 'Baarish', artist: 'Ash King, Shashaa Tirupati', album: 'World Music Day 2026', durationSec: 276, imageUrl: 'https://c.saavncdn.com/157/World-Music-Day-2026-Hindi-2026-20260619182741-500x500.webp'),
    _track(rawId: '10rKWWH_', title: 'Saanware', artist: 'Akhil Sachdeva, Kartik Dev', album: 'Saanware', durationSec: 195, imageUrl: 'https://c.saavncdn.com/447/Saanware-Hindi-2024-20240209043139-500x500.webp'),
  ];
}
