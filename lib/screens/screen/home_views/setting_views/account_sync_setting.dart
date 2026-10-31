import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/services/account/account_service.dart';

class AccountSyncSettings extends StatefulWidget {
  const AccountSyncSettings({super.key});

  @override
  State<AccountSyncSettings> createState() => _AccountSyncSettingsState();
}

class _AccountSyncSettingsState extends State<AccountSyncSettings> {
  final _accountService = AccountService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Account & Sync',
          style: TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Default_Theme.primaryColor1),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ValueListenableBuilder<UserProfile>(
            valueListenable: _accountService.currentUser,
            builder: (context, user, _) {
              return ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. User Status Card
                  _buildProfileCard(user),
                  const SizedBox(height: 20),

                  // 2. Cloud Backup & Restore
                  _buildCloudSyncSection(),
                  const SizedBox(height: 20),

                  // 3. Security & Privacy Notice
                  _buildPrivacyNotice(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor2.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Default_Theme.accentColor2.withValues(alpha: 0.2),
                child: Icon(
                  user.isGuest ? MingCute.user_2_line : MingCute.user_star_fill,
                  color: Default_Theme.accentColor2,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.isGuest
                          ? 'Guest Mode (No login required)'
                          : user.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (user.isGuest) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(MingCute.user_follow_line, size: 18),
                    label: const Text('Sign-in unavailable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Default_Theme.accentColor2,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(MingCute.close_circle_line, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _handleDeleteAccount,
                  icon: const Icon(MingCute.delete_2_fill,
                      size: 18, color: Colors.redAccent),
                  label: const Text('Clear Local Profile',
                      style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSyncSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor2.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cloud sync is not configured',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Guest mode keeps the app fully usable. Email/Google sign-in and cross-device backup require an authenticated backend, which is not connected.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            MingCute.save_2_line,
            color: Default_Theme.accentColor2.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your local library stays on this device. No cloud account, remote backup, or push-notification backend is currently connected.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await _accountService.signOut();
    SnackbarService.showMessage('Returned to Guest Mode.');
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Default_Theme.themeColor,
        title: const Text('Clear Local Profile?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This clears the locally stored account session and backup placeholder. Your playlists and local songs are not deleted. No cloud account exists.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Local Profile'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _accountService.deleteAccount();
      SnackbarService.showMessage('Local account session cleared.');
    }
  }
}
