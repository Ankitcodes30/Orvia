import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';

/// Service managing the persistent "Dammn" Library playlist.
///
/// Source: YouTube Music playlist `https://music.youtube.com/playlist?list=PLLt5mJLdjhbQ`
/// Every track candidate was verified through the existing JioSaavn provider
/// architecture (`content-resolver.bloomfactory.jisaavn`).
///
/// Original seeded tracks are protected at the database/DAO level so they
/// cannot be removed through normal playlist editing, while user-added tracks
/// remain removable and the playlist itself can be renamed.
class DammnPlaylistService {
  static const String playlistName = "Dammn";
  static const String kDammnCanonicalId = "dammn_canonical_playlist";
  static const String sourceUrl =
      "https://music.youtube.com/playlist?list=PLLt5mJLdjhbQ";
  static const String playlistDescription =
      "Curated chillout, lofi, and mellow vibes imported from YouTube Music playlist PLLt5mJLdjhbQ.";
  static const String pluginId = kDefaultSaavnPluginId;

  /// Returns the ordered list of verified, playable tracks.
  static List<Track> getVerifiedTracks() => List.unmodifiable(_kVerifiedTracks);

  /// Returns the set of media IDs for original seeded tracks.
  static Set<String> getProtectedMediaIds() =>
      _kVerifiedTracks.map((t) => t.id).toSet();

  /// Retired: returns false since special Dammn playlist protection is removed.
  static bool isOriginalTrack(String mediaId) => false;

  /// Extracts the raw ID from either composite (`plugin::rawId`) or raw string.
  static String extractRawId(String mediaId) {
    if (mediaId.contains('::')) {
      return mediaId.split('::').last;
    }
    return mediaId;
  }

