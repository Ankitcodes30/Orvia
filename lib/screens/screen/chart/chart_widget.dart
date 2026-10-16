import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/services/cache/plugin_cache_repository.dart';
import 'package:Orvia/services/plugin_cache_codec.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';
import 'package:flutter/material.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ChartWidget extends StatefulWidget {
  final ChartSummary chart;
  final String pluginId;

  const ChartWidget({
    super.key,
    required this.chart,
    required this.pluginId,
  });

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  String? _resolvedArtworkUrl;

  @override
  void initState() {
    super.initState();
    _checkTopItemArtwork();
  }

  @override
  void didUpdateWidget(ChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart.id != widget.chart.id ||
        oldWidget.chart.thumbnail != widget.chart.thumbnail) {
      _checkTopItemArtwork();
    }
  }

  bool _isGenericIcon(String? url) => isGenericProviderIcon(url);

  Future<void> _checkTopItemArtwork() async {
    final artwork = widget.chart.thumbnail;
    final currentUrl = artwork?.urlHigh ?? artwork?.url ?? artwork?.urlLow;

    if (currentUrl != null && !_isGenericIcon(currentUrl)) {
      if (_resolvedArtworkUrl != currentUrl) {
        setState(() {
          _resolvedArtworkUrl = currentUrl;
        });
      }
      return;
    }

    // Try reading cached chart items to extract genuine track artwork
    try {
      final cacheKey = 'chart_cache::${widget.pluginId}::${widget.chart.id}';
      final cached = await ServiceLocator.pluginCache
          .getCachedWithStaleness<List<ChartItem>>(
        key: cacheKey,
        type: CacheType.chart,
        decode: decodeChartItemsCacheAsync,
        stalenessThreshold: const Duration(hours: 12),
      );

      if (cached.value != null && cached.value!.isNotEmpty) {
        for (final item in cached.value!) {
          final topUrl = item.item.when(
            track: (t) => t.thumbnail.urlHigh ?? t.thumbnail.url,
            album: (a) => a.thumbnail?.urlHigh ?? a.thumbnail?.url,
            artist: (a) => a.thumbnail?.urlHigh ?? a.thumbnail?.url,
            playlist: (p) => p.thumbnail.urlHigh ?? p.thumbnail.url,
          );
          if (topUrl != null &&
              topUrl.isNotEmpty &&
              !isGenericProviderIcon(topUrl) &&
              mounted) {
            setState(() {
              _resolvedArtworkUrl = topUrl;
            });
            break;
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final artwork = widget.chart.thumbnail;
    final fallbackUrl = artwork?.urlHigh ?? artwork?.url ?? artwork?.urlLow;
    final effectiveUrl = _resolvedArtworkUrl ??
        (!_isGenericIcon(fallbackUrl) ? fallbackUrl : null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: isMobile || isTablet
            ? MediaQuery.of(context).size.height * 0.35
            : MediaQuery.of(context).size.height * 0.25,
        width: isMobile
            ? MediaQuery.of(context).size.height * 0.3
            : isTablet
                ? MediaQuery.of(context).size.width * 0.3
                : MediaQuery.of(context).size.width * 0.25,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (effectiveUrl != null && effectiveUrl.isNotEmpty)
              LoadImageCached(
                imageUrl: effectiveUrl,
                fallbackUrl: fallbackUrl,
                fit: BoxFit.cover,
              )
            else
              const _ChartPlaceholder(),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Text(
                widget.chart.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Default_Theme.secondoryTextStyleMedium.merge(
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Default_Theme.primaryColor2.withValues(alpha: 0.08),
      child: Center(
        child: Image.asset(
          'assets/icons/OrviaLogo_System.png',
          width: 56,
          height: 56,
          opacity: const AlwaysStoppedAnimation(0.25),
        ),
      ),
    );
  }
}

