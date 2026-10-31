import 'dart:developer';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';

/// Single source of truth for Phase 2 Curated Playlists:
/// 1. Bollywood Hits (YouTube jukebox I0b88L53Gbg — 20 verified tracks)
/// 2. Marathi Hits (YouTube playlist PLU4QT-w5zH6k — 17 verified tracks)
/// 3. Instrumental Classics & Covers (18 curated tracks)
class CuratedPlaylistsService {
  static const String pluginId = kDefaultSaavnPluginId;

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
            layout: ImageLayout.square,
          ),
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
          layout: ImageLayout.square,
        ),
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(
        url: imageUrl,
        urlLow: imageUrl,
        urlHigh: imageUrl,
        layout: ImageLayout.square,
      ),
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
    const ytPluginId = 'content-resolver.bloomfactory.ytvideo';
    final compositeId = '$ytPluginId::$videoId';
    final artwork = Artwork(
      url: imageUrl,
      urlLow: imageUrl,
      urlHigh: imageUrl,
      layout: ImageLayout.square,
    );
    return Track(
      id: compositeId,
      title: title,
      artists: [
        ArtistSummary(
          id: '$ytPluginId::UC55Gz5tT6m3_rWd3l1_PjXw',
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

  /// Deduplicates tracks preserving their original order.
  static List<Track> deduplicate(List<Track> tracks) {
    final seen = <String>{};
    final unique = <Track>[];
    for (final t in tracks) {
      if (t.id.isNotEmpty && seen.add(t.id)) {
        unique.add(t);
      }
    }
    return unique;
  }

  // ==========================================
  // 1. BOLLYWOOD HITS (20 Verified Tracks)
  // Source: https://youtu.be/I0b88L53Gbg
  // ==========================================
  static const String bollywoodPlaylistName = 'Bollywood Dance Hits';
  static const String bollywoodPlaylistDescription =
      'High energy moves, iconic hooks, and pure Bollywood dance anthems from the Best of Bollywood Dance Hits.';

  static final List<Track> _kVerifiedBollywoodTracks = [
    _track(
      rawId: 'W13ekRcO',
      title: 'Bom Diggy Diggy',
      artist: 'Jasmin Walia, Zack Knight',
      album: 'Sonu Ke Titu Ki Sweety',
      durationSec: 238,
      imageUrl:
          'https://c.saavncdn.com/074/Sonu-Ke-Titu-Ki-Sweety-Hindi-2018-20180214153942-500x500.jpg',
    ),
    _track(
      rawId: '_xepYjRk',
      title: 'Abhi Toh Party Shuru Hui Hai',
      artist: 'Badshah, Aastha',
      album: 'Khoobsurat',
      durationSec: 180,
      imageUrl:
          'https://c.saavncdn.com/282/Khoobsurat-Hindi-2014-20250510165659-500x500.jpg',
    ),
    _track(
      rawId: 'AMsdswKo',
      title: 'Teri Baaton Mein Aisa Uljha Jiya Title Song',
      artist: 'Raghav, Tanishk Bagchi, Asees Kaur, Nina Mathur',
      album: 'Teri Baaton Mein Aisa Uljha Jiya',
      durationSec: 153,
      imageUrl:
          'https://c.saavncdn.com/214/Teri-Baaton-Mein-Aisa-Uljha-Jiya-Hindi-2024-20240205151011-500x500.jpg',
    ),
    _track(
      rawId: 'Fy1Afntv',
      title: 'Chammak Challo',
      artist: 'Akon',
      album: 'Ra-One',
      durationSec: 208,
      imageUrl: 'https://c.saavncdn.com/026/Ra-One-Hindi-2011-500x500.jpg',
    ),
    _track(
      rawId: 'hje_bLGI',
      title: 'Dilbar (From "Satyameva Jayate")',
      artist: 'Neha Kakkar, Dhvani Bhanushali, Ikka',
      album: "Nora's Global Grooves",
      durationSec: 184,
      imageUrl:
          'https://c.saavncdn.com/652/Nora-s-Global-Grooves-Hindi-2025-20250207121050-500x500.jpg',
    ),
    _track(
      rawId: 'JaA-GHGf',
      title: 'Mere Mehboob',
      artist: 'Sachin-Jigar, Shilpa Rao, Sachet Tandon, Priya Saraiya',
      album: 'Vicky Vidya Ka Woh Wala Video',
      durationSec: 216,
      imageUrl:
          'https://c.saavncdn.com/412/Vicky-Vidya-Ka-Woh-Wala-Video-Hindi-2024-20241022141007-500x500.jpg',
    ),
    _track(
      rawId: '4POggZZ_',
      title: 'Gali Gali',
      artist: 'Neha Kakkar',
      album: 'KGF Chapter 1',
      durationSec: 164,
      imageUrl:
          'https://c.saavncdn.com/623/Kgf-Chapter-1-Hindi-2018-20181226104000-500x500.jpg',
    ),
    _track(
      rawId: 'a0yY5aoD',
      title: 'Chittiyaan Kalaiyaan',
      artist: 'Meet Bros Anjjan, Kanika Kapoor',
      album: 'Roy',
      durationSec: 185,
      imageUrl: 'https://c.saavncdn.com/647/Roy-Hindi-2015-500x500.jpg',
    ),
    _track(
      rawId: 'pUXO93DP',
      title: 'Payal',
      artist: 'Yo Yo Honey Singh, Paradox',
      album: 'GLORY',
      durationSec: 198,
      imageUrl:
          'https://c.saavncdn.com/173/GLORY-Hindi-2024-20250117161048-500x500.jpg',
    ),
    _track(
      rawId: 'S0U546YS',
      title: 'Millionaire',
      artist: 'Yo Yo Honey Singh',
      album: 'GLORY',
      durationSec: 198,
      imageUrl:
          'https://c.saavncdn.com/173/GLORY-Hindi-2024-20250117161048-500x500.jpg',
    ),
    _track(
      rawId: 'NyXM2Wcy',
      title: 'Aaye Haaye (Feat. Nora Fatehi)',
      artist: 'Karan Aujla, Neha Kakkar, Jay Trak',
      album: 'Aaye Haaye (Feat. Nora Fatehi)',
      durationSec: 167,
      imageUrl:
          'https://c.saavncdn.com/973/Aaye-Haaye-Feat-Nora-Fatehi-Hindi-2024-20241204141009-500x500.jpg',
    ),
    _track(
      rawId: 'mcbYa1Hg',
      title: 'Pink Lips',
      artist: 'Meet Bros Anjjan, Khushboo Grewal',
      album: 'Hate Story 2',
      durationSec: 288,
      imageUrl:
          'https://c.saavncdn.com/622/Hate-Story-2-Hindi-2014-500x500.jpg',
    ),
    _track(
      rawId: '2DIyeoMO',
      title: 'Baby Doll',
      artist: 'Kanika Kapoor, Meet Bros Anjjan',
      album: 'Ragini MMS 2',
      durationSec: 212,
      imageUrl: 'https://c.saavncdn.com/536/Ragini-MMS-2-2014-500x500.jpg',
    ),
    _track(
      rawId: '16MIvBRf',
      title: 'Nasha',
      artist: 'Jasmine Sandlas, Sachet Tandon, Divya Kumar, Sumonto Mukherjee',
      album: 'Raid 2',
      durationSec: 181,
      imageUrl:
          'https://c.saavncdn.com/641/Raid-2-Hindi-2025-20250429161057-500x500.jpg',
    ),
    _track(
      rawId: 'QwkYUnDf',
      title: 'Laal Pari',
      artist: 'Yo Yo Honey Singh, Simar Kaur',
      album: 'Housefull 5',
      durationSec: 185,
      imageUrl:
          'https://c.saavncdn.com/658/Housefull-5-Hindi-2025-20250606151003-500x500.jpg',
    ),
    _track(
      rawId: 'XkEMoT_8',
      title: 'Dil Kaa Jo Haal Hai',
      artist: 'Abhijeet, Shreya Ghoshal',
      album: 'Besharam',
      durationSec: 279,
      imageUrl: 'https://c.saavncdn.com/972/Besharam-2013-500x500.jpg',
    ),
    _track(
      rawId: 'AS4uC68d',
      title: 'Munni Badnaam',
      artist: 'Mamta Sharma, Aishwarya',
      album: 'Dabangg',
      durationSec: 307,
      imageUrl:
          'https://c.saavncdn.com/765/Dabangg-Hindi-2010-20221211114032-500x500.jpg',
    ),
    _track(
      rawId: 'fMPUqMSs',
      title: 'Fevicol Se',
      artist: 'Mamta Sharma, Wajid Khan',
      album: 'Dabangg 2',
      durationSec: 289,
      imageUrl:
          'https://c.saavncdn.com/652/Dabangg-2-Hindi-2012-20221213012606-500x500.jpg',
    ),
    _track(
      rawId: 'wUL21KHg',
      title: 'Afghan Jalebi (Film Version)',
      artist: 'Pritam, Akhtar Chanal Zahri',
      album: 'Phantom',
      durationSec: 226,
      imageUrl: 'https://c.saavncdn.com/951/Phantom-Hindi-2015-500x500.jpg',
    ),
    _track(
      rawId: '_n4E8z9a',
      title: 'Mauja Hi Mauja',
      artist: 'Pritam, Mika Singh',
      album: 'Jab We Met',
      durationSec: 244,
      imageUrl:
          'https://c.saavncdn.com/223/Jab-We-Met-Hindi-2007-20231016162009-500x500.webp',
    ),
  ];

  static List<Track> getBollywoodTracks() =>
      deduplicate(_kVerifiedBollywoodTracks);

  // ==========================================
  // 2. MARATHI HITS (17 Verified Tracks)
  // Source: https://youtube.com/playlist?list=PLU4QT-w5zH6k
  // ==========================================
  static const String marathiPlaylistName = 'Marathi Superhits';
  static const String marathiPlaylistDescription =
      'Iconic Marathi party tracks, folk rhythms, and timeless romantic melodies verified from YouTube playlist PLU4QT-w5zH6k.';

  static final List<Track> _kVerifiedMarathiTracks = [
    _track(
      rawId: '0W8Jg6hD',
      title: 'Zingaat',
      artist: 'Ajay Gogavale, Atul Gogavale',
      album: 'Sairat',
      durationSec: 227,
      imageUrl: 'https://c.saavncdn.com/998/Sairat-Marathi-2016-500x500.jpg',
    ),
    _track(
      rawId: 'E4PzytVq',
      title: 'Gulabi Sadi',
      artist: 'Sanju Rathod',
      album: 'Gulabi Sadi',
      durationSec: 224,
      imageUrl:
          'https://c.saavncdn.com/593/Gulabi-Sadi-Marathi-2024-20240220043332-500x500.jpg',
    ),
    _track(
      rawId: 'zq6JuCFh',
      title: 'Aika Dajiba',
      artist: 'Vaishali Samant',
      album: 'Aika Dajiba',
      durationSec: 241,
      imageUrl: 'https://c.saavncdn.com/791/Aika-Dajiba-Hindi-2002-500x500.jpg',
    ),
    _track(
      rawId: 'VU8H1GzZ',
      title: 'Hi Poli Saajuk',
      artist: 'Reshma Sonawane, Manohar Kolambre',
      album: 'Timepass',
      durationSec: 201,
      imageUrl:
          'https://c.saavncdn.com/777/Timepass-Marathi-2013-20190401111212-500x500.jpg',
    ),
    _track(
      rawId: 'YnuscRJ-',
      title: 'Pappi De Parula',
      artist: 'Smita Gondkar',
      album: 'Pappi De Parula',
      durationSec: 244,
      imageUrl:
          'https://c.saavncdn.com/731/Pappi-De-Parula-Marathi-2021-20210306001428-500x500.jpg',
    ),
    _track(
      rawId: '79PEveVb',
      title: 'Ye Go Ye Ye Maina',
      artist: 'Ajay Gogavale',
      album: 'Jatra',
      durationSec: 279,
      imageUrl:
          'https://c.saavncdn.com/155/Jatra-Marathi-2006-20181122091430-500x500.jpg',
    ),
    _track(
      rawId: 'KBjyAJoX',
      title: 'Kombadi Palali',
      artist: 'Vaishali Samant, Anand Shinde',
      album: 'Jatra',
      durationSec: 326,
      imageUrl:
          'https://c.saavncdn.com/155/Jatra-Marathi-2006-20181122091430-500x500.jpg',
    ),
    _track(
      rawId: 'bJuoQIC4',
      title: 'Sairat Zaala Ji',
      artist: 'Chinmayi Sripada, Ajay Gogavale',
      album: 'Sairat',
      durationSec: 369,
      imageUrl: 'https://c.saavncdn.com/998/Sairat-Marathi-2016-500x500.jpg',
    ),
    _track(
      rawId: 'wto7eGvS',
      title: 'Mala Ved Laagale (Duet)',
      artist: 'Swapnil Bandodkar, Ketakee Mateygaonkar',
      album: 'Timepass',
      durationSec: 266,
      imageUrl:
          'https://c.saavncdn.com/777/Timepass-Marathi-2013-20190401111212-500x500.jpg',
    ),
    _track(
      rawId: 'q83gZrb0',
      title: 'Navin Popat Ha',
      artist: 'Anand Shinde',
      album: 'Java Navin Popat Ha - Dhol Tasha Mix',
      durationSec: 317,
      imageUrl:
          'https://c.saavncdn.com/568/Java-Navin-Popat-Ha-Dhol-Tasha-Mix-Marathi-2006-20230508094352-500x500.jpg',
    ),
    _track(
      rawId: 'sMewrKk_',
      title: 'Navri Natali Supari Futali',
      artist: 'Rahul Shinde',
      album: 'Banu Navri Natli Supari Futali',
      durationSec: 289,
      imageUrl:
          'https://c.saavncdn.com/956/Banu-Navri-Natli-Supari-Futali-Marathi-1997-20251215152405-500x500.jpg',
    ),
    _track(
      rawId: 'Uuu6FZf9',
      title: 'Kelewali',
      artist: 'Avadhoot Gupte, Sampada Mane',
      album: 'Pandu',
      durationSec: 232,
      imageUrl:
          'https://c.saavncdn.com/705/Pandu-Marathi-2021-20220208111747-500x500.jpg',
    ),
    _track(
      rawId: '1ZF6Xnso',
      title: 'Bhurum Bhurum',
      artist: 'Avadhoot Gupte, Vaishali Samant',
      album: 'Pandu',
      durationSec: 228,
      imageUrl:
          'https://c.saavncdn.com/705/Pandu-Marathi-2021-20220208111747-500x500.jpg',
    ),
    _track(
      rawId: '76Z-p7L2',
      title: 'Apsara Aali',
      artist: 'Bela Shende, Ajay Gogavale, Atul Gogavale',
      album: 'Natarang',
      durationSec: 238,
      imageUrl:
          'https://c.saavncdn.com/575/Natarang-Marathi-2010-20170921053253-500x500.jpg',
    ),
    _track(
      rawId: '7ALawopY',
      title: 'Wajle Ki Bara',
      artist: 'Bela Shende',
      album: 'Natarang',
      durationSec: 279,
      imageUrl:
          'https://c.saavncdn.com/575/Natarang-Marathi-2010-20170921053253-500x500.jpg',
    ),
    _track(
      rawId: '2eR1xDiB',
      title: 'Dagala Lagali Kala',
      artist: 'Dada Kondke',
      album: 'Bot Lavin Tithe Gudgulya',
      durationSec: 298,
      imageUrl:
          'https://c.saavncdn.com/757/Bot-Lavin-Tithe-Gudgulya-Marathi-1978-20250708093702-500x500.jpg',
    ),
    _track(
      rawId: 'LRIS0MXg',
      title: 'Ashtami',
      artist: 'Ajay Gogavale',
      album: 'Marathi Devotional Songs',
      durationSec: 254,
      imageUrl:
          'https://c.saavncdn.com/924/Marathi-Devotional-Songs-Marathi-2026-20260529163805-500x500.jpg',
    ),
    _track(
      rawId: '29VH-wzI',
      title: 'Vatanyacha Gol Dana',
      artist: 'Eknath Mali',
      album: 'Navra Palatwala Pahije',
      durationSec: 179,
      imageUrl:
          'https://c.saavncdn.com/131/Navra-Palatwala-Pahije-2008-500x500.jpg',
    ),
  ];

  static List<Track> getMarathiTracks() => deduplicate(_kVerifiedMarathiTracks);

  // ==========================================
  // 3. INSTRUMENTAL HITS (18 Curated Tracks)
  // Source: https://youtube.com/playlist?list=PLPAE4oBeQMuc
  // ==========================================
  static const String instrumentalPlaylistName =
      'Instrumental Classics & Covers';
  static const String instrumentalPlaylistDescription =
      'Pure instrumentals, saxophone melodies, flute tributes, and acoustic classical recordings verified from YouTube playlist PLPAE4oBeQMuc.';

  static final List<Track> _kVerifiedInstrumentalTracks = [
    _track(
      rawId: 'dx9o7bhj',
      title: 'Sambhala Hai Maine (Instrumental)',
      artist: 'Tabun Sutradhar',
      album: 'Soft Instrumentals: Anu Malik',
      durationSec: 295,
      imageUrl:
          'https://c.saavncdn.com/610/Soft-Instrumentals-Anu-Malik-Instrumental-2004-20240408222005-500x500.jpg',
    ),
    _track(
      rawId: 'Dhzfp7H-',
      title: 'Aaja Mahiya (Instrumental)',
      artist: 'Tabun Sutradhar',
      album: 'Soft Instrumentals: Anu Malik',
      durationSec: 328,
      imageUrl:
          'https://c.saavncdn.com/610/Soft-Instrumentals-Anu-Malik-Instrumental-2004-20240408222005-500x500.jpg',
    ),
    _track(
      rawId: 'MhP6ep0G',
      title: 'Raah Mein Unse Mulaqat (Instrumental)',
      artist: 'Tabun Sutradhar',
      album: 'Soft Instrumentals: Anu Malik',
      durationSec: 361,
      imageUrl:
          'https://c.saavncdn.com/610/Soft-Instrumentals-Anu-Malik-Instrumental-2004-20240408222005-500x500.jpg',
    ),
    _track(
      rawId: 'Vy0R1kmu',
      title: 'Soldier Soldier (Instrumental)',
      artist: 'Tabun Sutradhar',
      album: 'Soft Instrumentals: Anu Malik',
      durationSec: 334,
      imageUrl:
          'https://c.saavncdn.com/610/Soft-Instrumentals-Anu-Malik-Instrumental-2004-20240408222005-500x500.jpg',
    ),
    _track(
      rawId: 'sHp6TQU2',
      title: 'Lagi Aaj Sawan Ki (Flute)',
      artist: 'S.R. Kamble',
      album: 'Chandni Instrumental - Flute',
      durationSec: 298,
      imageUrl:
          'https://c.saavncdn.com/825/Chandni-Instrumental-Flute-Hindi-2006-500x500.jpg',
    ),
    _track(
      rawId: 'rmWhhOSL',
      title: 'Dekha Hai Pehli Baar (Instrumental)',
      artist: 'Manohari Singh, Ramakant Patil',
      album: 'Saajan and Yaara Dildara (Instrumental)',
      durationSec: 290,
      imageUrl:
          'https://c.saavncdn.com/456/Saajan-and-Yaara-Dildara-Instrumental-Unknown-1993-20250731053341-500x500.jpg',
    ),
    _track(
      rawId: '-8JmD6_B',
      title: 'Tujhe Dekha To Ye Jana Sanam (Instrumental)',
      artist: 'Arijit Chauhan, Shivani Kashyap',
      album: 'Tujhe Dekha To Ye Jana Sanam (Instrumental)',
      durationSec: 260,
      imageUrl:
          'https://c.saavncdn.com/502/Tujhe-Dekha-To-Ye-Jana-Sanam-Instrumental-Hindi-2025-20250206131505-500x500.jpg',
    ),
    _track(
      rawId: 'qL9x2qLF',
      title: 'Jeeta Tha Jiske Liye (Instrumental)',
      artist: 'Romantic Soft Instrumental Ensemble',
      album: 'Romantic Soft Instrumental',
      durationSec: 375,
      imageUrl:
          'https://c.saavncdn.com/003/Romantic-Soft-Instrumental-Instrumental-2016-500x500.jpg',
    ),
    _track(
      rawId: 'rRopBml2',
      title: 'Saat Samundar Paar (Instrumental)',
      artist: 'Bollywood Instrumental Ensemble',
      album: 'Vishwatma',
      durationSec: 341,
      imageUrl:
          'https://c.saavncdn.com/760/Vishwatma-Hindi-1991-20200901153942-500x500.jpg',
    ),
    _track(
      rawId: 'Z-IXQ0IQ',
      title: 'O Mere Dil Ke Chain (Saxophone)',
      artist: 'Dr. Sanjay Teotia',
      album: 'Instrumental Covers On Saxophone',
      durationSec: 267,
      imageUrl:
          'https://c.saavncdn.com/105/Instrumental-Covers-On-Saxophone-Instrumental-2020-20201013184152-500x500.jpg',
    ),
    _track(
      rawId: 'FDa2l5ZX',
      title: 'Pal Pal Dil Ke Paas (Instrumental)',
      artist: 'Instrumental Tribute Ensemble',
      album: 'The Hits Of Kishore Kumar - An Instrumental Tribute',
      durationSec: 302,
      imageUrl:
          'https://c.saavncdn.com/651/The-Hits-Of-Kishore-Kumar-An-Instrumental-Tribute-English-2011-20190924060933-500x500.jpg',
    ),
    _track(
      rawId: 'puykw_6l',
      title: 'Do Lafzon Ki Hai (Electric Guitar Instrumental)',
      artist: 'Sunil Ganguly',
      album: 'Magic Melody Sunil Ganguly',
      durationSec: 284,
      imageUrl:
          'https://c.saavncdn.com/628/Magic-Melody-Sunil-Ganguly-Hindi-2012-20230113133112-500x500.jpg',
    ),
    _track(
      rawId: 'dCEi2g4f',
      title: 'Dil Kya Kare (Instrumental)',
      artist: 'Instrumental Tribute Ensemble',
      album: 'The Hits Of Kishore Kumar - An Instrumental Tribute',
      durationSec: 290,
      imageUrl:
          'https://c.saavncdn.com/651/The-Hits-Of-Kishore-Kumar-An-Instrumental-Tribute-English-2011-20190924060933-500x500.jpg',
    ),
    _track(
      rawId: 'wTghTVS5',
      title: 'Kal Chaudhvin Ki Raat Thi (Sitar & Surbahar Instrumental)',
      artist: 'Ustad Shujaat Husain Khan',
      album: 'Tribute To Jagjit Singh Ustad Shujaat Husain Khan',
      durationSec: 367,
      imageUrl:
          'https://c.saavncdn.com/814/Tribute-To-Jagjit-Singh-Ustad-Shujaat-Husain-Khan-Urdu-2015-20201015164005-500x500.jpg',
    ),
    _track(
      rawId: '6pE6Ewsf',
      title: 'Phir Aur Kya Chahiye (Instrumental)',
      artist: 'Raghav Sachar, Sachin-Jigar',
      album: 'Phir Aur Kya Chahiye - Instrumental',
      durationSec: 211,
      imageUrl:
          'https://c.saavncdn.com/353/Phir-Aur-Kya-Chahiye-Instrumental-Hindi-2023-20250130063114-500x500.jpg',
    ),
    _track(
      rawId: 'eJ7kmCp2',
      title: 'Ae Mere Humsafar (Instrumental)',
      artist: 'Anu Malik',
      album: 'Romantic Soft Instrumental',
      durationSec: 396,
      imageUrl:
          'https://c.saavncdn.com/003/Romantic-Soft-Instrumental-Instrumental-2016-500x500.jpg',
    ),
    _track(
      rawId: '4R5KnI4S',
      title: 'Chand Tare Phool Sabnam (Instrumental)',
      artist: 'Dj Vikash, Vikash Rock',
      album: 'Chand Tare Phool Sabnam',
      durationSec: 239,
      imageUrl:
          'https://c.saavncdn.com/459/Chand-Tare-Phool-Sabnam-Hindi-2026-20260816010948-500x500.jpg',
    ),
    _track(
      rawId: '_aUkHC6m',
      title: 'Tum Dil Ki Dhadkan Mein (Instrumental)',
      artist: 'Nadeem-Shravan',
      album: 'Dhadkan',
      durationSec: 254,
      imageUrl:
          'https://c.saavncdn.com/454/Dhadkan-Hindi-2000-20210226131403-500x500.jpg',
    ),
  ];

  // ==========================================
  // 4. A.K. MUSIC WORLD INSTRUMENTALS (12 Verified Genuine Channel Tracks)
  // Channel: https://www.youtube.com/@a.k.musicworld199
  // ==========================================
  static const String akMusicWorldPlaylistName =
      'A.K. Music World Instrumentals';
  static const String akMusicWorldPlaylistDescription =
      'Original piano covers, fusion mashups, and background themes by A.K. MUSIC WORLD.';

  static final List<Track> _kVerifiedAkMusicWorldTracks = [
    _ytTrack(
      videoId: 'Ha5QlyycMhM',
      title:
          'Har Shambhu song on piano || हर हर शंभू || शिवा महादेवा || A.K. MUSIC WORLD || Ankit kumbhare ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 114,
      imageUrl: 'https://i.ytimg.com/vi/Ha5QlyycMhM/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'OoOpaG0aoVM',
      title:
          'Lut gaye song on piano || Emraan Hashmi || Jubin N || Instrumental cover || A.K. MUSIC WORLD ||Ankit',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 176,
      imageUrl: 'https://i.ytimg.com/vi/OoOpaG0aoVM/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'gWb64Q6HX40',
      title:
          'Pirates Of The Caribbean Main Theme song || Pirates of the caribbean BGM on Piano by A.K MUSIC WORLD',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 80,
      imageUrl: 'https://i.ytimg.com/vi/gWb64Q6HX40/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'N5PRDOKqSUs',
      title:
          'KGF Theme music Official || KGF: :BGM on Piano by A.K. MUSIC WORLD || Yash || KGF: :BGM Tutorial ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 94,
      imageUrl: 'https://i.ytimg.com/vi/N5PRDOKqSUs/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'MNhJ6obZvh8',
      title:
          'Raataan Lambiyan song on piano by A.K. MUSIC WORLD : Shershaah | Tanishk_B. | Jubin | Asees |',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 125,
      imageUrl: 'https://i.ytimg.com/vi/MNhJ6obZvh8/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'ZhmqU8jjgDY',
      title:
          'Yadav Brand 2 ringtone || Rao Sahab || Elvish Yadav || Musical ringtone edit ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 61,
      imageUrl: 'https://i.ytimg.com/vi/ZhmqU8jjgDY/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'VVUJbVzVosY',
      title:
          'Instrumental ringtones || bom digy digy bom bom || musical ringtone edits ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 66,
      imageUrl: 'https://i.ytimg.com/vi/VVUJbVzVosY/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'v8M12-G3jFc',
      title:
          'Tu Mujhe Soch kabhi Instrumental song || KK (Zindagi Tere Naam ) || A.K. MUSIC WORLD ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 143,
      imageUrl: 'https://i.ytimg.com/vi/v8M12-G3jFc/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'Pt-DdBr3anQ',
      title:
          'Unexpected Piano Mashup | Nagin × Chap tilak × Mast Qalandar × Amarnath aane ko | A.K. MUSIC WORLD',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 201,
      imageUrl: 'https://i.ytimg.com/vi/Pt-DdBr3anQ/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'oYVgw3xGiaU',
      title:
          'Teri Baaton Mein Aisa Uljha Jiya piano cover || Shahid Kapoor || Kriti Sanon || A.K. MUSIC WORLD ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 66,
      imageUrl: 'https://i.ytimg.com/vi/oYVgw3xGiaU/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'SkBKlP4eOBk',
      title:
          'Pasoori song || Ali Sethi  X  Shae Gill || Piano tutorial (cover) || A.K MUSIC WORLD:Ankit kumbhare',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 105,
      imageUrl: 'https://i.ytimg.com/vi/SkBKlP4eOBk/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'O9qpGTKEsYw',
      title:
          'Apna Bana Le Piya [Bhediya]  instrumental ringtone on piano || A.K. MUSIC WORLD ||',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 68,
      imageUrl: 'https://i.ytimg.com/vi/O9qpGTKEsYw/hqdefault.jpg',
    ),
  ];

  static List<Track> getAkMusicWorldTracks() =>
      deduplicate(_kVerifiedAkMusicWorldTracks);

  static List<Track> getInstrumentalTracks() =>
      deduplicate(_kVerifiedInstrumentalTracks);

  /// Discovery playlists must NOT be created in the user's Library.
  /// This method is preserved as a safe no-op to satisfy backward compatibility.
  static Future<void> ensurePlaylistsExists(PlaylistDAO playlistDao) async {
    log('ensurePlaylistsExists called: strictly no-op to protect user Library',
        name: 'CuratedPlaylistsService');
  }
}
