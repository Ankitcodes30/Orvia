import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/routes/search_navigation.dart';

bool shouldFetchBhaktiTracks({required bool hasProviderResults}) =>
    !hasProviderResults;

Track _buildBhaktiTrack({
  required String id,
  required String title,
  required String artist,
  required int durationMs,
  required String imgUrl,
  required String albumTitle,
}) {
  final stampedId =
      isStampedId(id) ? id : buildMediaId(kDefaultSaavnPluginId, id);
  final artwork = Artwork(
    url: imgUrl,
    urlLow: imgUrl,
    urlHigh: imgUrl,
    layout: ImageLayout.square,
  );
  return Track(
    id: stampedId,
    title: title,
    artists: [ArtistSummary(id: '', name: artist, thumbnail: artwork)],
    album: AlbumSummary(
        id: '', title: albumTitle, artists: const [], thumbnail: artwork),
    durationMs: BigInt.from(durationMs),
    thumbnail: artwork,
    isExplicit: false,
  );
}

Track _buildBhaktiYtTrack({
  required String videoId,
  required String title,
  required String artist,
  required int durationMs,
  required String imgUrl,
  required String albumTitle,
}) {
  const ytPluginId = 'content-resolver.bloomfactory.ytvideo';
  final compositeId = '$ytPluginId::$videoId';
  final artwork = Artwork(
    url: imgUrl,
    urlLow: imgUrl,
    urlHigh: imgUrl,
    layout: ImageLayout.square,
  );
  return Track(
    id: compositeId,
    title: title,
    artists: [ArtistSummary(id: '', name: artist, thumbnail: artwork)],
    album: AlbumSummary(
        id: '', title: albumTitle, artists: const [], thumbnail: artwork),
    durationMs: BigInt.from(durationMs),
    thumbnail: artwork,
    url: 'https://www.youtube.com/watch?v=$videoId',
    isExplicit: false,
  );
}

/// Verified sacred devotional tracks matching requested titles & artists
final List<Track> kVerifiedBhaktiTracks = [
  _buildBhaktiTrack(
    id: "0mzeu7ZV",
    title: "Pyara Saja Hai Tera Dwar",
    artist: "Lakhbir Singh Lakkha",
    albumTitle: "Pyara Saja Hai Tera Dwar Bhawani",
    durationMs: 444000,
    imgUrl:
        "https://c.saavncdn.com/150/Pyara-Saja-Hai-Tera-Dwar-Bhawani-Hindi-1997-20230807154137-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "OUn5kNr0",
    title: "Mann Ki Muradein Poori Kar Maa",
    artist: "Lakhbir Singh Lakkha",
    albumTitle: "Beta Bulaye",
    durationMs: 388000,
    imgUrl:
        "https://c.saavncdn.com/034/Beta-Bulaye-Hindi-1998-20230807153827-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "ZNEi3ZrP",
    title: "Maiya Ka Chola Hai Rangla",
    artist: "Lakhbir Singh Lakkha",
    albumTitle: "Maiya Ka Chola Hai Rangla",
    durationMs: 421000,
    imgUrl:
        "https://c.saavncdn.com/094/Maiya-Ka-Chola-Hai-Rangla-Hindi-1996-20250707161916-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "WU5HhJJV",
    title: "Karein Bhagat hon aarti mai doi biriyan",
    artist: "Rakesh Tiwari",
    albumTitle: "DEVI MAHIMA VOL 1",
    durationMs: 341000,
    imgUrl:
        "https://c.saavncdn.com/370/DEVI-MAHIMA-VOL-1-Hindi-1986-20220401124606-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "JyKZiWHI",
    title: "Leke Pooja Ki Thali",
    artist: "Sonu Nigam, Suresh Wadkar, Anuradha Paudwal",
    albumTitle: "Jai Maa Vaishno Devi",
    durationMs: 319000,
    imgUrl:
        "https://c.saavncdn.com/791/Jai-Maa-Vaishno-Devi-Hindi-1999-20250401130824-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "AQLHJETS",
    title: "Path Rakho Meri Maa",
    artist: "Satyam Toriya",
    albumTitle: "Path Rakho Meri Maa",
    durationMs: 334000,
    imgUrl:
        "https://c.saavncdn.com/287/Path-Rakho-Meri-Maa-Hindi-2018-20230118103518-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "cvMn3Va5",
    title: "Chali Aa Rahi Mahamai Kalika",
    artist: "Subhash Soni",
    albumTitle: "Chali Aa Rahi Mahamai Kalika",
    durationMs: 412000,
    imgUrl:
        "https://c.saavncdn.com/014/Chali-Aa-Rahi-Mahamai-Kalika-Hindi-2026-20260823200805-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "YlrtzWwk",
    title: "Kalo Ki Kaal Mahakali",
    artist: "Manish Agrawal",
    albumTitle: "Kalo Ki Kaal Mahakali",
    durationMs: 367000,
    imgUrl:
        "https://c.saavncdn.com/062/Kalo-Ki-Kaal-Mahakali-Hindi-2017-20241206144821-500x500.jpg",
  ),
];

