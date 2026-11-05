import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class DiwaliTrackItem {
  final Track track;
  final String filterTag;

  const DiwaliTrackItem({
    required this.track,
    required this.filterTag,
  });
}

const String _kDiwaliYtPluginId = 'content-resolver.bloomfactory.ytvideo';

Track _buildDiwaliTrack({
  required String videoId,
  required String title,
  required String artist,
  required int durationMs,
  required String albumTitle,
}) {
  final compositeId = '$_kDiwaliYtPluginId::$videoId';
  final artwork = Artwork(
    url: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
    urlLow: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
    urlHigh: 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
    layout: ImageLayout.square,
  );
  return Track(
    id: compositeId,
    title: title,
    artists: [
      ArtistSummary(id: '', name: artist, thumbnail: artwork),
    ],
    album: AlbumSummary(
      id: '',
      title: albumTitle,
      artists: const [],
      thumbnail: artwork,
    ),
    durationMs: BigInt.from(durationMs),
    thumbnail: artwork,
    url: 'https://www.youtube.com/watch?v=$videoId',
    isExplicit: false,
  );
}

final List<DiwaliTrackItem> kVerifiedDiwaliTracks = [
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'yWNPxS0sXnE',
      title: 'Ramayana: Jai Jai Ram',
      artist: 'AR Rahman, Shreya Ghoshal, Arijit Singh',
      durationMs: 128000,
      albumTitle: 'Ramayana',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'z_e1d5_VVfw',
      title: 'Ramayana: Mangal Rang',
      artist: 'AR Rahman, Arijit Singh, Shreya Ghoshal, Kumar V',
      durationMs: 145000,
      albumTitle: 'Ramayana',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: '5k_2d_15f6Y',
      title: 'लक्ष्मी स्तुति | Lakshmi Stuti | Diwali Special Lakshmi Puja',
      artist: 'Power of Chants',
      durationMs: 1170000,
      albumTitle: 'Diwali Special Lakshmi Puja',
    ),
    filterTag: 'Lakshmi Puja & Aarti',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'nxRf-p8KWdM',
      title: 'Mahalakshmi Ashtakam - Prayer for Abundance & Divine Grace',
      artist: 'Religious India',
      durationMs: 3827000,
      albumTitle: 'Diwali Special 2025',
    ),
    filterTag: 'Lakshmi Puja & Aarti',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'OgE62AQv5iA',
      title: 'दीपावली नॉनस्टॉप राम भजन - Ram Aayenge To Angana Sajaungi',
      artist: 'Bhakti Group',
      durationMs: 3847000,
      albumTitle: 'Diwali NonStop Ram Bhajan',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: '22bLNq6iCjU',
      title: 'Jai Shree Ram | Ayodhya Ram Mandir Song | Yug Ram Raj Ka',
      artist: 'Hansraj Raghuwanshi',
      durationMs: 348000,
      albumTitle: 'Yug Ram Raj Ka',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: '3TylP-ux8W0',
      title: 'Ram Aayenge',
      artist: 'Vishal Mishra, Payal Dev, Manoj Muntashir',
      durationMs: 283000,
      albumTitle: 'Ram Aayenge',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'q5PmN7SuUkY',
      title: 'Mere Ghar Ram Aaye Hain',
      artist: 'Jubin Nautiyal, Payal Dev, Manoj Muntashir',
      durationMs: 255000,
      albumTitle: 'Mere Ghar Ram Aaye Hain',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'wEU8mWwAcv0',
      title: 'Shri Ram Ki Gali Mein Tum Jana',
      artist: 'Tulsi Kumar, Bhushan Kumar',
      durationMs: 273000,
      albumTitle: 'Shri Ram Ki Gali Mein Tum Jana',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'UuLkjyBKQE4',
      title: 'RAM LALA',
      artist: 'Vishal Mishra, Manoj Muntashir',
      durationMs: 273000,
      albumTitle: 'RAM LALA',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: '6fQzvZpBzj8',
      title: 'Ye Chamak Ye Damak 2.0 | Sab Kuch Sarkar Tumhi Se Hai',
      artist: 'Sudhir Vyas, Ak Digital',
      durationMs: 348000,
      albumTitle: 'Ye Chamak Ye Damak 2.0',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'wVrz52oz_T8',
      title: 'नगरी हो अयोध्या सी | Nagri Ho Ayodhya Si',
      artist: 'प्रकाश गाँधी | PMC Sant Sandesh',
      durationMs: 482000,
      albumTitle: 'Nagri Ho Ayodhya Si',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'Ekymhpz8oUM',
      title: 'जरा देर ठहरो राम तमन्ना यही है',
      artist: 'Katha Puraan Bhajan',
      durationMs: 292000,
      albumTitle: 'जरा देर ठहरो राम',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'txXXRMfp12w',
      title: 'Ram Siya Ram',
      artist: 'Sachet Tandon, Poonam Thakkar, Shabbir Ahmed',
      durationMs: 259000,
      albumTitle: 'Ram Siya Ram',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'leVoi6kkp3o',
      title: 'Shree Ram Stuti',
      artist: 'Sonika Sharma Agarwal, Vickky Agarwal',
      durationMs: 199000,
      albumTitle: 'Shree Ram Stuti',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'yFyP0dMx5cw',
      title: 'मंगल भवन अमंगल हारी | Ram Siya Ram | Ramayan Chaupai',
      artist: 'Medi Tuner',
      durationMs: 148000,
      albumTitle: 'Ramayan Chaupai',
    ),
    filterTag: 'Ram Bhajans',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'H2r9M66CQPk',
      title: 'Ghar Me Padharo Laxmi Maiya घर में पधारो लक्ष्मी मैया',
      artist: 'Nova Spiritual India',
      durationMs: 370000,
      albumTitle: 'Laxmi Mata Bhajan',
    ),
    filterTag: 'Lakshmi Puja & Aarti',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'oec7CXRAfeE',
      title: 'लक्ष्मी आरती हिंदी | Om Jai Laxmi Mata',
      artist: 'Shemaroo Bhakti',
      durationMs: 587000,
      albumTitle: 'Mata Laxmi Aarti',
    ),
    filterTag: 'Lakshmi Puja & Aarti',
  ),
  DiwaliTrackItem(
    track: _buildDiwaliTrack(
      videoId: 'dxVa3AaPvy8',
      title: 'धनतेरस स्पेशल नॉनस्टॉप भजन | Kuber Laxmi Bhajan',
      artist: 'Ganga Bhakti',
      durationMs: 1964000,
      albumTitle: 'Dhanteras Ke Bhajan',
    ),
    filterTag: 'Lakshmi Puja & Aarti',
  ),
];

