import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/plugins/utils/media_id.dart';

class NavratriTrackItem {
  final Track track;
  final String filterTag;

  const NavratriTrackItem({
    required this.track,
    required this.filterTag,
  });
}

Track _buildNavratriTrack({
  required String id,
  required String title,
  required String artist,
  required int durationMs,
  required String imgUrl,
  required String albumTitle,
}) {
  final stampedId = isStampedId(id) ? id : buildMediaId(kDefaultSaavnPluginId, id);
  return Track(
    id: stampedId,
    title: title,
    artists: [ArtistSummary(id: '', name: artist)],
    album: AlbumSummary(id: '', title: albumTitle, artists: const []),
    durationMs: BigInt.from(durationMs),
    thumbnail: Artwork(
      url: imgUrl,
      urlHigh: imgUrl,
      layout: ImageLayout.square,
    ),
    isExplicit: false,
  );
}

final List<NavratriTrackItem> kVerifiedNavratriTracks = [
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "0qcITrST",
      title: "Tari Madh Mithi Madh Mithi Vaate",
      artist: "Jigardan Gadhavi",
      durationMs: 124000,
      imgUrl:
          "https://c.saavncdn.com/418/Tari-Madh-Mithi-Madh-Mithi-Vaate-Gujarati-2021-20211128113113-500x500.webp",
      albumTitle: "Tari Madh Mithi Madh Mithi Vaate",
    ),
    filterTag: "Garba",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "n4z_Fdyo",
      title: "Gori Radha Ne Kalo Kaan",
      artist: "DHARAMVEER",
      durationMs: 103000,
      imgUrl:
          "https://c.saavncdn.com/124/Gori-Radha-Ne-Kalo-Kaan-Gujarati-2026-20261006132514-500x500.webp",
      albumTitle: "Gori Radha Ne Kalo Kaan",
    ),
    filterTag: "Dandiya",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "UXmSGgYg",
      title: "Dholida",
      artist: "Udit Narayan, Neha Kakkar, Palak Muchhal",
      durationMs: 216000,
      imgUrl:
          "https://c.saavncdn.com/401/Loveyatri-A-Journey-Of-Love-Hindi-2018-20181003-500x500.jpg",
      albumTitle: "Loveyatri - A Journey Of Love",
    ),
    filterTag: "Bollywood Garba",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "qIssG4RV",
      title: "Non Stop Garba by Falguni Pathak",
      artist: "Falguni Pathak",
      durationMs: 4615000,
      imgUrl:
          "https://c.saavncdn.com/374/Non-Stop-Garba-by-Falguni-Pathak-Gujarati-2022-20220919193312-500x500.webp",
      albumTitle: "Non Stop Garba by Falguni Pathak",
    ),
    filterTag: "Dandiya",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "Lyec1Osb",
      title: "Hansla (Feat. Aditya Gadhvi)",
      artist: "Aditya Gadhvi, Folk Box",
      durationMs: 244000,
      imgUrl: "https://c.saavncdn.com/808/Hansla-Gujarati-2015-500x500.jpg",
      albumTitle: "Hansla",
    ),
    filterTag: "Devotional",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "hhdJ6Cvt",
      title: "Rasiyo Rupalo Rang Reliyo",
      artist: "Traditional Folk",
      durationMs: 100000,
      imgUrl:
          "https://c.saavncdn.com/012/Garba-Ni-Ramzat-4-0-Gujarati-2025-20250915190648-500x500.webp",
      albumTitle: "Garba Ni Ramzat 4.0",
    ),
    filterTag: "Traditional / Folk",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "1bBcCRbB",
      title: "Pethalpur Ma Pawo Vaagyo",
      artist: "Praful Dave, Vatsala",
      durationMs: 355000,
      imgUrl: "https://c.saavncdn.com/342/Kalaja-No-Katako-1990-500x500.jpg",
      albumTitle: "Kadja No Katko",
    ),
    filterTag: "Traditional / Folk",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "hx_Jz6GL",
      title: "Kesariyo Rang",
      artist: "Asees Kaur, Dev Negi, Lijo George",
      durationMs: 193000,
      imgUrl:
          "https://c.saavncdn.com/478/Kesariyo-Rang-Hindi-2022-20240926203647-500x500.webp",
      albumTitle: "Kesariyo Rang",
    ),
    filterTag: "Bollywood Garba",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "rVYG1boa",
      title: "Chogada",
      artist: "Darshan Raval, Asees Kaur",
      durationMs: 249000,
      imgUrl:
          "https://c.saavncdn.com/179/World-Music-Day-Best-Of-Bollywood-Hits-Hindi-2026-20260622111029-500x500.webp",
      albumTitle: "World Music Day - Best Of Bollywood Hits",
    ),
    filterTag: "Bollywood Garba",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "g09aK6ce",
      title: "Dholida Dhol Re Vagadi Mandli Garba",
      artist: "Gujarati Folk Band",
      durationMs: 289000,
      imgUrl:
          "https://c.saavncdn.com/712/Raatladi-The-Mandli-Garba-Laal-Ishq-Gujarati-2025-20250923132148-500x500.webp",
      albumTitle: "Raatladi The Mandli Garba (Laal Ishq)",
    ),
    filterTag: "Garba",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "c69Skc-T",
      title: "Gori Radha Ne Kado Kaan",
      artist: "Divya Kumar, Sachin-Jigar",
      durationMs: 308000,
      imgUrl:
          "https://c.saavncdn.com/712/Wrong-Side-Raju-Gujarati-2016-500x500.jpg",
      albumTitle: "Wrong Side Raju",
    ),
    filterTag: "Dandiya",
  ),
  NavratriTrackItem(
    track: _buildNavratriTrack(
      id: "rSBU4cMG",
      title: "Dholida Dhol Re Vagad (Khelaiya Disco Dandiya)",
      artist: "Khelaiya",
      durationMs: 481000,
      imgUrl:
          "https://c.saavncdn.com/664/Khelaiya-Disco-Dandiya-Hits-Vol-1-Gujarati-2021-20260615175408-500x500.jpg",
      albumTitle: "Khelaiya Disco Dandiya Hits, Vol. 1",
    ),
    filterTag: "Traditional / Folk",
  ),
];