/// Verified additions from Devotional Playlist PLcsznYWNmQT0
final List<Track> kVerifiedDevotionalPlaylistTracks = [
  // --- New Verified Devotional Tracks from Playlist PLcsznYWNmQT0 ---
  _buildBhaktiTrack(
    id: "C5NaiPNM",
    title: "Machlat Aave Mai Kalika",
    artist: "Subhash Soni",
    albumTitle: "Machlat Aave Mai Kalika",
    durationMs: 407000,
    imgUrl:
        "https://c.saavncdn.com/746/Machlat-Aave-Mai-Kalika-Hindi-2026-20260311124407-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "Br3sv0l4",
    title: "Dulhaniya Re",
    artist: "Shahnaaz Akhtar",
    albumTitle: "Dulhaniya Re",
    durationMs: 858000,
    imgUrl:
        "https://c.saavncdn.com/580/Dulhaniya-Re-Hindi-2023-20250511164359-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "__MfaQW6",
    title: "Aalha Ki Dhwaja Nahin Aayi",
    artist: "Shahnaz Akhtar",
    albumTitle: "Maiyya Pav Paijaniya",
    durationMs: 787000,
    imgUrl:
        "https://c.saavncdn.com/066/Maiya-Paav-Paijaniya-Vol-1-Hindi-2009-20260608212622-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "r5yioR-M",
    title: "Bigdi Meri Bana De Oo Sherawali Maiya",
    artist: "Lakhbir Singh Lakkha",
    albumTitle: "Bigdi Meri Bana De Oo Sherawali Maiya",
    durationMs: 417000,
    imgUrl:
        "https://c.saavncdn.com/034/Beta-Bulaye-Hindi-1998-20230807153827-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "6o2XH_yQ",
    title: "Nach Rahi Hai Kali Angana Mein",
    artist: "Sandeep Karosiya",
    albumTitle: "Nach Rahi Hai Kali Angana Mein",
    durationMs: 391000,
    imgUrl:
        "https://c.saavncdn.com/311/Nach-Rahi-Hai-Kali-Angana-Mein-Hindi-2025-20251007144002-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "ifnZV6aN",
    title: "O Aaye Tere Bhawan",
    artist: "Sonu Nigam, Anuradha Paudwal",
    albumTitle: "Jai Maa Vaishno Devi",
    durationMs: 324000,
    imgUrl:
        "https://c.saavncdn.com/791/Jai-Maa-Vaishno-Devi-Hindi-1999-20250401130824-500x500.jpg",
  ),
  _buildBhaktiTrack(
    id: "Ft5IeMlT",
    title: "Angna Padharo Maharani",
    artist: "Manish Agrawal",
    albumTitle: "Angna Padharo Maharani",
    durationMs: 568000,
    imgUrl:
        "https://c.saavncdn.com/734/Angna-Padharo-Maharani-Hindi-2023-20260420210240-500x500.jpg",
  ),
  // --- Verified YouTube-Exclusive Devotional Releases ---
  _buildBhaktiYtTrack(
    videoId: "macdUAgZTpY",
    title: "Bigdi Meri Bana De (Beta Bulaye)",
    artist: "Lakhbir Singh Lakkha",
    albumTitle: "Beta Bulaye (T-Series Bhakti)",
    durationMs: 412000,
    imgUrl: "https://i.ytimg.com/vi/macdUAgZTpY/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "4-XF6hvmOjk",
    title: "Mai Sabse Badi Hai Tu",
    artist: "Riza Khan, Bali Thakre",
    albumTitle: "Navratri Special",
    durationMs: 522000,
    imgUrl: "https://i.ytimg.com/vi/4-XF6hvmOjk/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "3qbyBuw2F-g",
    title: "Jagmang Jyoti Jale",
    artist: "Shahnaaz Akhtar",
    albumTitle: "Navratri Special Bhajan",
    durationMs: 325000,
    imgUrl: "https://i.ytimg.com/vi/3qbyBuw2F-g/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "m4Nw7jSRpEQ",
    title: "De De Thoda Pyar Maiya",
    artist: "Yuki Bhakti",
    albumTitle: "Matarani Most Popular Bhajan",
    durationMs: 312000,
    imgUrl: "https://i.ytimg.com/vi/m4Nw7jSRpEQ/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "UUAJFjov7Xo",
    title: "Man Leke Aaya Mata Rani Ke Bhawan Mein",
    artist: "Gulshan Kumar",
    albumTitle: "Jai Jagjanni",
    durationMs: 550000,
    imgUrl: "https://i.ytimg.com/vi/UUAJFjov7Xo/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "ik79ITh2AD8",
    title: "Hey Naam Re Sabse Bada Tera Naam",
    artist: "Bhakti Bhajan",
    albumTitle: "Maa Durga Bhajan",
    durationMs: 395000,
    imgUrl: "https://i.ytimg.com/vi/ik79ITh2AD8/hqdefault.jpg",
  ),
];

