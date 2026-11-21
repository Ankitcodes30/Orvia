import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/check_update_view.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';

class UpdatesSettings extends StatefulWidget {
  const UpdatesSettings({super.key});

  @override
  State<UpdatesSettings> createState() => _UpdatesSettingsState();
}

class _UpdatesSettingsState extends State<UpdatesSettings> {
  String _manifestUrl = '';
  String _channel = 'stable';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!DBProvider.isInitialized) return;
    final dao = SettingsDAO(DBProvider.db);
    final url = await dao.getSettingStr(SettingKeys.updateManifestUrl) ?? '';
    final channel = await dao.getSettingStr(SettingKeys.updateChannel) ?? 'stable';
    if (mounted) {
      setState(() {
        _manifestUrl = url;
        _channel = channel;
      });
    }
  }

  Future<void> _setManifestUrl(String url) async {
    if (!DBProvider.isInitialized) return;
    final dao = SettingsDAO(DBProvider.db);
    await dao.putSettingStr(SettingKeys.updateManifestUrl, url.trim());
    setState(() {
      _manifestUrl = url.trim();
    });
  }

  Future<void> _setChannel(String channel) async {
    if (!DBProvider.isInitialized) return;
    final dao = SettingsDAO(DBProvider.db);
    await dao.putSettingStr(SettingKeys.updateChannel, channel);
    setState(() {
      _channel = channel;
    });
  }

  void _showManifestDialog() {
    final controller = TextEditingController(text: _manifestUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Default_Theme.themeColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Release Manifest URL',
          style: TextStyle(
            color: Default_Theme.primaryColor1,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the official HTTPS endpoint hosting the Orvia release manifest (release_manifest.json).',
              style: TextStyle(
                color: Default_Theme.primaryColor2.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Default_Theme.primaryColor1),
              decoration: InputDecoration(
                hintText: 'https://example.com/release_manifest.json',
                hintStyle: TextStyle(
                  color: Default_Theme.primaryColor2.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                final uri = Uri.tryParse(text);
                final isLocal = uri != null &&
                    (uri.host == 'localhost' || uri.host == '127.0.0.1');
                if (uri == null ||
                    (!uri.isScheme('https') &&
                        !(uri.isScheme('http') && isLocal))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Endpoint must use secure HTTPS (https://...) to prevent tampering.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
              }
              Navigator.pop(ctx);
              _setManifestUrl(text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChannelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Default_Theme.themeColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Update Channel',
          style: TextStyle(
            color: Default_Theme.primaryColor1,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _setChannel('stable');
            },
            child: Row(
              children: [
                Icon(
                  _channel == 'stable'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Default_Theme.accentColor2,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Stable (Recommended)',
                  style: TextStyle(color: Default_Theme.primaryColor1),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _setChannel('preview');
            },
            child: Row(
              children: [
                Icon(
                  _channel == 'preview'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Default_Theme.accentColor2,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Preview / Pre-release',
                  style: TextStyle(color: Default_Theme.primaryColor1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Default_Theme.primaryColor1,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          l10n.updateSettingTitle,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ).merge(Default_Theme.secondoryTextStyleMedium),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (prev, curr) =>
            prev.autoUpdateNotify != curr.autoUpdateNotify,
        builder: (context, state) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              SettingSectionHeader(label: l10n.updateSettingTitle),
              SettingCard(
                children: [
                  SettingNavTile(
                    icon: MingCute.download_3_fill,
                    title: l10n.updateCheckForUpdates,
                    subtitle: l10n.updateCheckSubtitle,
                    roundBottom: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CheckUpdateView(),
                        ),
                      );
                    },
                  ),
                  const SettingDivider(),
                  SettingToggleTile(
                    icon: MingCute.notification_fill,
                    title: l10n.updateAutoNotify,
                    subtitle: l10n.updateAutoNotifySubtitle,
                    value: state.autoUpdateNotify,
                    onChanged: (value) {
                      context.read<SettingsCubit>().setAutoUpdateNotify(value);
                    },
                  ),
                  const SettingDivider(),
                  SettingNavTile(
                    icon: MingCute.git_branch_line,
                    title: 'Update Channel',
                    subtitle: _channel == 'preview'
                        ? 'Preview (Pre-release)'
                        : 'Stable',
                    roundBottom: false,
                    onTap: _showChannelDialog,
                  ),
                  const SettingDivider(),
                  SettingNavTile(
                    icon: MingCute.link_line,
                    title: 'Release Manifest Endpoint',
                    subtitle: _manifestUrl.isEmpty
                        ? 'Not configured (tap to specify official endpoint)'
                        : _manifestUrl,
                    roundBottom: true,
                    onTap: _showManifestDialog,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
