import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final bool isGuest;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.isGuest = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
        'isGuest': isGuest,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? 'guest_user',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Guest Listener',
        photoUrl: json['photoUrl'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isGuest: json['isGuest'] as bool? ?? true,
      );

  static UserProfile guest() => UserProfile(
        id: 'guest_user',
        email: '',
        displayName: 'Guest Listener',
        createdAt: DateTime.now(),
        isGuest: true,
      );
}

/// Keeps Orvia usable in guest mode until a real account backend is configured.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  static const String _kAccountSessionKey = 'user_account_session';
  static const String _kCloudBackupKey = 'user_cloud_backup_payload';

  final ValueNotifier<UserProfile> currentUser =
      ValueNotifier<UserProfile>(UserProfile.guest());

  bool get isGuest => currentUser.value.isGuest;
  bool get isSignedIn => !currentUser.value.isGuest;

  Future<void> initialize() async {
    try {
      if (DBProvider.isInitialized) {
        final settingsDao = SettingsDAO(DBProvider.db);
        await settingsDao.putSettingStr(_kAccountSessionKey, '');
      }
    } catch (e) {
      log('Could not clear unsupported local account session: $e',
          name: 'AccountService');
    }
    currentUser.value = UserProfile.guest();
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw ArgumentError(
          'Please enter a valid email and 6+ character password.');
    }
    throw UnsupportedError(
        'Email sign-in is unavailable until an authentication backend is configured.');
  }

  Future<void> signUpWithEmail(
      String email, String password, String displayName) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw ArgumentError(
          'Please enter a valid email and 6+ character password.');
    }
    throw UnsupportedError(
        'Account registration is unavailable until an authentication backend is configured.');
  }

  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty) {
      throw ArgumentError('Please enter a valid email address.');
    }
    throw UnsupportedError(
        'Password reset is unavailable until an authentication backend is configured.');
  }

  Future<void> signInWithGoogle() async {
    throw UnsupportedError(
        'Google sign-in is unavailable until an authentication backend is configured.');
  }

  Future<void> signOut() async {
    if (DBProvider.isInitialized) {
      final settingsDao = SettingsDAO(DBProvider.db);
      await settingsDao.putSettingStr(_kAccountSessionKey, '');
    }
    currentUser.value = UserProfile.guest();
  }

  Future<void> deleteAccount() async {
    if (DBProvider.isInitialized) {
      final settingsDao = SettingsDAO(DBProvider.db);
      await settingsDao.putSettingStr(_kAccountSessionKey, '');
      await settingsDao.putSettingStr(_kCloudBackupKey, '');
    }
    currentUser.value = UserProfile.guest();
  }

  /// Cloud backup is unavailable until authenticated remote storage is configured.
  Future<int> backupToCloud() async {
    throw UnsupportedError(
        'Cloud backup is unavailable until authenticated remote storage is configured.');
  }

  /// Cloud restore is unavailable until authenticated remote storage is configured.
  Future<int> restoreFromCloud({bool merge = true}) async {
    throw UnsupportedError(
        'Cloud restore is unavailable until authenticated remote storage is configured.');
  }
}