/// Verified Hanuman Ji tracks with valid artwork & playable IDs
final List<Track> kVerifiedHanumanTracks = [
  _buildBhaktiTrack(
    id: "7CwLvXc6",
    title: "Shree Hanuman Chalisa",
    artist: "Hariharan, Traditional",
    albumTitle: "Shree Hanuman Chalisa (Hanuman Ashtak)",
    durationMs: 582000,
    imgUrl:
        "https://c.saavncdn.com/256/Shree-Hanuman-Chalisa-Hanuman-Ashtak-Hindi-1992-20260324161030-500x500.webp",
  ),
  _buildBhaktiTrack(
    id: "In-xltz_",
    title: "Hanuman Chalisa",
    artist: "Hariharan, shivam samrat",
    albumTitle: "Hanuman Chalisa",
    durationMs: 347000,
    imgUrl:
        "https://c.saavncdn.com/741/Hanuman-Chalisa-Sanskrit-2026-20260720104804-150x150.jpg",
  ),
];

/// Verified Ganesh Ji tracks with valid artwork & playable IDs
final List<Track> kVerifiedGaneshTracks = [
  _buildBhaktiTrack(
    id: "ALDWwuwj",
    title: "Jai Ganesh Deva",
    artist: "Anuradha Paudwal",
    albumTitle: "Aarti Vol-3",
    durationMs: 270000,
    imgUrl:
        "https://c.saavncdn.com/065/Aarti-Vol-3-Hindi-1989-20211102161000-150x150.jpg",
  ),
  _buildBhaktiTrack(
    id: "94sdDisK",
    title: "Shree Ganeshay Dheemahi",
    artist: "Shankar Mahadevan",
    albumTitle: "Viruddh... Family Comes First",
    durationMs: 407000,
    imgUrl:
        "https://c.saavncdn.com/592/Viruddh-Family-Comes-First-Hindi-2005-150x150.jpg",
  ),
  _buildBhaktiTrack(
    id: "Pl851a1Z",
    title: "Vakratunda Mahakaya (Ganesh Mantra)",
    artist: "Anuradha Paudwal",
    albumTitle: "Durga Saptashati",
    durationMs: 143000,
    imgUrl:
        "https://c.saavncdn.com/304/Durga-Saptashati-Hindi-2015-20250812103817-150x150.jpg",
  ),
];

