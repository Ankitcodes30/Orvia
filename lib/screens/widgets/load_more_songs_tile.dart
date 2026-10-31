import 'package:flutter/material.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// A compact, theme-aligned row placed at the bottom of song lists
/// in Album and Artist pages to discover more songs on demand.
class LoadMoreSongsTile extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final VoidCallback onTap;
  final String title;
  final int? currentCount;

  const LoadMoreSongsTile({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.error,
    required this.onTap,
    this.title = 'Load more songs',
    this.currentCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore && error == null) {
      if (currentCount == null || currentCount! <= 0) {
        return const SizedBox.shrink();
      }
      return Padding(
        key: const Key('load_more_songs_ended'),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text(
            'All $currentCount songs loaded',
            style: TextStyle(
              fontSize: 12,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        key: const Key('load_more_songs_retry'),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Center(
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
              decoration: BoxDecoration(
                color: Default_Theme.accentColor2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Default_Theme.accentColor2.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    MingCute.refresh_3_line,
                    size: 16,
                    color: Default_Theme.accentColor2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Failed to load more. Tap to retry',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Default_Theme.accentColor2,
                    ).merge(Default_Theme.secondoryTextStyleMedium),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('load_more_songs_button'),
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      key: Key('load_more_songs_loading'),
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Default_Theme.accentColor2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading more songs...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
                      ).merge(Default_Theme.secondoryTextStyleMedium),
                    ),
                  ] else ...[
                    const Icon(
                      MingCute.down_line,
                      size: 16,
                      color: Default_Theme.accentColor2,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Default_Theme.primaryColor1,
                      ).merge(Default_Theme.secondoryTextStyleMedium),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
