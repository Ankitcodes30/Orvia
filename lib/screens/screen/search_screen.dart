// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:Orvia/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/blocs/search_suggestions/search_suggestion_bloc.dart';
import 'package:Orvia/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/plugins/blocs/content/content_bloc.dart';
import 'package:Orvia/plugins/blocs/content/content_event.dart';
import 'package:Orvia/plugins/blocs/content/content_state.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_state.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:Orvia/screens/widgets/album_card.dart';
import 'package:Orvia/screens/widgets/artist_card.dart';
import 'package:Orvia/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/multi_select_bar.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/playlist_card.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/src/rust/api/plugin/plugin_info.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart' as plugin_models;

class SearchScreen extends StatefulWidget {
  final String searchQuery;
  final String prefillQuery;
  const SearchScreen({
    Key? key,
    this.searchQuery = "",
    this.prefillQuery = "",
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ContentBloc _contentBloc;
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Highly optimized State Management using Notifiers (Eliminates Root setState)
  final ValueNotifier<ContentSearchFilter> _filterNotifier =
      ValueNotifier(ContentSearchFilter.all);
  final ValueNotifier<String?> _activePluginIdNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isSuggestionPanelOpenNotifier =
      ValueNotifier(false);
  final ValueNotifier<int> _highlightedSuggestionIndexNotifier =
      ValueNotifier(-1);

  List<({String query, ContentSearchFilter filter})>
      _currentCombinedSuggestions = [];

  // Multi-Select Mode
  bool _isMultiSelect = false;
  final Set<String> _selectedTrackIds = {};
  List<Track> _lastTrackList = [];

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedTrackIds.clear();
    });
  }

  void _toggleSelectAll(List<Track> tracks) {
    setState(() {
      if (_selectedTrackIds.length == tracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.addAll(tracks.map((t) => t.id));
      }
    });
  }

  Future<void> _handleMultiLike(List<Track> tracks) async {
    final selected = tracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    await context.read<LibraryItemsCubit>().likeTracks(selected);
    _exitMultiSelect();
  }

  Future<void> _handleMultiAddToPlaylist(List<Track> tracks) async {
    final selected = tracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    await showMultiTrackAddToPlaylistSheet(context, selected);
    _exitMultiSelect();
  }

  Future<void> _handleMultiDownload(List<Track> tracks) async {
    final selected = tracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    final downloader = context.read<DownloaderCubit>();
    int queued = 0;
    for (final t in selected) {
      if (!downloader.isDownloaded(t.id)) {
        await downloader.downloadSong(t, showSnackbar: false);
        queued++;
      }
    }
    SnackbarService.showMessage('Added $queued song${queued == 1 ? '' : 's'} to download queue');
    _exitMultiSelect();
  }

  @override
  void initState() {
    super.initState();
    _contentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _scrollController.addListener(_onSearchScroll);

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _isSuggestionPanelOpenNotifier.value = true;
        context
            .read<SearchSuggestionBloc>()
            .add(SearchSuggestionFetch(_textEditingController.text));
      }
    });

    final pluginState = context.read<PluginBloc>().state;
    final resolvers = pluginState.loadedContentResolvers;
    if (resolvers.isNotEmpty) {
      final activeId = _resolveActivePluginId(resolvers);
      if (activeId != null) {
        _activePluginIdNotifier.value = activeId;
        _contentBloc.add(SetActiveContentPlugin(pluginId: activeId));
      }
    }

    if (widget.searchQuery.isNotEmpty) {
      _textEditingController.text = widget.searchQuery;
      _doSearch(widget.searchQuery);
    } else if (widget.prefillQuery.isNotEmpty) {
      _textEditingController.text = widget.prefillQuery;
    }
  }

  String? _resolveActivePluginId(List<PluginInfo> resolvers) {
    if (resolvers.isEmpty) {
      return null;
    }

    final currentId = _activePluginIdNotifier.value;
    if (currentId != null &&
        resolvers.any((p) => p.manifest.id == currentId)) {
      return currentId;
    }

    final persistedId = context.read<SettingsCubit>().state.searchPluginId;
    if (persistedId.isNotEmpty &&
        resolvers.any((p) => p.manifest.id == persistedId)) {
      return persistedId;
    }

    final saavnPlugin = resolvers.cast<PluginInfo?>().firstWhere(
      (p) => p?.manifest.id == kDefaultSaavnPluginId,
      orElse: () => null,
    );
    if (saavnPlugin != null) {
      return kDefaultSaavnPluginId;
    }

    return resolvers.first.manifest.id;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textEditingController.dispose();
    _searchFocusNode.dispose();
    _filterNotifier.dispose();
    _activePluginIdNotifier.dispose();
    _isSuggestionPanelOpenNotifier.dispose();
    _highlightedSuggestionIndexNotifier.dispose();
    _contentBloc.close();
    super.dispose();
  }

  void _onSearchScroll() {
    if (!_scrollController.hasClients) return;
    final state = _contentBloc.state;
    final nextPageToken = state.searchResults?.nextPageToken;
    if (nextPageToken == null ||
        state.searchStatus == SearchStatus.loading ||
        state.searchStatus == SearchStatus.loadingMore) {
      return;
    }

    final remaining =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    if (remaining <= 400) {
      _contentBloc.add(LoadMoreSearchContent(pageToken: nextPageToken));
    }
  }

  String _normalizeSearchQuery(String query) =>
      query.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _setSearchFieldText(String query) {
    _textEditingController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  void _closeSuggestionPanel() {
    _isSuggestionPanelOpenNotifier.value = false;
    _highlightedSuggestionIndexNotifier.value = -1;
    _searchFocusNode.unfocus();
  }

  void _openSuggestionPanel() {
    _isSuggestionPanelOpenNotifier.value = true;
    _highlightedSuggestionIndexNotifier.value = -1;
  }

  void _performSearch(
      {required String query, required ContentSearchFilter filter}) {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) {
      return;
    }

    var activeId = _activePluginIdNotifier.value;
    if (activeId == null) {
      final resolvers = context.read<PluginBloc>().state.loadedContentResolvers;
      activeId = _resolveActivePluginId(resolvers);
      if (activeId != null) {
        _activePluginIdNotifier.value = activeId;
        _contentBloc.add(SetActiveContentPlugin(pluginId: activeId));
      }
    }

    if (activeId == null) {
      _setSearchFieldText(normalizedQuery);
      return;
    }

    context
        .read<SearchSuggestionBloc>()
        .add(SearchSuggestionSave(normalizedQuery));
    _setSearchFieldText(normalizedQuery);
    _filterNotifier.value = filter;
    _closeSuggestionPanel();
    _contentBloc.add(SearchContent(
      query: normalizedQuery,
      filter: filter,
      pluginId: activeId,
    ));
  }

  void _doSearch(String query) =>
      _performSearch(query: query, filter: _filterNotifier.value);
  void _doSearchInAllCategories(String query) =>
      _performSearch(query: query, filter: ContentSearchFilter.all);
  void _doSearchWithFilter(String query, ContentSearchFilter filter) =>
      _performSearch(query: query, filter: filter);

  void _triggerSearch() {
    if (_textEditingController.text.trim().isNotEmpty) {
      _doSearch(_textEditingController.text);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isSuggestionPanelOpenNotifier.value ||
        _currentCombinedSuggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _highlightedSuggestionIndexNotifier.value =
            (_highlightedSuggestionIndexNotifier.value + 1)
                .clamp(-1, _currentCombinedSuggestions.length - 1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _highlightedSuggestionIndexNotifier.value =
            (_highlightedSuggestionIndexNotifier.value - 1)
                .clamp(-1, _currentCombinedSuggestions.length - 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PluginBloc, PluginState>(
      listenWhen: (prev, curr) {
        if (curr.loadedContentResolvers.isEmpty) return false;
        if (_activePluginIdNotifier.value == null) return true;
        final currentValid = curr.loadedContentResolvers
            .any((p) => p.manifest.id == _activePluginIdNotifier.value);
        if (!currentValid) return true;
        final persistedId = context.read<SettingsCubit>().state.searchPluginId;
        if (persistedId.isEmpty &&
            _activePluginIdNotifier.value != kDefaultSaavnPluginId &&
            curr.loadedContentResolvers
                .any((p) => p.manifest.id == kDefaultSaavnPluginId)) {
          return true;
        }
        return false;
      },
      listener: (context, pluginState) {
        final resolvers = pluginState.loadedContentResolvers;
        final activeId = _resolveActivePluginId(resolvers);
        if (activeId != null) {
          final changed = _activePluginIdNotifier.value != activeId;
          _activePluginIdNotifier.value = activeId;
          _contentBloc.add(SetActiveContentPlugin(pluginId: activeId));

          final pendingQuery = _textEditingController.text.trim();
          if (pendingQuery.isNotEmpty &&
              (_contentBloc.state.searchResults == null || changed)) {
            _performSearch(query: pendingQuery, filter: _filterNotifier.value);
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          _closeSuggestionPanel();
        },
        child: Scaffold(
          backgroundColor: Default_Theme.themeColor,
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: _isMultiSelect
              ? MultiSelectActionBar(
                  selectedCount: _selectedTrackIds.length,
                  totalCount: _lastTrackList.length,
                  onToggleSelectAll: () => _toggleSelectAll(_lastTrackList),
                  onClose: _exitMultiSelect,
                  contextType: MultiSelectContext.discovery,
                  onLike: () => _handleMultiLike(_lastTrackList),
                  onAddToPlaylist: () =>
                      _handleMultiAddToPlaylist(_lastTrackList),
                  onDownload: () => _handleMultiDownload(_lastTrackList),
                )
              : null,
          body: Stack(
            children: [
              // Extracted Background Painter
              _NebulaBackground(contentBloc: _contentBloc),

              SafeArea(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isSuggestionPanelOpenNotifier,
                  builder: (context, isSuggestionPanelOpen, _) {
                    return CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _FloatingSearchBarSliver(
                          textEditingController: _textEditingController,
                          searchFocusNode: _searchFocusNode,
                          handleKeyEvent: _handleKeyEvent,
                          contentBloc: _contentBloc,
                          currentCombinedSuggestions:
                              _currentCombinedSuggestions,
                          highlightedIndexNotifier:
                              _highlightedSuggestionIndexNotifier,
                          onSearchRequested: _performSearch,
                          onClearRequested: () {
                            _textEditingController.clear();
                            _openSuggestionPanel();
                            context
                                .read<SearchSuggestionBloc>()
                                .add(const SearchSuggestionFetch(''));
                            _searchFocusNode.requestFocus();
                          },
                          onQueryChanged: (val) {
                            _openSuggestionPanel();
                            context
                                .read<SearchSuggestionBloc>()
                                .add(SearchSuggestionFetch(val));
                          },
                        ),
                        _AestheticFilterChipsSliver(
                          filterNotifier: _filterNotifier,
                          textEditingController: _textEditingController,
                          onFilterTapped: _triggerSearch,
                        ),
                        if (!isSuggestionPanelOpen)
                          _PluginsGlassyBoxSliver(
                            activePluginNotifier: _activePluginIdNotifier,
                            contentBloc: _contentBloc,
                            onPluginChanged: _triggerSearch,
                            textEditingController: _textEditingController,
                          ),
                        if (isSuggestionPanelOpen)
                          _SuggestionsSliver(
                            textEditingController: _textEditingController,
                            highlightedIndexNotifier:
                                _highlightedSuggestionIndexNotifier,
                            onSearchInAllCategories: _doSearchInAllCategories,
                            onSearchWithFilter: _doSearchWithFilter,
                            onSetSearchFieldText: (query) {
                              _setSearchFieldText(query);
                              _openSuggestionPanel();
                              _searchFocusNode.requestFocus();
                              context
                                  .read<SearchSuggestionBloc>()
                                  .add(SearchSuggestionFetch(query));
                            },
                            onSuggestionsGenerated: (suggestions) {
                              // We update this silently without triggering rebuilds for the KeyHandler
                              _currentCombinedSuggestions = suggestions;
                            },
                          )
                        else
                          _ContentSliver(
                            contentBloc: _contentBloc,
                            activePluginNotifier: _activePluginIdNotifier,
                            isMultiSelect: _isMultiSelect,
                            selectedTrackIds: _selectedTrackIds,
                            onTrackToggle: (track) {
                              setState(() {
                                if (_selectedTrackIds.contains(track.id)) {
                                  _selectedTrackIds.remove(track.id);
                                  if (_selectedTrackIds.isEmpty) {
                                    _isMultiSelect = false;
                                  }
                                } else {
                                  _selectedTrackIds.add(track.id);
                                }
                              });
                            },
                            onTrackLongPress: (track) {
                              setState(() {
                                _isMultiSelect = true;
                                _selectedTrackIds.add(track.id);
                              });
                            },
                            onTracksLoaded: (tracks) {
                              _lastTrackList = tracks;
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── OPTIMIZED MODULAR SLIVERS ──────────────────────────────────────────────────

class _FloatingSearchBarSliver extends StatelessWidget {
  final TextEditingController textEditingController;
  final FocusNode searchFocusNode;
  final ContentBloc contentBloc;
  final FocusOnKeyEventCallback handleKeyEvent;
  final List<({String query, ContentSearchFilter filter})>
      currentCombinedSuggestions;
  final ValueNotifier<int> highlightedIndexNotifier;
  final Function({required String query, required ContentSearchFilter filter})
      onSearchRequested;
  final VoidCallback onClearRequested;
  final ValueChanged<String> onQueryChanged;

  const _FloatingSearchBarSliver({
    required this.textEditingController,
    required this.searchFocusNode,
    required this.contentBloc,
    required this.handleKeyEvent,
    required this.currentCombinedSuggestions,
    required this.highlightedIndexNotifier,
    required this.onSearchRequested,
    required this.onClearRequested,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      toolbarHeight: 70,
      title: Focus(
        onKeyEvent: handleKeyEvent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  _buildAnimatedSearchLeadingIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: textEditingController,
                      focusNode: searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: onQueryChanged,
                      onSubmitted: (val) {
                        final hIndex = highlightedIndexNotifier.value;
                        if (hIndex >= 0 &&
                            hIndex < currentCombinedSuggestions.length) {
                          final selected = currentCombinedSuggestions[hIndex];
                          onSearchRequested(
                              query: selected.query, filter: selected.filter);
                        } else {
                          onSearchRequested(
                              query: val, filter: ContentSearchFilter.all);
                        }
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        hintText:
                            AppLocalizations.of(context)!.searchHintExplore,
                        hintStyle: TextStyle(
                          color: Default_Theme.primaryColor1
                              .withValues(alpha: 0.35),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: textEditingController,
                    builder: (context, value, child) {
                      if (value.text.isNotEmpty) {
                        return IconButton(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          icon: Icon(MingCute.close_fill,
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.5),
                              size: 18),
                          onPressed: onClearRequested,
                        );
                      }
                      return const SizedBox(width: 16);
                    },
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSearchLeadingIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final query = textEditingController.text.trim();
        if (query.isNotEmpty) {
          onSearchRequested(query: query, filter: ContentSearchFilter.all);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: BlocBuilder<ContentBloc, ContentState>(
          bloc: contentBloc,
          buildWhen: (previous, current) =>
              previous.searchStatus != current.searchStatus,
          builder: (context, state) {
            final isLoading = state.searchStatus == SearchStatus.loading ||
                state.searchStatus == SearchStatus.loadingMore;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final rotation = Tween<double>(begin: 0.82, end: 1).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOutBack));
                return FadeTransition(
                    opacity: animation,
                    child: RotationTransition(turns: rotation, child: child));
              },
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('search-loading'),
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color:
                              Default_Theme.primaryColor1.withValues(alpha: 0.5)),
                    )
                  : Icon(MingCute.search_2_line,
                      key: const ValueKey('search-idle'),
                      color:
                          Default_Theme.primaryColor1.withValues(alpha: 0.5),
                      size: 20),
            );
          },
        ),
      ),
    );
  }
}

class _AestheticFilterChipsSliver extends StatelessWidget {
  final ValueNotifier<ContentSearchFilter> filterNotifier;
  final TextEditingController textEditingController;
  final VoidCallback onFilterTapped;

  const _AestheticFilterChipsSliver(
      {required this.filterNotifier,
      required this.textEditingController,
      required this.onFilterTapped});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<ContentSearchFilter>(
        valueListenable: filterNotifier,
        builder: (context, filterValue, child) {
          return SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              physics: const BouncingScrollPhysics(),
              itemCount: ContentSearchFilter.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final e = ContentSearchFilter.values[index];
                final isSelected = filterValue == e;
                final displayName =
                    e.name[0].toUpperCase() + e.name.substring(1);

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    filterNotifier.value = e;
                    if (textEditingController.text.isNotEmpty) onFilterTapped();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Default_Theme.accentColor2
                          : Default_Theme.primaryColor2.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? Default_Theme.accentColor2
                              : Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Text(
                      displayName,
                      style: Default_Theme.secondoryTextStyleMedium.copyWith(
                        color: isSelected
                            ? Default_Theme.primaryColor2
                            : Default_Theme.primaryColor1
                                .withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PluginsGlassyBoxSliver extends StatelessWidget {
  final ValueNotifier<String?> activePluginNotifier;
  final ContentBloc contentBloc;
  final TextEditingController textEditingController;
  final VoidCallback onPluginChanged;

  const _PluginsGlassyBoxSliver({
    required this.activePluginNotifier,
    required this.contentBloc,
    required this.textEditingController,
    required this.onPluginChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: BlocBuilder<PluginBloc, PluginState>(
        buildWhen: (prev, curr) =>
            prev.loadedContentResolvers != curr.loadedContentResolvers,
        builder: (context, pluginState) {
          final resolvers = pluginState.loadedContentResolvers;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Default_Theme.primaryColor2.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(MingCute.plugin_2_line,
                                size: 18, color: Default_Theme.accentColor2),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.searchSources,
                              style: Default_Theme.secondoryTextStyleMedium
                                  .copyWith(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w800,
                                color: Default_Theme.primaryColor1
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (resolvers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            AppLocalizations.of(context)!.searchNoPlugins,
                            style: TextStyle(
                                color: Default_Theme.primaryColor1
                                    .withValues(alpha: 0.4),
                                fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: resolvers
                                .map((plugin) => Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: _PluginChip(
                                        plugin: plugin,
                                        activePluginNotifier:
                                            activePluginNotifier,
                                        onTap: () {
                                          final id = plugin.manifest.id;
                                          if (activePluginNotifier.value == id)
                                            return;
                                          activePluginNotifier.value = id;
                                          contentBloc.add(
                                              SetActiveContentPlugin(
                                                  pluginId: id));
                                          context
                                              .read<SettingsCubit>()
                                              .setSearchPluginId(id);
                                          if (textEditingController.text
                                              .isNotEmpty) onPluginChanged();
                                        },
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PluginChip extends StatelessWidget {
  final PluginInfo plugin;
  final ValueNotifier<String?> activePluginNotifier;
  final VoidCallback onTap;

  const _PluginChip(
      {required this.plugin,
      required this.activePluginNotifier,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: activePluginNotifier,
      builder: (context, activeId, child) {
        final isSelected = activeId == plugin.manifest.id;

        return InkWell(
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? Default_Theme.accentColor2.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSelected
                    ? Default_Theme.accentColor2
                    : Default_Theme.primaryColor1.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(MingCute.check_line,
                        size: 13, color: Default_Theme.accentColor2),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    formatUserFriendlyPluginName(plugin.name),
                    style: Default_Theme.secondoryTextStyleMedium.merge(
                      TextStyle(
                        color: isSelected
                            ? Default_Theme.accentColor2
                            : Default_Theme.primaryColor1
                                .withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionsSliver extends StatelessWidget {
  final TextEditingController textEditingController;
  final ValueNotifier<int> highlightedIndexNotifier;
  final void Function(String) onSearchInAllCategories;
  final void Function(String, ContentSearchFilter) onSearchWithFilter;
  final void Function(String) onSetSearchFieldText;
  final void Function(List<({String query, ContentSearchFilter filter})>)
      onSuggestionsGenerated;

  const _SuggestionsSliver({
    required this.textEditingController,
    required this.highlightedIndexNotifier,
    required this.onSearchInAllCategories,
    required this.onSearchWithFilter,
    required this.onSetSearchFieldText,
    required this.onSuggestionsGenerated,
  });

  String _normalize(String q) => q.trim().replaceAll(RegExp(r'\s+'), ' ');
  ContentSearchFilter _filterForEntity(plugin_models.EntityType type) =>
      switch (type) {
        plugin_models.EntityType.track => ContentSearchFilter.track,
        plugin_models.EntityType.album => ContentSearchFilter.album,
        plugin_models.EntityType.artist => ContentSearchFilter.artist,
        plugin_models.EntityType.playlist => ContentSearchFilter.playlist,
        _ => ContentSearchFilter.all,
      };

  String _buildEntitySearchQuery(plugin_models.EntitySuggestion entity) {
    final parts = <String>[entity.title.trim()];
    if (entity.subtitle != null && entity.subtitle!.isNotEmpty) {
      parts.add(entity.subtitle!
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), " ")
          .replaceAll(RegExp(r'[^\w\s]+', unicode: true), "")
          .replaceAll(entity.title.toLowerCase().trim(), ""));
    }
    return _normalize(parts.where((p) => p.isNotEmpty).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchSuggestionBloc, SearchSuggestionState>(
      builder: (context, state) {
        if (state is SearchSuggestionLoading) {
          return const SliverToBoxAdapter(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                    child: CircularProgressIndicator(
                        color: Default_Theme.accentColor2))),
          );
        }

        if (state is SearchSuggestionLoaded) {
          final dbList = state.dbSuggestionList
              .map((e) => e['query'] ?? '')
              .where((q) => q.isNotEmpty)
              .toList();
          final apiList = state.suggestionList;
          final entityList = state.entitySuggestionList;
          final isPluginLoading = state.isPluginLoading;

          final combined = <({String query, ContentSearchFilter filter})>[
            ...dbList.map(
                (q) => (query: _normalize(q), filter: ContentSearchFilter.all)),
            ...apiList.map(
                (q) => (query: _normalize(q), filter: ContentSearchFilter.all)),
            ...entityList.map((e) => (
                  query: _buildEntitySearchQuery(e),
                  filter: _filterForEntity(e.kind)
                )),
          ];

          WidgetsBinding.instance
              .addPostFrameCallback((_) => onSuggestionsGenerated(combined));

          if (combined.isEmpty && isPluginLoading) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Default_Theme.accentColor2,
                  ),
                ),
              ),
            );
          }
          if (combined.isEmpty && textEditingController.text.isEmpty) {
            return SliverFillRemaining(
                hasScrollBody: false,
                child: SignBoardWidget(
                    message: AppLocalizations.of(context)!.searchStartTyping,
                    icon: MingCute.keyboard_line));
          }
          if (combined.isEmpty) {
            return SliverFillRemaining(
                hasScrollBody: false,
                child: SignBoardWidget(
                    message: AppLocalizations.of(context)!.searchNoSuggestions,
                    icon: MingCute.ghost_line));
          }

          final children = <Widget>[
            const SizedBox(height: 12),
            if (dbList.isNotEmpty) ...[
              _buildSuggestionSectionHeader(
                context,
                'Recent',
                MingCute.history_line,
                onClearAll: () => _confirmClearAll(context),
              ),
              ...dbList.asMap().entries.map((e) => _SuggestionTile(
                    suggestion: e.value,
                    icon: MingCute.history_line,
                    isHistory: true,
                    globalIndex: e.key,
                    highlightedIndexNotifier: highlightedIndexNotifier,
                    onSearch: onSearchInAllCategories,
                    onPopulate: onSetSearchFieldText,
                  )),
              const SizedBox(height: 12),
            ],
            if (isPluginLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Default_Theme.accentColor2.withValues(alpha: 0.7),
                    backgroundColor:
                        Default_Theme.primaryColor1.withValues(alpha: 0.06),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (apiList.isNotEmpty) ...[
              _buildSuggestionSectionHeader(
                  context, 'Suggestions', MingCute.search_2_line),
              ...apiList.asMap().entries.map((e) => _SuggestionTile(
                    suggestion: e.value,
                    icon: MingCute.search_line,
                    isHistory: false,
                    globalIndex: e.key + dbList.length,
                    highlightedIndexNotifier: highlightedIndexNotifier,
                    onSearch: onSearchInAllCategories,
                    onPopulate: onSetSearchFieldText,
                  )),
              const SizedBox(height: 12),
            ],
            if (entityList.isNotEmpty) ...[
              _buildSuggestionSectionHeader(
                  context, 'Top Results', MingCute.sparkles_2_line),
              ...entityList.asMap().entries.map((e) => _EntitySuggestionTile(
                    entity: e.value,
                    globalIndex: e.key + dbList.length + apiList.length,
                    filter: _filterForEntity(e.value.kind),
                    query: _buildEntitySearchQuery(e.value),
                    highlightedIndexNotifier: highlightedIndexNotifier,
                    onSearch: onSearchWithFilter,
                  )),
            ],
            const SizedBox(height: 120),
          ];

          return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList(delegate: SliverChildListDelegate(children)));
        }
        return SliverFillRemaining(
            hasScrollBody: false,
            child: SignBoardWidget(
                message: AppLocalizations.of(context)!.searchNoSuggestions,
                icon: MingCute.ghost_line));
      },
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Default_Theme.themeColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.1),
          ),
        ),
        title: const Text(
          'Clear Search History?',
          style: TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete all recent search history?',
          style: TextStyle(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Default_Theme.accentColor1,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<SearchSuggestionBloc>()
                  .add(const SearchSuggestionClearAll());
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    VoidCallback? onClearAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          Icon(icon,
              size: 14,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: Default_Theme.secondoryTextStyleMedium.copyWith(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700)),
          ),
          if (onClearAll != null)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onClearAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Clear all',
                  style: Default_Theme.secondoryTextStyleMedium.copyWith(
                    color: Default_Theme.accentColor2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String suggestion;
  final IconData icon;
  final bool isHistory;
  final int globalIndex;
  final ValueNotifier<int> highlightedIndexNotifier;
  final void Function(String) onSearch;
  final void Function(String) onPopulate;

  const _SuggestionTile(
      {required this.suggestion,
      required this.icon,
      required this.isHistory,
      required this.globalIndex,
      required this.highlightedIndexNotifier,
      required this.onSearch,
      required this.onPopulate});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSearch(suggestion),
        splashColor: Colors.transparent,
        highlightColor: Default_Theme.primaryColor1.withValues(alpha: 0.05),
        child: ValueListenableBuilder<int>(
          valueListenable: highlightedIndexNotifier,
          builder: (context, highlightedIndex, child) {
            final isHighlighted = highlightedIndex == globalIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Default_Theme.primaryColor1.withValues(alpha: 0.065)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.48)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(suggestion,
                      style: TextStyle(
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.9),
                              fontSize: 15)
                          .merge(Default_Theme.secondoryTextStyle))),
              if (isHistory)
                GestureDetector(
                    onTap: () => context
                        .read<SearchSuggestionBloc>()
                        .add(SearchSuggestionClear(suggestion)),
                    child: Icon(MingCute.close_fill,
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.4),
                        size: 18))
              else
                GestureDetector(
                    onTap: () => onPopulate(
                        suggestion.trim().replaceAll(RegExp(r'\s+'), ' ')),
                    child: Icon(MingCute.arrow_left_up_line,
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.4),
                        size: 18))
            ],
          ),
        ),
      ),
    );
  }
}

class _EntitySuggestionTile extends StatelessWidget {
  final plugin_models.EntitySuggestion entity;
  final int globalIndex;
  final ContentSearchFilter filter;
  final String query;
  final ValueNotifier<int> highlightedIndexNotifier;
  final void Function(String, ContentSearchFilter) onSearch;

  const _EntitySuggestionTile(
      {required this.entity,
      required this.globalIndex,
      required this.filter,
      required this.query,
      required this.highlightedIndexNotifier,
      required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = entity.thumbnail?.urlLow ?? entity.thumbnail?.url;
    final isArtist = entity.kind == plugin_models.EntityType.artist;
    final typeLabel = switch (entity.kind) {
      plugin_models.EntityType.track =>
        AppLocalizations.of(context)!.searchTracks,
      plugin_models.EntityType.album =>
        AppLocalizations.of(context)!.searchAlbums,
      plugin_models.EntityType.artist =>
        AppLocalizations.of(context)!.searchArtists,
      plugin_models.EntityType.playlist =>
        AppLocalizations.of(context)!.searchPlaylists,
      plugin_models.EntityType.genre => 'Genre',
      plugin_models.EntityType.unknown => 'Result',
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSearch(query, filter),
        splashColor: Colors.transparent,
        highlightColor: Default_Theme.primaryColor1.withValues(alpha: 0.05),
        child: ValueListenableBuilder<int>(
          valueListenable: highlightedIndexNotifier,
          builder: (context, highlightedIndex, child) {
            final isHighlighted = highlightedIndex == globalIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Default_Theme.primaryColor1.withValues(alpha: 0.07)
                    : Default_Theme.primaryColor2.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isHighlighted
                        ? Default_Theme.primaryColor1.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04)),
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              isArtist
                  ? ClipOval(child: _buildThumb(thumbnailUrl))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildThumb(thumbnailUrl)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(entity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                                color: Default_Theme.primaryColor1
                                    .withValues(alpha: 0.9),
                                fontSize: 14.5)
                            .merge(Default_Theme.secondoryTextStyleMedium)),
                    if (entity.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(entity.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                                  color: Default_Theme.primaryColor1
                                      .withValues(alpha: 0.5),
                                  fontSize: 12)
                              .merge(Default_Theme.secondoryTextStyle)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Default_Theme.primaryColor1
                            .withValues(alpha: 0.08))),
                child: Text(typeLabel,
                    style: Default_Theme.secondoryTextStyleMedium.copyWith(
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.52),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(String? url) {
    if (url != null) {
      return CachedNetworkImage(
          imageUrl: url,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
      width: 42,
      height: 42,
      color: Default_Theme.primaryColor2.withValues(alpha: 0.15),
      child: Icon(MingCute.search_line,
          size: 18, color: Default_Theme.primaryColor1.withValues(alpha: 0.4)));
}

class _ContentSliver extends StatelessWidget {
  final ContentBloc contentBloc;
  final ValueNotifier<String?> activePluginNotifier;
  final bool isMultiSelect;
  final Set<String> selectedTrackIds;
  final void Function(Track) onTrackToggle;
  final void Function(Track) onTrackLongPress;
  final void Function(List<Track>) onTracksLoaded;

  const _ContentSliver({
    required this.contentBloc,
    required this.activePluginNotifier,
    required this.isMultiSelect,
    required this.selectedTrackIds,
    required this.onTrackToggle,
    required this.onTrackLongPress,
    required this.onTracksLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connState) {
        return BlocBuilder<ContentBloc, ContentState>(
          bloc: contentBloc,
          builder: (context, state) {
            final hasResults = state.searchResults != null &&
                state.searchResults!.items.isNotEmpty;

            if (connState == ConnectivityState.disconnected &&
                !hasResults &&
                state.searchStatus != SearchStatus.loading &&
                state.searchStatus != SearchStatus.loadingMore) {
              return SliverFillRemaining(
                  hasScrollBody: false,
                  child: SignBoardWidget(
                      icon: MingCute.wifi_off_line,
                      message: AppLocalizations.of(context)!.emptyNoInternet));
            }

            if (state.searchStatus == SearchStatus.loading && !hasResults) {
              return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Default_Theme.accentColor2)));
            }
            if ((state.searchStatus == SearchStatus.loading ||
                    state.searchStatus == SearchStatus.loaded ||
                    state.searchStatus == SearchStatus.loadingMore) &&
                hasResults) {
              return _SliverSearchResults(
                state: state,
                activePluginNotifier: activePluginNotifier,
                isMultiSelect: isMultiSelect,
                selectedTrackIds: selectedTrackIds,
                onTrackToggle: onTrackToggle,
                onTrackLongPress: onTrackLongPress,
                onTracksLoaded: onTracksLoaded,
              );
            }
            if (state.searchStatus == SearchStatus.loaded &&
                state.searchResults != null &&
                state.searchResults!.items.isEmpty) {
              return SliverFillRemaining(
                  hasScrollBody: false,
                  child: SignBoardWidget(
                      message: AppLocalizations.of(context)!.searchNoResults,
                      icon: MingCute.ghost_line));
            }
            if (state.searchStatus == SearchStatus.error) {
              return SliverFillRemaining(
                  hasScrollBody: false,
                  child: SignBoardWidget(
                      message: state.error ??
                          AppLocalizations.of(context)!.searchFailed,
                      icon: MingCute.sweats_line));
            }
            return SliverFillRemaining(
                hasScrollBody: false,
                child: SignBoardWidget(
                    message: AppLocalizations.of(context)!.searchDiscover,
                    icon: MingCute.planet_line));
          },
        );
      },
    );
  }
}

class _SliverSearchResults extends StatelessWidget {
  final ContentState state;
  final ValueNotifier<String?> activePluginNotifier;
  final bool isMultiSelect;
  final Set<String> selectedTrackIds;
  final void Function(Track) onTrackToggle;
  final void Function(Track) onTrackLongPress;
  final void Function(List<Track>) onTracksLoaded;

  const _SliverSearchResults({
    required this.state,
    required this.activePluginNotifier,
    required this.isMultiSelect,
    required this.selectedTrackIds,
    required this.onTrackToggle,
    required this.onTrackLongPress,
    required this.onTracksLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final items = state.searchResults!.items;
    final tracks = <Track>[];
    final albums = <AlbumSummary>[];
    final artists = <ArtistSummary>[];
    final playlists = <PlaylistSummary>[];

    for (final item in items) {
      switch (item) {
        case MediaItem_Track(:final field0):
          tracks.add(field0);
        case MediaItem_Album(:final field0):
          albums.add(field0);
        case MediaItem_Artist(:final field0):
          artists.add(field0);
        case MediaItem_Playlist(:final field0):
          playlists.add(field0);
      }
    }

    final pluginId = activePluginNotifier.value ?? '';
    final isLoadingMore = state.searchStatus == SearchStatus.loadingMore;
    final isRefreshing = state.searchStatus == SearchStatus.loading;

    return SliverMainAxisGroup(
      slivers: [
        if (isRefreshing)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: Default_Theme.primaryColor2.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05))),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Default_Theme.accentColor2)),
                    const SizedBox(width: 10),
                    Text('Searching...',
                        style: Default_Theme.secondoryTextStyleMedium.copyWith(
                            color: Default_Theme.primaryColor1
                                .withValues(alpha: 0.78),
                            fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          ),
        if (tracks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Builder(builder: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onTracksLoaded(tracks);
              });
              return const SizedBox.shrink();
            }),
          ),
          _sliverSectionHeader(
              '${AppLocalizations.of(context)!.searchTracks} (${tracks.length})'),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  final isSelected = selectedTrackIds.contains(track.id);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: SongCardWidget(
                      song: track,
                      showOptions: !isMultiSelect,
                      isSelectMode: isMultiSelect,
                      isSelected: isSelected,
                      onSelectChanged: (val) {
                        onTrackToggle(track);
                      },
                      onLongPress: () {
                        onTrackLongPress(track);
                      },
                      onTap: () {
                        if (isMultiSelect) {
                          onTrackToggle(track);
                          return;
                        }
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .updateQueueTracks(
                          [track],
                          doPlay: true,
                          queueTitle: 'Search',
                        );
                      },
                      onOptionsTap: () => showMoreBottomSheet(context, track,
                          showSinglePlay: true),
                    ),
                  );
                },
                childCount: tracks.length,
              ),
            ),
          ),
        ],
        if (albums.isNotEmpty) ...[
          _sliverSectionHeader(
              '${AppLocalizations.of(context)!.searchAlbums} (${albums.length})'),
          _buildResponsiveGrid(albums
              .map((a) => AlbumCard(album: a, pluginId: pluginId))
              .toList()),
        ],
        if (artists.isNotEmpty) ...[
          _sliverSectionHeader(
              '${AppLocalizations.of(context)!.searchArtists} (${artists.length})'),
          _buildResponsiveGrid(artists
              .map((a) => ArtistCard(artist: a, pluginId: pluginId))
              .toList()),
        ],
        if (playlists.isNotEmpty) ...[
          _sliverSectionHeader(
              '${AppLocalizations.of(context)!.searchPlaylists} (${playlists.length})'),
          _buildResponsiveGrid(playlists
              .map((p) => PlaylistCard(playlist: p, pluginId: pluginId))
              .toList()),
        ],
        if (isLoadingMore)
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Default_Theme.accentColor2))))
        else
          const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
      ],
    );
  }

  Widget _sliverSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 20, bottom: 12),
        child: Text(
          title,
          style: Default_Theme.secondoryTextStyleMedium.merge(TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.9))),
        ),
      ),
    );
  }

  Widget _buildResponsiveGrid(List<Widget> children) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: Wrap(
            spacing: 20,
            runSpacing: 28,
            alignment: WrapAlignment.start,
            children: children),
      ),
    );
  }
}