/// Verified Ram Ji tracks with valid artwork & playable IDs
final List<Track> kVerifiedRamTracks = [
  _buildBhaktiTrack(
    id: "q3ElTqvW",
    title: "Mere Ghar Ram Aaye Hain",
    artist: "Jubin Nautiyal",
    albumTitle: "Mere Ghar Ram Aaye Hain",
    durationMs: 234000,
    imgUrl:
        "https://c.saavncdn.com/946/Mere-Ghar-Ram-Aaye-Hain-Hindi-2022-20221019191009-150x150.jpg",
  ),
  _buildBhaktiTrack(
    id: "dBM1AsPC",
    title: "Ram Siya Ram",
    artist: "Sachet-Parampara, Sachet Tandon, Parampara Tandon",
    albumTitle: "Adipurush",
    durationMs: 230000,
    imgUrl:
        "https://c.saavncdn.com/972/Adipurush-Hindi-2023-20230607184755-150x150.jpg",
  ),
  _buildBhaktiTrack(
    id: "GQOZ52ac",
    title: "Raghupati Raghav Raja Ram",
    artist: "Sachet Tandon",
    albumTitle: "Raghupati Raghav Raja Ram",
    durationMs: 196000,
    imgUrl:
        "https://c.saavncdn.com/642/Raghupati-Raghav-Raja-Ram-Hindi-2020-20200630234001-150x150.jpg",
  ),
  _buildBhaktiTrack(
    id: "AEHmmhTb",
    title: "Aarti Shri Ramayan Ji Ki",
    artist: "Parul Mishra, Jai Kesarwani",
    albumTitle: "Sampurna Aarti Sangrah",
    durationMs: 350000,
    imgUrl:
        "https://c.saavncdn.com/625/Sampurna-Aarti-Sangrah-Hindi-2018-20180903-150x150.jpg",
  ),
];

/// Verified Khatu Shyam Ji tracks with verified YouTube playback
final List<Track> kVerifiedKhatuShyamTracks = [
  _buildBhaktiYtTrack(
    videoId: "8UzezOZCixs",
    title: "Haara Hun Baba Par Tujhpe Bharosa Hai",
    artist: "Kanhaiya Mittal",
    albumTitle: "Khatu Shyam Ji Bhajan",
    durationMs: 480000,
    imgUrl: "https://i.ytimg.com/vi/8UzezOZCixs/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "-D1PyeK-K6Q",
    title: "Kyu Ghabrau Main Mera To Shyam Se Nata Hai",
    artist: "Kanhaiya Mittal",
    albumTitle: "Khatu Shyam Bhajan",
    durationMs: 512000,
    imgUrl: "https://i.ytimg.com/vi/-D1PyeK-K6Q/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "fBXOpdifPsA",
    title: "Bulawa Aawega Khatu Se Ek Bar",
    artist: "Sanjay Mittal",
    albumTitle: "Khatu Shyam Ji Bhajan",
    durationMs: 440000,
    imgUrl: "https://i.ytimg.com/vi/fBXOpdifPsA/hqdefault.jpg",
  ),
];

/// Verified Shiv Ji tracks with valid artwork & playable IDs
final List<Track> kVerifiedShivTracks = [
  _buildBhaktiTrack(
    id: "RciMpqOj",
    title: "Om Namah Shivaya Har Har",
    artist: "Anuradha Paudwal",
    albumTitle: "Om Namah Shivaya By Anuradha Paudwal",
    durationMs: 1416000,
    imgUrl:
        "https://c.saavncdn.com/601/Om-Namah-Shivaya-By-Anuradha-Paudwal-Hindi-2021-20210426234746-150x150.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "L-y1sr1qUlE",
    title: "Maha Mrityunjaya Mantra",
    artist: "Anuradha Paudwal",
    albumTitle: "Maha Mrityunjaya Mantra",
    durationMs: 420000,
    imgUrl: "https://i.ytimg.com/vi/L-y1sr1qUlE/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "S980-z1qx3g",
    title: "Shiv Tandav Stotram",
    artist: "Shankar Mahadevan",
    albumTitle: "Shiv Tandav Stotram",
    durationMs: 554000,
    imgUrl: "https://i.ytimg.com/vi/S980-z1qx3g/hqdefault.jpg",
  ),
];

