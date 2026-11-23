import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/blocs/history/cubit/history_cubit.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/utils/load_image.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  int _totalPlayCount = 0;
  Duration _totalListeningTime = Duration.zero;
  List<_StatTrack> _topTracks = [];
  List<_StatArtist> _topArtists = [];
  List<int> _weekdayPlays = List.filled(7, 0); // Mon (0) to Sun (6)

  @override
  void initState() {
    super.initState();
    _computeStatistics();
  }

  Future<void> _computeStatistics() async {
    final historyDao = context.read<HistoryCubit>().historyDao;
    final rawHistory = await historyDao.getRawHistory(limit: 0);

    int totalSeconds = 0;
    final trackCounts = <String, _TrackCounter>{};
    final artistCounts = <String, int>{};
    final weekdayCounts = List.filled(7, 0);

    for (final entry in rawHistory) {
      final track = entry.track.value;
      if (track == null) continue;

      final durSec = (track.durationMs ?? 0) ~/ 1000;
      totalSeconds += durSec;

      final artistStr = track.artists?.map((a) => a.name).join(', ') ?? 'Unknown Artist';
      final thumbUrl = track.thumbnail?.url;

      // Track count
      final counter = trackCounts.putIfAbsent(
        track.mediaId,
        () => _TrackCounter(
          mediaId: track.mediaId,
          title: track.title,
          artist: artistStr,
          thumbnailUrl: thumbUrl,
        ),
      );
      counter.count++;

      // Artist count
      final artistName = artistStr.trim();
      if (artistName.isNotEmpty && artistName != 'Unknown Artist') {
        artistCounts[artistName] = (artistCounts[artistName] ?? 0) + 1;
      }

      // Weekday (DateTime.weekday is 1 for Mon, 7 for Sun)
      final weekdayIdx = entry.playedAt.weekday - 1;
      if (weekdayIdx >= 0 && weekdayIdx < 7) {
        weekdayCounts[weekdayIdx]++;
      }
    }

    final sortedTracks = trackCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final topTracksList = sortedTracks.take(5).map((e) => _StatTrack(
      title: e.title,
      artist: e.artist,
      thumbnailUrl: e.thumbnailUrl,
      count: e.count,
    )).toList();

    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtistsList = sortedArtists.take(5).map((e) => _StatArtist(
      name: e.key,
      count: e.value,
    )).toList();

    if (mounted) {
      setState(() {
        _totalPlayCount = rawHistory.length;
        _totalListeningTime = Duration(seconds: totalSeconds);
        _topTracks = topTracksList;
        _topArtists = topArtistsList;
        _weekdayPlays = weekdayCounts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _totalListeningTime.inHours;
    final minutes = _totalListeningTime.inMinutes.remainder(60);

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Default_Theme.primaryColor1),
        title: const Text(
          'Listening Statistics',
          style: TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Default_Theme.accentColor2),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero KPI Cards ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Listened',
                          value: '${hours}h ${minutes}m',
                          icon: MingCute.time_line,
                          accentColor: Default_Theme.accentColor2,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Plays',
                          value: '$_totalPlayCount songs',
                          icon: MingCute.play_circle_line,
                          accentColor: Colors.tealAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Weekly Activity Chart ──
                  _buildWeeklyActivitySection(),
                  const SizedBox(height: 24),

                  // ── Top 5 Tracks ──
                  if (_topTracks.isNotEmpty) ...[
                    _buildTopTracksSection(),
                    const SizedBox(height: 24),
                  ],

                  // ── Top 5 Artists ──
                  if (_topArtists.isNotEmpty) ...[
                    _buildTopArtistsSection(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Default_Theme.primaryColor1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivitySection() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxPlays = _weekdayPlays.fold<int>(0, (m, c) => c > m ? c : m);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Default_Theme.primaryColor1.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Rhythm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Default_Theme.primaryColor1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final count = _weekdayPlays[i];
              final factor = maxPlays > 0 ? (count / maxPlays).clamp(0.08, 1.0) : 0.08;
              final isMax = count == maxPlays && maxPlays > 0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMax ? Default_Theme.accentColor2 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 24,
                    height: 90 * factor,
                    decoration: BoxDecoration(
                      color: isMax ? Default_Theme.accentColor2 : Default_Theme.primaryColor1.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isMax ? FontWeight.bold : FontWeight.w500,
                      color: isMax ? Default_Theme.accentColor2 : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTracksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Songs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Default_Theme.primaryColor1,
          ),
        ),
        const SizedBox(height: 12),
        ..._topTracks.asMap().entries.map((entry) {
          final idx = entry.key;
          final track = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  '#${idx + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: idx == 0 ? Default_Theme.accentColor2 : Colors.grey,
                  ),
                ),
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: LoadImageCached(
                      imageUrl: track.thumbnailUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Default_Theme.primaryColor1,
                        ),
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${track.count} plays',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Default_Theme.accentColor2,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTopArtistsSection() {
    final maxArtistCount = _topArtists.isNotEmpty ? _topArtists.first.count : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Artists',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Default_Theme.primaryColor1,
          ),
        ),
        const SizedBox(height: 12),
        ..._topArtists.asMap().entries.map((entry) {
          final idx = entry.key;
          final artist = entry.value;
          final fraction = (artist.count / maxArtistCount).clamp(0.1, 1.0);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${idx + 1}  ${artist.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Default_Theme.primaryColor1,
                      ),
                    ),
                    Text(
                      '${artist.count} plays',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: Default_Theme.primaryColor1.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      idx == 0 ? Default_Theme.accentColor2 : Colors.tealAccent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TrackCounter {
  final String mediaId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  int count = 0;

  _TrackCounter({
    required this.mediaId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
  });
}

class _StatTrack {
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int count;

  const _StatTrack({
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.count,
  });
}

class _StatArtist {
  final String name;
  final int count;

  const _StatArtist({required this.name, required this.count});
}
