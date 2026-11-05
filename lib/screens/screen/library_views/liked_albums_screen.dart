import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/screens/screen/common_views/album_view.dart';
import 'package:Orvia/screens/widgets/animated_list_item.dart';
import 'package:Orvia/screens/widgets/libitem_tile.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';

/// Screen displaying the user's liked albums as normal saved playlist-style rows.
class LikedAlbumsScreen extends StatelessWidget {
  const LikedAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Default_Theme.themeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            MingCute.left_line,
            color: Default_Theme.primaryColor1,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: BlocBuilder<LibraryItemsCubit, LibraryItemsState>(
          builder: (context, state) {
            final count = state.likedAlbums.length;
            final subtitle = count == 1 ? '1 album' : '$count albums';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Liked albums',
                  style: Default_Theme.primaryTextStyle.merge(
                    const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Default_Theme.primaryColor1,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: Default_Theme.secondoryTextStyle.merge(
                    TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Default_Theme.primaryColor2.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: BlocBuilder<LibraryItemsCubit, LibraryItemsState>(
        builder: (context, state) {
          final albums = state.likedAlbums;
          if (albums.isEmpty) {
            return const Center(
              child: SignBoardWidget(
                message: 'No liked albums yet',
                icon: MingCute.album_2_line,
              ),
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList.builder(
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final artistNames = album.artists.isNotEmpty
                        ? album.artists.map((a) => a.name).join(', ')
                        : 'Album';
                    final yearPrefix =
                        (album.year != null && album.year! > 0)
                            ? '${album.year} • '
                            : '';
                    final subtitle = '$yearPrefix$artistNames';
                    final resolvedPluginId =
                        pluginIdOf(album.id) ?? kDefaultSaavnPluginId;

                    return AnimatedListItem(
                      key: ValueKey('liked_album_${album.id}'),
                      index: index,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          LibItemCard(
                            title: album.title,
                            coverArt: album.thumbnail?.url ?? '',
                            subtitle: subtitle,
                            type: LibItemTypes.album,
                            showMenuButton: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AlbumView(
                                    album: album,
                                    pluginId: resolvedPluginId,
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            right: 16,
                            child: IconButton(
                              icon: const Icon(
                                MingCute.heart_fill,
                                color: Default_Theme.accentColor2,
                                size: 22,
                              ),
                              tooltip: 'Unlike album',
                              onPressed: () {
                                context
                                    .read<LibraryItemsCubit>()
                                    .removeRemoteSaved(
                                        album.id, PlaylistType.album);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
