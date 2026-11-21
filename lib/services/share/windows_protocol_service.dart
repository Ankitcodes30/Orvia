import 'dart:developer';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:win32_registry/win32_registry.dart';
import 'orvia_deep_link_service.dart';

/// Service responsible for Windows deep-link protocol registration (`orvia://`)
/// and inter-process activation messaging via MethodChannel.
class WindowsProtocolService {
  static const MethodChannel _channel =
      MethodChannel('ls.orvia.musicplayer/deep_link');

  static bool _initialized = false;

  /// Hook for testing registration logic without actual Win32 registry access.
  static bool Function(String exePath)? registryWriterOverride;

  /// Initializes the deep link listener and ensures protocol registration.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final rawUri = call.arguments as String?;
        if (rawUri != null && rawUri.isNotEmpty) {
          log('Received Windows deep link message: $rawUri',
              name: 'WindowsProtocolService');
          final uri = Uri.tryParse(rawUri);
          if (uri != null && OrviaDeepLinkService.isDeepLink(uri)) {
            await OrviaDeepLinkService.handleDeepLinkUri(uri);
          }
        }
      }
    });

    if (io.Platform.isWindows) {
      try {
        registerUrlProtocol();
      } catch (e, stack) {
        log('Failed to register Windows URL protocol: $e',
            error: e, stackTrace: stack, name: 'WindowsProtocolService');
      }
    }
  }

  /// Registers the `orvia://` URL protocol in `HKEY_CURRENT_USER\Software\Classes\orvia`.
  ///
  /// This allows browsers (Chrome, Edge, Firefox) to launch or activate Orvia
  /// when the user clicks "Open in Orvia App".
  ///
  /// Writing to HKCU requires NO administrative privileges and functions
  /// cleanly from both installed and portable directories.
  static bool registerUrlProtocol([String? customExePath]) {
    final exePath = customExePath ?? io.Platform.resolvedExecutable;
    if (registryWriterOverride != null) {
      return registryWriterOverride!(exePath);
    }

    if (!io.Platform.isWindows) return false;

    try {
      final classesKey = Registry.openPath(
        RegistryHive.currentUser,
        path: r'Software\Classes',
        desiredAccessRights: AccessRights.allAccess,
      );

      final orviaKey = classesKey.createKey('orvia');
      orviaKey.createValue(
        const RegistryValue.string('', 'URL:Orvia Protocol'),
      );
      orviaKey.createValue(
        const RegistryValue.string('URL Protocol', ''),
      );

      final commandKey = orviaKey.createKey(r'shell\open\command');
      commandKey.createValue(
        RegistryValue.string('', '"$exePath" "%1"'),
      );

      commandKey.close();
      orviaKey.close();
      classesKey.close();

      log('Successfully registered orvia:// protocol for "$exePath"',
          name: 'WindowsProtocolService');
      return true;
    } catch (e, stack) {
      log('Could not register Windows orvia protocol: $e',
          error: e, stackTrace: stack, name: 'WindowsProtocolService');
      return false;
    }
  }
}