class _NebulaBackground extends StatelessWidget {
  final ContentBloc contentBloc;
  const _NebulaBackground({required this.contentBloc});

  List<Color> _getReactiveGradientColors(ContentState state) {
    if (state.searchStatus != SearchStatus.loaded &&
        state.searchStatus != SearchStatus.loadingMore)
      return [Colors.transparent, Colors.transparent];
    final items = state.searchResults?.items;
    if (items == null || items.isEmpty)
      return [Colors.transparent, Colors.transparent];

    String seedString = "";
    final firstItem = items.first;
    switch (firstItem) {
      case MediaItem_Track(:final field0):
        seedString = field0.thumbnail.urlLow ?? field0.thumbnail.url;
      case MediaItem_Album(:final field0):
        seedString =
            field0.thumbnail?.urlLow ?? field0.thumbnail?.url ?? field0.title;
      case MediaItem_Artist(:final field0):
        seedString =
            field0.thumbnail?.urlLow ?? field0.thumbnail?.url ?? field0.name;
      case MediaItem_Playlist(:final field0):
        seedString = field0.thumbnail.urlLow ?? field0.thumbnail.url;
    }

    final int hash = seedString.hashCode;
    double hue = (hash % 360).abs().toDouble();
    if (hue > 60 && hue < 170) hue = (hash % 2 == 0) ? 180 : 40;

    final color1 = HSLColor.fromAHSL(1.0, hue, 0.65, 0.35).toColor();
    final color2 =
        HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.65, 0.30).toColor();
    return [color1, color2];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentBloc, ContentState>(
      bloc: contentBloc,
      builder: (context, state) {
        final colors = _getReactiveGradientColors(state);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.75,
          child: CustomPaint(
              painter: NebulaPainter(
                  color1: colors[0].withValues(alpha: 0.18),
                  color2: colors[1].withValues(alpha: 0.18))),
        );
      },
    );
  }
}

class NebulaPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  NebulaPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
              center: const Alignment(-0.5, -0.6),
              radius: 1.6,
              colors: [color1, Colors.transparent],
              stops: const [0.0, 1.0])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final paint2 = Paint()
      ..shader = RadialGradient(
              center: const Alignment(0.5, -0.6),
              radius: 1.6,
              colors: [color2, Colors.transparent],
              stops: const [0.0, 1.0])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(covariant NebulaPainter oldDelegate) =>
      oldDelegate.color1 != color1 || oldDelegate.color2 != color2;
}
