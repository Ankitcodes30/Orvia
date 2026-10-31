import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';

class PushNotificationService with WidgetsBindingObserver {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final StreamController<UpdateCheckResult> _updateAlertController =
      StreamController<UpdateCheckResult>.broadcast();
  Stream<UpdateCheckResult> get updateAlertStream =>
      _updateAlertController.stream;

  DateTime? _lastCheckTime;
  String? _dismissedVersion;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    // Initial update check with delay so app startup is smooth
    Future.delayed(const Duration(seconds: 4), () {
      checkForUpdatesQuietly();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkForUpdatesQuietly();
    }
  }

  /// Request push notification permissions on supported platforms
  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      log('Error requesting notification permission: $e',
          name: 'PushNotificationService');
      return false;
    }
  }

  /// Checks for updates quietly, respecting debounce time and dismissed versions.
  Future<void> checkForUpdatesQuietly({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastCheckTime != null &&
        now.difference(_lastCheckTime!) < const Duration(hours: 6)) {
      return;
    }

    _lastCheckTime = now;
    try {
      final result = await OrviaUpdateService.instance.checkForUpdates();
      if (result.isUpdateAvailable) {
        // If user already dismissed this specific version and it's not below min supported, skip
        if (!result.isBelowMinSupportedVersion &&
            _dismissedVersion == result.newVersion &&
            !force) {
          return;
        }
        _updateAlertController.add(result);
      }
    } catch (e) {
      log('Quiet update check error: $e', name: 'PushNotificationService');
    }
  }

  void dismissUpdate(String? version) {
    _dismissedVersion = version;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateAlertController.close();
  }
}