class DiwaliSpecialSection extends StatefulWidget {
  const DiwaliSpecialSection({super.key});

  @override
  State<DiwaliSpecialSection> createState() => _DiwaliSpecialSectionState();
}

class _DiwaliSpecialSectionState extends State<DiwaliSpecialSection> {
  String _selectedFilter = 'All';
  bool _isExpanded = false;

  static const int _kInitialVisibleCount = 4;

  static const List<String> _filters = [
    'All',
    'Ram Bhajans',
    'Lakshmi Puja & Aarti',
  ];

  @override
  Widget build(BuildContext context) {
    final seenIds = <String>{};
    final uniqueItems = <DiwaliTrackItem>[];
    for (final item in kVerifiedDiwaliTracks) {
      if (item.track.id.isNotEmpty && seenIds.add(item.track.id)) {
        uniqueItems.add(item);
      }
    }

    final filteredItems = _selectedFilter == 'All'
        ? uniqueItems
        : uniqueItems
            .where((item) => item.filterTag == _selectedFilter)
            .toList();

    final allTracks = filteredItems.map((e) => e.track).toList();
    final visibleCount = _isExpanded
        ? filteredItems.length
        : (filteredItems.length > _kInitialVisibleCount
            ? _kInitialVisibleCount
            : filteredItems.length);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5A3000).withValues(alpha: 0.45),
            const Color(0xFF2A1005).withValues(alpha: 0.35),
            Default_Theme.themeColor,
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.35),
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
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MingCute.sparkles_fill,
                        size: 14, color: Color(0xFFFFB300)),
                    SizedBox(width: 4),
                    Text(
                      'DIWALI SPECIAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFFFFB300),
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
            'Diwali Festive Special 2026 — Devotional Ram Bhajans & Lakshmi Aarti',
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
            'Sacred celebration of lights with divine Ram Bhajans, Mahalakshmi Ashtakam, and soulful festive aartis.',
            style: TextStyle(
              fontSize: 13,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    selectedColor: const Color(0xFFFF9800),
                    checkmarkColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFFB300)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
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
                                    'Diwali Special 2026 ($_selectedFilter)',
                              ),
                              doPlay: true,
                              idx: 0,
                              isFromPlaylist: false,
                            );
                      },
                icon: const Icon(MingCute.play_fill, size: 16),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
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
                                    'Diwali Special 2026 ($_selectedFilter)',
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleCount,
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
                          title: 'Diwali Special 2026',
                        ),
                        idx: index,
                        doPlay: true,
                        isFromPlaylist: false,
                      );
                },
              );
            },
          ),
          if (filteredItems.length > _kInitialVisibleCount) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded
                      ? MingCute.up_line
                      : MingCute.down_line,
                  size: 16,
                  color: const Color(0xFFFFB300),
                ),
                label: Text(
                  _isExpanded
                      ? 'Show Less'
                      : 'View All (${filteredItems.length} Songs)',
                  style: const TextStyle(
                    color: Color(0xFFFFB300),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DiwaliSpecialScreen extends StatelessWidget {
  const DiwaliSpecialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        title: const Text(
          'Diwali Festive Special 2026',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: 120),
        child: DiwaliSpecialSection(),
      ),
    );
  }
}