/// Verified Radha–Krishna tracks with verified YouTube playback
final List<Track> kVerifiedRadhaKrishnaTracks = [
  _buildBhaktiYtTrack(
    videoId: "FEMR5alT7CY",
    title: "Aarti Kunj Bihari Ki",
    artist: "Anuradha Paudwal",
    albumTitle: "Aarti Kunj Bihari Ki",
    durationMs: 297000,
    imgUrl: "https://i.ytimg.com/vi/FEMR5alT7CY/hqdefault.jpg",
  ),
  _buildBhaktiYtTrack(
    videoId: "AEjEMXYFU0A",
    title: "Radhe Radhe Radhe Barsane Wali Radhe",
    artist: "Gaurav Krishna Goswami",
    albumTitle: "Radhe Radhe Barsane Wali",
    durationMs: 380000,
    imgUrl: "https://i.ytimg.com/vi/AEjEMXYFU0A/hqdefault.jpg",
  ),
];

class BhaktiCategory {
  final String name;
  final String query;
  final String tag;

  const BhaktiCategory({
    required this.name,
    required this.query,
    required this.tag,
  });
}

const List<BhaktiCategory> kBhaktiCategories = [
  BhaktiCategory(
    name: 'Mata Rani & Mahakali Special',
    query: 'Mata Rani Bhajans Bhenten Lakhbir Singh Lakkha',
    tag: 'Curated',
  ),
  BhaktiCategory(
    name: 'Radha–Krishna',
    query: 'Radha Krishna Bhajans Kirtan',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Shiv Ji',
    query: 'Shiv Ji Bhajans Mahadev Aarti Shiv Tandav',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Hanuman Ji',
    query: 'Hanuman Chalisa Bajrang Baan Sundarkand',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Ram Ji',
    query: 'Shree Ram Bhajans Ram Siya Ram Aarti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Khatu Shyam Ji',
    query: 'Khatu Shyam Ji Bhajans Kirtan',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Ganesh Ji',
    query: 'Ganesh Aarti Ganpati Bhajans Stuti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Durga Maa / Mata Rani',
    query: 'Durga Mata Aarti Mata Rani Bhajans Bhenten',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Maa Lakshmi',
    query: 'Maa Lakshmi Aarti Mahalakshmi Ashtakam',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Maa Mahakali',
    query: 'Mahakali Stotram Maa Kali Aarti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Saraswati Ji',
    query: 'Saraswati Vandana Stotram Aarti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Vitthal–Rukmini',
    query: 'Vitthal Rukmini Abhang Pandharpur Bhajans',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Vishnu Ji',
    query: 'Vishnu Sahasranamam Narayan Aarti Stotram',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Sai Baba',
    query: 'Shirdi Sai Baba Aarti Bhajans',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Maa Parvati',
    query: 'Gauri Parvati Aarti Stotram',
    tag: 'Deity',
  ),
  // Regional Traditions
  BhaktiCategory(
    name: 'Maharashtra: Abhang & Warkari',
    query: 'Sant Tukaram Dnyaneshwar Vitthal Abhang Marathi',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'Gujarat: Krishna & Garba Bhajans',
    query: 'Gujarati Krishna Bhajans Prabhatiya Mataji Na Garba',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'Punjab: Shabad Kirtan',
    query: 'Gurbani Shabad Kirtan Waheguru Simran',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'Bengal: Devotional & Kirtan',
    query: 'Bengali Kirtan Shyama Sangeet Krishna Nam',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'South Indian Devotional',
    query: 'South Indian Carnatic Devotional Songs Tamil Telugu Kannada',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'North Indian Bhajans',
    query: 'North Indian Bhajans Khatu Shyam Mata Rani Jagran',
    tag: 'Regional',
  ),
];

