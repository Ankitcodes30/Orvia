// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Orvia/screens/screen/home_views/setting_views/about.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/appui_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/local_music_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/plugin_defaults_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/storage_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/country_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/download_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/lastfm_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/player_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/updates_setting.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/account_sync_setting.dart';
import 'package:Orvia/screens/screen/home_views/listen_together_screen.dart';
import 'package:Orvia/screens/screen/home_views/timer_view.dart';
import 'package:Orvia/screens/screen/home_views/statistics_screen.dart';
import 'package:Orvia/screens/screen/plugin_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Default_Theme.primaryColor1),
        title: Text(
          AppLocalizations.of(context)!.settingsTitle,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: 640), // Desktop & tablet responsive
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // ── Group 1: Appearance (Metrolist Style) ──
              const _SectionHeader(title: 'APPEARANCE'),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsUIElements,
                    subtitle: AppLocalizations.of(context)!
                        .settingsUIElementsSubtitle,
                    icon: MingCute.display_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const AppUISettings()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Group 2: Player & Audio ──
              const _SectionHeader(title: 'PLAYER & AUDIO'),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsPlayer,
                    subtitle:
                        AppLocalizations.of(context)!.settingsPlayerSubtitle,
                    icon: MingCute.airpods_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const PlayerSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.timerTitle,
                    subtitle: 'Stop music automatically after a set duration',
                    icon: MingCute.stopwatch_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const TimerView()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Group 3: Content & Region ──
              const _SectionHeader(title: 'CONTENT & REGION'),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title:
                        AppLocalizations.of(context)!.settingsLanguageCountry,
                    subtitle: AppLocalizations.of(context)!
                        .settingsLanguageCountrySubtitle,
                    icon: MingCute.globe_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const CountrySettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsPluginDefaults,
                    subtitle: AppLocalizations.of(context)!
                        .settingsPluginDefaultsSubtitle,
                    icon: MingCute.settings_6_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () =>
                        _navigate(context, const PluginDefaultsSettings()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Group 4: Storage & Downloads ──
              const _SectionHeader(title: 'STORAGE & DOWNLOADS'),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsDownloads,
                    subtitle:
                        AppLocalizations.of(context)!.settingsDownloadsSubtitle,
                    icon: MingCute.folder_download_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const DownloadSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsStorage,
                    subtitle:
                        AppLocalizations.of(context)!.settingsStorageSubtitle,
                    icon: MingCute.coin_2_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const BackupSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsLocalTracks,
                    subtitle: AppLocalizations.of(context)!
                        .settingsLocalTracksSubtitle,
                    icon: MingCute.music_2_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const LocalMusicSettings()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Group 5: Services & Social ──
              const _SectionHeader(title: 'SERVICES & SOCIAL'),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: 'Account & Cloud Sync',
                    subtitle: 'Guest mode, cloud backup & library restore',
                    icon: MingCute.user_star_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const AccountSyncSettings()),
                  ),
                  _SettingsTile(
                    title: 'Listen Together',
                    subtitle: 'Host or join synchronized listening rooms',
                    icon: MingCute.group_line,
                    iconColor: Default_Theme.accentColor2,
                    isHighlightIcon: true,
                    onTap: () => _navigate(context, const ListenTogetherScreen()),
                  ),
                  _SettingsTile(
                    title: 'Listening Statistics',
                    subtitle: 'View your total listening time, top tracks and artists',
                    icon: MingCute.chart_bar_line,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const StatisticsScreen()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsPlugins,
                    subtitle:
                        AppLocalizations.of(context)!.settingsPluginsSubtitle,
                    icon: MingCute.plugin_2_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () =>
                        _navigate(context, const PluginManagerScreen()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsLastFM,
                    subtitle:
                        AppLocalizations.of(context)!.settingsLastFMSubtitle,
                    icon: FontAwesome.lastfm_brand,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const LastDotFM()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Group 6: About & Updates ──
              const _SectionHeader(title: 'ABOUT & UPDATES'),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsUpdates,
                    subtitle:
                        AppLocalizations.of(context)!.settingsUpdatesSubtitle,
                    icon: MingCute.download_3_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const UpdatesSettings()),
                  ),
                  _SettingsTile(
                    title: AppLocalizations.of(context)!.settingsAbout,
                    subtitle:
                        AppLocalizations.of(context)!.settingsAboutSubtitle,
                    icon: MingCute.github_fill,
                    iconColor: Default_Theme.accentColor2,
                    onTap: () => _navigate(context, const About()),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}

// ── Custom Section Header ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Default_Theme.accentColor2,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Custom Widgets for Modern Settings UI ───────────────────────────────────

/// Wraps a list of settings tiles in a beautifully rounded, borderless card.
class _SettingsSection extends StatelessWidget {
  final List<Widget> children;
  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: children.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 56, // Indents past the icon for a clean iOS/Material 3 feel
            color: Default_Theme.primaryColor1.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) => children[index],
        ),
      ),
    );
  }
}

/// An individual modern Settings Tile.
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isHighlightIcon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isHighlightIcon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Default_Theme.accentColor2.withValues(alpha: 0.12),
        highlightColor: Default_Theme.accentColor2.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isHighlightIcon
                      ? iconColor.withValues(alpha: 0.15)
                      : Default_Theme.primaryColor1.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isHighlightIcon ? iconColor : Default_Theme.primaryColor1,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Default_Theme.primaryColor1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                MingCute.right_line,
                size: 16,
                color: Default_Theme.primaryColor1.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