  /// Retired: no-op since Dammn auto-seeding has been removed.
  static Future<void> ensurePlaylistExists(PlaylistDAO playlistDao) async {
    // Feature retired: do not auto-seed or lock Dammn playlist.
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
          thumbnail: Artwork(
              url: imageUrl,
              urlLow: imageUrl,
              urlHigh: imageUrl,
              layout: ImageLayout.square),
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: Artwork(
            url: imageUrl,
            urlLow: imageUrl,
            urlHigh: imageUrl,
            layout: ImageLayout.square),
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(
          url: imageUrl,
          urlLow: imageUrl,
          urlHigh: imageUrl,
          layout: ImageLayout.square),
      isExplicit: false,
    );
  }

  static final List<Track> _kVerifiedTracks = [
    // Pos 07
    _track(
      rawId: 'J82LrEcw',
      title: 'Phir Le Aya Dil (Reprise)',
      artist: 'Arijit Singh',
      album: 'Barfi!',
      durationSec: 305,
      imageUrl:
          'https://c.saavncdn.com/974/Barfi-Hindi-2012-20221211221051-500x500.webp',
    ),
    // Pos 08
    _track(
      rawId: 'KIkbghNe',
      title: 'Akhiyaan',
      artist: 'Mitraz',
      album: 'Akhiyaan',
      durationSec: 191,
      imageUrl:
          'https://c.saavncdn.com/834/Akhiyaan-Hindi-2022-20221019053914-500x500.webp',
    ),
    // Pos 10
    _track(
      rawId: 'tM7QIScN',
      title: 'Samjho Na',
      artist: 'Aditya Rikhari',
      album: 'Samjho Na',
      durationSec: 170,
      imageUrl:
          'https://c.saavncdn.com/159/Samjho-Na-Hindi-2022-20220204043906-500x500.webp',
    ),
    // Pos 13
    _track(
      rawId: 'E72zWT1L',
      title: 'Woh Lamhe Woh Baatein',
      artist: 'Atif Aslam, Mithoon',
      album: 'Zeher',
      durationSec: 318,
      imageUrl:
          'https://c.saavncdn.com/602/Zeher-Hindi-2005-20200924151740-500x500.webp',
    ),
    // Pos 16
    _track(
      rawId: 'GrS_KQjR',
      title: 'Toh Phir Aao (From Awarapan)',
      artist: 'Mustafa Zahid, Pritam',
      album: 'Awarapan: The Complete Soundtrack',
      durationSec: 353,
      imageUrl:
          'https://c.saavncdn.com/393/Awarapan-The-Complete-Soundtrack-Hindi-2007-20221128163531-500x500.webp',
    ),
    // Pos 17
    _track(
      rawId: 'GFfS4AqI',
      title: 'Maand X Jhol (Acoustic Cover)',
      artist: 'Tehseen',
      album: 'Maand X Jhol (Acoustic Cover)',
      durationSec: 176,
      imageUrl:
          'https://c.saavncdn.com/142/Maand-X-Jhol-Acoustic-Cover-Hindi-2024-20240321204859-500x500.webp',
    ),
    // Pos 18
    _track(
      rawId: 'ehe2_J8l',
      title: 'Labon Ko Flip Mix(Remix By Kedrock,Sd Style)',
      artist: 'KK, Pritam',
      album: 'Bhool Bhulaiyaa',
      durationSec: 249,
      imageUrl:
          'https://c.saavncdn.com/844/Bhool-Bhulaiyaa-Hindi-2007-20221202022718-500x500.webp',
    ),
    // Pos 22
    _track(
      rawId: 'zIPKC8PK',
      title: 'Tum Se Hi',
      artist: 'Mohit Chauhan, Pritam',
      album: 'Jab We Met',
      durationSec: 323,
      imageUrl:
          'https://c.saavncdn.com/264/Jab-We-Met-Hindi-2007-20221128163430-500x500.webp',
    ),
    // Pos 24
    _track(
      rawId: 'CG4Ce88S',
      title: 'Tere Liye (Unplugged Version)',
      artist: 'Atif Aslam, Shreya Ghoshal, Sachin Gupta',
      album: 'Prince',
      durationSec: 213,
      imageUrl:
          'https://c.saavncdn.com/396/Prince-Hindi-2010-20221202030018-500x500.webp',
    ),
    // Pos 25
    _track(
      rawId: '9E38z3GN',
      title: 'Paro',
      artist: 'Aditya Rikhari, UNPLG\'d',
      album: 'Paro',
      durationSec: 156,
      imageUrl:
          'https://c.saavncdn.com/495/Paro-Hindi-2023-20230623063544-500x500.webp',
    ),
    // Pos 28
    _track(
      rawId: '_WVIcEvf',
      title: 'Gul',
      artist: 'Anuv Jain',
      album: 'Gul',
      durationSec: 217,
      imageUrl:
          'https://c.saavncdn.com/835/Gul-Hindi-2021-20210714150537-500x500.webp',
    ),
    // Pos 29
    _track(
      rawId: 'a7S91rjg',
      title: 'Toh Phir Aao Tera Mera Rishta (Lofi Mash Up)',
      artist: 'Amtee, Pritam, Mustafa Zahid',
      album: 'Toh Phir Aao Tera Mera Rishta (Lofi Mash Up)',
      durationSec: 329,
      imageUrl:
          'https://c.saavncdn.com/112/Toh-Phir-Aao-Tera-Mera-Rishta-Lofi-Mash-Up-Hindi-2023-20230811053032-500x500.webp',
    ),
    // Pos 30
    _track(
      rawId: 'IKc2REl8',
      title: 'Khat',
      artist: 'Navjot Ahuja',
      album: 'Khat',
      durationSec: 297,
      imageUrl:
          'https://c.saavncdn.com/791/Khat-Hindi-2023-20230807090543-500x500.webp',
    ),
    // Pos 32
    _track(
      rawId: '6f34n5wM',
      title: 'Choo Lo',
      artist: 'The Local Train',
      album: 'Aalas Ka Pedh',
      durationSec: 234,
      imageUrl: 'https://c.saavncdn.com/669/Aalas-Ka-Pedh-Hindi-2015-500x500.jpg',
    ),
    // Pos 33
    _track(
      rawId: 'QuUt1Ko-',
      title: 'Parwaaz',
      artist: '10A, Farak',
      album: 'Deewar Ke Uss Paar',
      durationSec: 185,
      imageUrl:
          'https://c.saavncdn.com/264/Deewar-Ke-Uss-Paar-Hindi-2022-20220606132717-500x500.webp',
    ),
    // Pos 35
    _track(
      rawId: 'i_XGg6c2',
      title: 'Aahatein',
      artist: 'Agnee',
      album: 'Aahatein',
      durationSec: 240,
      imageUrl:
          'https://c.saavncdn.com/604/Aahatein-Hindi-2010-20200812234057-500x500.webp',
    ),
    // Pos 36
    _track(
      rawId: '_ORMv2s-',
      title: 'Let Me Down Slowly x Tose Naina',
      artist: 'TommyMuzzic',
      album: 'Let Me Down Slowly x Tose Naina',
      durationSec: 174,
      imageUrl:
          'https://c.saavncdn.com/832/Let-Me-Down-Slowly-x-Tose-Naina-Unknown-2022-20220412151108-500x500.webp',
    ),
    // Pos 37
    _track(
      rawId: 'cli-P2pu',
      title: 'Arz Kiya Hai | Coke Studio Bharat',
      artist: 'Anuv Jain, Lost Stories',
      album: 'Arz Kiya Hai | Coke Studio Bharat',
      durationSec: 307,
      imageUrl:
          'https://c.saavncdn.com/129/Arz-Kiya-Hai-Coke-Studio-Bharat-Hindi-2024-20240722122606-500x500.webp',
    ),
    // Pos 38
    _track(
      rawId: '9D_8Jd1R',
      title: 'Na Tum Jano Na Hum',
      artist: 'Lucky Ali, Divya Spandana (Ramya)',
      album: 'And The Winner Is - Best Singer',
      durationSec: 348,
      imageUrl:
          'https://c.saavncdn.com/177/And-The-Winner-Is-Best-Singer-Hindi-2014-500x500.jpg',
    ),
    // Pos 39
    _track(
      rawId: 'UlkAvI5L',
      title: 'Meherbaan',
      artist: 'Ash King, Shilpa Rao, Shekhar Ravjiani',
      album: 'Bang Bang!',
      durationSec: 307,
      imageUrl: 'https://c.saavncdn.com/970/Bang-Bang-Hindi-2014-500x500.jpg',
    ),
    // Pos 41
    _track(
      rawId: 'X0zxHHfs',
      title: 'Husn',
      artist: 'Anuv Jain',
      album: 'Husn',
      durationSec: 218,
      imageUrl:
          'https://c.saavncdn.com/393/Husn-Hindi-2023-20231201043322-500x500.webp',
    ),
    // Pos 45
    _track(
      rawId: 'AWoCK3DV',
      title: 'Tum Tak',
      artist: 'Javed Ali, A.R. Rahman, Kirti Sagathia',
      album: 'Raanjhanaa',
      durationSec: 304,
      imageUrl: 'https://c.saavncdn.com/142/Raanjhanaa-Hindi-2013-500x500.jpg',
    ),
    // Pos 48
    _track(
      rawId: 'FC63n6XV',
      title: 'Kya Mujhe Pyar Hai',
      artist: 'KK, Pritam',
      album: 'Woh Lamhe',
      durationSec: 272,
      imageUrl:
          'https://c.saavncdn.com/602/Woh-Lamhe-Hindi-2006-20190617154030-500x500.webp',
    ),
    // Pos 51
    _track(
      rawId: 'pJjvPcAb',
      title: 'Piya Tu Piya',
      artist: 'Arijit Singh, Chinmayi Sripada',
      album: 'Dongri Ka Raja',
      durationSec: 375,
      imageUrl: 'https://c.saavncdn.com/830/Dongri-Ka-Raja-Hindi-2016-500x500.jpg',
    ),
    // Pos 52
    _track(
      rawId: 'aDLvwxgv',
      title: 'Gori Radha Ne Kado Kaan',
      artist: 'Sachin-Jigar, Kirtidan Gadhvi',
      album: 'Wrong Side Raju',
      durationSec: 327,
      imageUrl:
          'https://c.saavncdn.com/463/Wrong-Side-Raju-Gujarati-2016-500x500.jpg',
    ),
  ];

  /// Documentation of all 28 unresolved candidate tracks from the 53-track YouTube playlist.
  static const List<Map<String, String>> unresolvedCandidateTracks = [
    {
      'position': '01',
      'title': 'Kaun Hoon Main - Lofi Mix',
      'artist': 'Atif Aslam, Prince',
      'reason':
          'Vocal track not indexed on supported content provider; only instrumental available.',
    },
    {
      'position': '02',
      'title': 'O Re Piya (Gravero & Veerdo Lofi Remake)',
      'artist': 'Rahat Fateh Ali Khan',
      'reason':
          'Original Aaja Nachle recording is licensed under Yash Raj Films (YRF), unavailable on JioSaavn.',
    },
    {
      'position': '03',
      'title': 'Finding Her x Dooron Dooron - Mashup',
      'artist': 'Shubhadip Dey',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '04',
      'title': 'Zaroorat (Lo-fi Mix)',
      'artist': 'Mustafa Zahid, Mithoon',
      'reason':
          'Ek Villain original recording by Mustafa Zahid is not indexed as an individual playable track on JioSaavn.',
    },
    {
      'position': '05',
      'title': 'Husn X Let Her Go X Choo Lo - Part 2',
      'artist': 'Bharat Flips',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '06',
      'title': 'Pasoori X We Don\'t Talk Anymore',
      'artist': 'ROHAN',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '09',
      'title': 'Dildara (Stand By Me) x I Like Me Better',
      'artist': 'Mittxl',
      'reason':
          'Fan-created mashup; standalone Ra.One Dildara by Shafqat Amanat Ali is not catalogued on JioSaavn.',
    },
    {
      'position': '11',
      'title': 'Snap x Baarishen - Mashup',
      'artist': 'Gravero & TP',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '12',
      'title': 'Jo Tere Sang X Tere Liye (Synthwave Remix)',
      'artist': 'ROHAN',
      'reason':
          'Unofficial fan-created synthwave mashup without official label distribution.',
    },
    {
      'position': '14',
      'title': 'Stay x Ranjha (JAZ Scape Mashup)',
      'artist': 'JAZ Scape',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '15',
      'title': 'ILLAHI x NIGHT CHANGES (MEGA MASHUP)',
      'artist': 'Gravero & Happy Pills',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '19',
      'title': 'Animals X Kurbaan Hua (MegaMix)',
      'artist': 'ROHAN & Happy Pills',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '20',
      'title': 'People x Zara Sa x Ride It',
      'artist': 'Sk Visual',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '21',
      'title': 'Ik Vaari Aa x We Don\'t Talk Anymore',
      'artist': 'Mittxl',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '23',
      'title': 'Tu Hai (MegaMashup)',
      'artist': 'ROHAN & VDJJEET',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '26',
      'title': 'Zara Zara x Let Me Down Slowly MASHUP',
      'artist': 'JalRaj',
      'reason':
          'Unofficial fan-created cover mashup without official label distribution.',
    },
    {
      'position': '27',
      'title': 'I Wanna Love You x Kaise Mai Kahu Tujhse',
      'artist': 'Aviral Kapasia',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '31',
      'title': 'Aadat (Chillout Mashup)',
      'artist': 'BiKi & DJ Rik',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '34',
      'title': 'Diljit - Magic X Kina Chir (Synthwave Remix)',
      'artist': 'ROHAN',
      'reason':
          'Unofficial fan-created synthwave mashup without official label distribution.',
    },
    {
      'position': '40',
      'title': 'Love Mixtape (Mashup Lofi)',
      'artist': 'SKY THE SANGEETKAR',
      'reason':
          'Unofficial fan-created mixtape without official label distribution.',
    },
    {
      'position': '42',
      'title': 'Infinity x Kabhi Jo Badal Barse',
      'artist': 'Sagar Swarup & Sunix Thakor',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '43',
      'title': 'Aa Bhi Jaa Sanam Yun Na Kar Sitam - Lofi Mix',
      'artist': 'Atif Aslam, Prince',
      'reason':
          'Prince vocal version by Atif Aslam is not available on JioSaavn; only instrumental indexed.',
    },
    {
      'position': '44',
      'title': 'KK Mashup (Musical Tribute) - Chillout Mix',
      'artist': 'AB Ambients',
      'reason':
          'Unofficial fan-created tribute mashup without official label distribution.',
    },
    {
      'position': '46',
      'title': 'Phir Mohabbat x Aye Khuda x Uska Hi Banana',
      'artist': 'JalRaj',
      'reason':
          'Unofficial fan cover medley without official label distribution.',
    },
    {
      'position': '47',
      'title': 'Shape of You X Mann Mera - Lofi Mashup',
      'artist': 'Swapnil Tiwari',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '49',
      'title': 'MIDDLE OF THE NIGHT x TERI DEEWANI',
      'artist': 'Gravero & Beatzhacker',
      'reason':
          'Unofficial fan-created mashup without official label distribution.',
    },
    {
      'position': '50',
      'title': 'Hona Tha Pyar',
      'artist': 'Atif Aslam, Hadiqa Kiani (Bol)',
      'reason':
          'Original Bol vocal soundtrack is not catalogued on JioSaavn; only instrumental indexed.',
    },
    {
      'position': '53',
      'title': 'Woh Lamhe X Laare Choote',
      'artist': 'ROHAN',
      'reason':
          'Unofficial fan-created synthwave mashup without official label distribution.',
    },
  ];
}
