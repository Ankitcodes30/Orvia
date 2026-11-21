import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';

class SmartSlidingBanners extends StatefulWidget {
  final String pluginId;
  final VoidCallback? onFestivalTap;

  const SmartSlidingBanners({
    super.key,
    required this.pluginId,
    this.onFestivalTap,
  });

  @override
  State<SmartSlidingBanners> createState() => _SmartSlidingBannersState();
}

class _SmartSlidingBannersState extends State<SmartSlidingBanners>
    with WidgetsBindingObserver {
  late PageController _pageController;
  Timer? _dateBoundaryTimer;
  Timer? _remoteRefreshTimer;
  bool _remoteRefreshPending = false;
  int _currentPage = 0;
  List<SmartBannerItem> _banners = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(viewportFraction: 0.92);
    _updateBanners();
    _refreshRemoteBanners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateBanners();
      _refreshRemoteBanners();
    }
  }

  void _refreshRemoteBanners() {
    _remoteRefreshTimer?.cancel();
    if (!_remoteRefreshPending) {
      _remoteRefreshPending = true;
      SmartBannerService.refreshRemoteBanners().then((_) {
        _remoteRefreshPending = false;
        if (mounted) _updateBanners();
      });
    }
    _remoteRefreshTimer = Timer(const Duration(hours: 4), () {
      if (mounted) _refreshRemoteBanners();
    });
  }

  void _updateBanners() {
    _dateBoundaryTimer?.cancel();
    final active = SmartBannerService.getActiveBanners();
    if (mounted) {
      setState(() {
        _banners = active;
        if (_currentPage >= _banners.length) {
          _currentPage = 0;
        }
      });
      final nextBoundary = SmartBannerService.nextDateBoundary();
      if (nextBoundary != null) {
        final delay = nextBoundary.difference(DateTime.now());
        _dateBoundaryTimer = Timer(
          delay.isNegative ? Duration.zero : delay,
          _updateBanners,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateBoundaryTimer?.cancel();
    _remoteRefreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _playBanner(SmartBannerItem banner, {int startIndex = 0}) {
    if (banner.tracks.isEmpty) return;
    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
          Playlist(
            tracks: banner.tracks,
            title: banner.title,
          ),
          idx: startIndex,
          doPlay: true,
          isFromPlaylist: false,
        );
  }

  void _openBanner(SmartBannerItem banner) {
    if (banner.destination == 'festival_special' &&
        widget.onFestivalTap != null) {
      widget.onFestivalTap!();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.72,
          decoration: BoxDecoration(
            color: Default_Theme.themeColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: LoadImageCached(
                          imageUrl: banner.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${banner.tracks.length} tracks • ${banner.badge}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        _playBanner(banner);
                      },
                      icon: const Icon(MingCute.play_fill, size: 16),
                      label: const Text('Play All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Default_Theme.accentColor2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: banner.tracks.length,
                  itemBuilder: (context, idx) {
                    final t = banner.tracks[idx];
                    final artworkUrl = [
                      t.thumbnail.urlHigh,
                      t.thumbnail.url,
                      t.thumbnail.urlLow,
                    ].whereType<String>().map((u) => u.trim()).firstWhere(
                          (u) => u.isNotEmpty && !isGenericProviderIcon(u),
                          orElse: () => '',
                        );
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: LoadImageCached(
                            imageUrl: artworkUrl,
                            fallbackUrl: t.thumbnail.url,
                            mediaId: t.id,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        t.artists.map((a) => a.name).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(MingCute.play_circle_line,
                          color: Colors.white38, size: 22),
                      onTap: () {
                        Navigator.pop(modalContext);
                        _playBanner(banner, startIndex: idx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return _buildBannerCard(banner);
            },
          ),
        ),
        if (_banners.length > 1) ...[
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_banners.length, (index) {
                final isSelected = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Default_Theme.accentColor2
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBannerCard(SmartBannerItem banner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => _openBanner(banner),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: banner.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Subtle background shine
                Positioned(
                  right: -30,
                  top: -30,
                  width: 140,
                  height: 140,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (banner.id == 'diwali_festive_2026')
                                const _DiwaliBannerArt()
                              else
                                LoadImageCached(
                                  imageUrl: banner.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              if (banner.tracks.isNotEmpty)
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: GestureDetector(
                                    onTap: () => _playBanner(banner),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Default_Theme.accentColor2,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        MingCute.play_fill,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                banner.badge,
                                style: const TextStyle(
                                  color: Default_Theme.accentColor2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              banner.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        MingCute.right_line,
                        color: Colors.white38,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiwaliBannerArt extends StatelessWidget {
  const _DiwaliBannerArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB02E), Color(0xFFB83212), Color(0xFF39143F)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.wb_twilight_rounded,
            size: 88,
            color: const Color(0xFFFFE5A1).withValues(alpha: 0.25),
          ),
          const Positioned(
            bottom: 4,
            child: Text('🪔', style: TextStyle(fontSize: 38)),
          ),
          const Positioned(
            top: 7,
            right: 8,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFE5A1), size: 17),
          ),
          const Positioned(
            top: 12,
            left: 10,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFE5A1), size: 13),
          ),
        ],
      ),
    );
  }
}