class BhaktiSpiritualSection extends StatefulWidget {
  final String pluginId;

  const BhaktiSpiritualSection({super.key, required this.pluginId});

  @override
  State<BhaktiSpiritualSection> createState() => _BhaktiSpiritualSectionState();
}

class _BhaktiSpiritualSectionState extends State<BhaktiSpiritualSection> {
  late BhaktiCategory _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _isExpanded = false;

  static const int _kInitialVisibleCount = 4;

  final Map<String, List<Track>> _bhaktiCache = {};
  final Set<String> _providerLoadedCategories = {};
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    // Pre-seed curated special collections with verified tracks
    _bhaktiCache['Mata Rani & Mahakali Special'] = [
      ...kVerifiedBhaktiTracks,
      ...kVerifiedDevotionalPlaylistTracks,
    ];
    _bhaktiCache['Hanuman Ji'] = List.of(kVerifiedHanumanTracks);
    _bhaktiCache['Ganesh Ji'] = List.of(kVerifiedGaneshTracks);
    _bhaktiCache['Ram Ji'] = List.of(kVerifiedRamTracks);
    _bhaktiCache['Khatu Shyam Ji'] = List.of(kVerifiedKhatuShyamTracks);
    _bhaktiCache['Shiv Ji'] = List.of(kVerifiedShivTracks);
    _bhaktiCache['Radha–Krishna'] = List.of(kVerifiedRadhaKrishnaTracks);
    _selectedCategory = kBhaktiCategories.first;
    _fetchBhaktiTracks(_selectedCategory);
  }

  Future<void> _fetchBhaktiTracks(BhaktiCategory cat) async {
    final requestId = ++_activeRequestId;

    if (!shouldFetchBhaktiTracks(
      hasProviderResults: _providerLoadedCategories.contains(cat.name),
    )) {
      setState(() {
        _selectedCategory = cat;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _selectedCategory = cat;
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: cat.query,
            filter: ContentSearchFilter.track,
          ),
        ),
      );

      if (!mounted) return;

      response.when(
        search: (results) {
          final tracks = <Track>[];
          // Prepend verified tracks for curated and deity categories
          if (cat.name == 'Mata Rani & Mahakali Special' ||
              cat.name.contains('Durga') ||
              cat.name.contains('Mahakali')) {
            tracks.addAll(kVerifiedBhaktiTracks);
            tracks.addAll(kVerifiedDevotionalPlaylistTracks);
          } else if (cat.name == 'Hanuman Ji') {
            tracks.addAll(kVerifiedHanumanTracks);
          } else if (cat.name == 'Ganesh Ji') {
            tracks.addAll(kVerifiedGaneshTracks);
          } else if (cat.name == 'Ram Ji') {
            tracks.addAll(kVerifiedRamTracks);
          } else if (cat.name == 'Khatu Shyam Ji') {
            tracks.addAll(kVerifiedKhatuShyamTracks);
          } else if (cat.name == 'Shiv Ji') {
            tracks.addAll(kVerifiedShivTracks);
          } else if (cat.name == 'Radha–Krishna') {
            tracks.addAll(kVerifiedRadhaKrishnaTracks);
          }

          for (final item in results.items) {
            item.when(
              track: (t) => tracks.add(t),
              album: (_) {},
              artist: (_) {},
              playlist: (_) {},
            );
          }
          final seenIds = <String>{};
          final deduplicated = <Track>[];
          for (final t in tracks) {
            if (t.id.isNotEmpty && seenIds.add(t.id)) {
              deduplicated.add(t);
            }
          }

          _bhaktiCache[cat.name] = deduplicated;
          _providerLoadedCategories.add(cat.name);

          if (requestId == _activeRequestId) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        trackDetails: (_) {},
        albumDetails: (_) {},
        artistDetails: (_) {},
        playlistDetails: (_) {},
        streams: (_) {},
        moreTracks: (_) {},
        moreAlbums: (_) {},
        homeSections: (_) {},
        loadMoreItems: (_) {},
        charts: (_) {},
        chartDetails: (_) {},
        segments: (_) {},
        lyricsResult: (_) {},
        lyricsSearchResults: (_) {},
        lyricsById: (_, __) {},
        suggestions: (_) {},
        canHandle: (_) {},
        collectionInfo: (_) {},
        importTracks: (_) {},
        ack: () {},
      );
    } catch (e) {
      if (mounted && requestId == _activeRequestId) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load ${cat.name} devotional songs';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTracks = _bhaktiCache[_selectedCategory.name] ?? const [];
    final visibleCount = _isExpanded
        ? currentTracks.length
        : (currentTracks.length > _kInitialVisibleCount
            ? _kInitialVisibleCount
            : currentTracks.length);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE65100).withValues(alpha: 0.20),
            const Color(0xFF4A148C).withValues(alpha: 0.15),
            Default_Theme.themeColor,
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                ),
                child: const Icon(
                  MingCute.sun_fill,
                  size: 18,
                  color: Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bhakti & Spiritual',
                style: Default_Theme.primaryTextStyle.merge(
                  const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
              ),
              const Spacer(),
              if (currentTracks.isNotEmpty)
                Text(
                  '${currentTracks.length} Bhajans',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sacred bhajans, aartis, kirtans, and devotional traditions across India.',
            style: TextStyle(
              fontSize: 13,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Category selection chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: kBhaktiCategories.map((cat) {
                final isSelected = _selectedCategory.name == cat.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    onSelected: (val) => _fetchBhaktiTracks(cat),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    selectedColor:
                        const Color(0xFFFFB300).withValues(alpha: 0.25),
                    checkmarkColor: const Color(0xFFFFB300),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFFFFD54F)
                          : Default_Theme.primaryColor1.withValues(alpha: 0.75),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFFFB300)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading && currentTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB300)),
              ),
            )
          else if (_error != null && currentTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text(_error!,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _fetchBhaktiTracks(_selectedCategory),
                      icon: const Icon(MingCute.refresh_3_line, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (currentTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SignBoardWidget(
                  message:
                      'No devotional tracks found for ${_selectedCategory.name}',
                  icon: MingCute.sun_line,
                ),
              ),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Could not refresh devotional songs. Showing saved tracks.',
                  style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(
                            tracks: currentTracks,
                            title: '${_selectedCategory.name} Bhakti',
                          ),
                          doPlay: true,
                          idx: 0,
                          isFromPlaylist: false,
                        );
                  },
                  icon: const Icon(MingCute.play_fill, size: 16),
                  label: const Text('Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(
                            tracks: currentTracks,
                            title: '${_selectedCategory.name} Bhakti',
                          ),
                          doPlay: true,
                          shuffling: true,
                          isFromPlaylist: false,
                        );
                  },
                  icon: const Icon(MingCute.shuffle_line, size: 16),
                  label: const Text('Shuffle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleCount,
              itemBuilder: (context, index) {
                final track = currentTracks[index];
                return SongCardWidget(
                  song: track,
                  onOptionsTap: () => showMoreBottomSheet(
                    context,
                    track,
                    showDelete: false,
                    showSinglePlay: true,
                  ),
                  onTap: () {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(
                            tracks: currentTracks,
                            title: '${_selectedCategory.name} Bhakti',
                          ),
                          doPlay: true,
                          idx: index,
                          isFromPlaylist: false,
                        );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentTracks.length > _kInitialVisibleCount) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded ? MingCute.up_line : MingCute.down_line,
                      size: 16,
                      color: const Color(0xFFFFD54F),
                    ),
                    label: Text(
                      _isExpanded
                          ? 'Show less'
                          : 'Show more (${currentTracks.length - _kInitialVisibleCount} more)',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: () => SearchNavigation.openWithPrefill(
                    context,
                    _selectedCategory.query,
                  ),
                  icon: const Icon(
                    MingCute.list_check_line,
                    size: 16,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    'Explore More',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