class NavratriSpecialSection extends StatefulWidget {
  const NavratriSpecialSection({super.key});

  @override
  State<NavratriSpecialSection> createState() => _NavratriSpecialSectionState();
}

class _NavratriSpecialSectionState extends State<NavratriSpecialSection> {
  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Garba',
    'Dandiya',
    'Traditional / Folk',
    'Bollywood Garba',
    'Devotional',
  ];

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedFilter == 'All'
        ? kVerifiedNavratriTracks
        : kVerifiedNavratriTracks
            .where((item) => item.filterTag == _selectedFilter)
            .toList();

    final allTracks = filteredItems.map((e) => e.track).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B2500).withValues(alpha: 0.35),
            const Color(0xFF4A0E17).withValues(alpha: 0.25),
            Default_Theme.themeColor,
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.6),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MingCute.fire_fill, size: 14, color: Color(0xFFFF7A00)),
                    SizedBox(width: 4),
                    Text(
                      'FESTIVE SPECIAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${filteredItems.length} Tracks',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Navratri Special 2026 — Garba, Dandiya & Mataji Na Garba',
            style: Default_Theme.primaryTextStyle.merge(
              const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Default_Theme.primaryColor1,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Non-stop energetic garba beats, classic folk, dandiya raas, and divine Mataji bhajans.',
            style: TextStyle(
              fontSize: 13,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Interactive filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedFilter = filter);
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    selectedColor: const Color(0xFFFF7A00).withValues(alpha: 0.25),
                    checkmarkColor: const Color(0xFFFF7A00),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFFFF9B40)
                          : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFFF7A00)
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
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: allTracks.isEmpty
                    ? null
                    : () {
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: allTracks,
                                title:
                                    'Navratri Special 2026 ($_selectedFilter)',
                              ),
                              doPlay: true,
                              idx: 0,
                            );
                      },
                icon: const Icon(MingCute.play_fill, size: 16),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: allTracks.isEmpty
                    ? null
                    : () {
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: allTracks,
                                title:
                                    'Navratri Special 2026 ($_selectedFilter)',
                              ),
                              doPlay: true,
                              shuffling: true,
                            );
                      },
                icon: const Icon(MingCute.shuffle_line, size: 16),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Song cards list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return SongCardWidget(
                song: item.track,
                onOptionsTap: () => showMoreBottomSheet(
                  context,
                  item.track,
                  showDelete: false,
                  showSinglePlay: true,
                ),
                onTap: () {
                  context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                        Playlist(
                          tracks: allTracks,
                          title: 'Navratri Special 2026',
                        ),
                        doPlay: true,
                        idx: index,
                      );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
