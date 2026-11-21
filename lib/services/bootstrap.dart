import 'dart:async';
import 'dart:developer';

import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/local_music_service.dart';
import 'package:Orvia/services/plugin_bootstrap_service.dart';
import 'package:Orvia/services/onboarding_service.dart';
import 'package:Orvia/src/rust/frb_generated.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:path_provider/path_provider.dart';

/// Application bootstrap — run once before [runApp].
///
/// Responsibilities:
/// - Initialize platform path constants.
/// - Open the Isar database via [DBProvider].
/// - Schedule periodic DB maintenance tasks.
/// - Wire the [ServiceLocator] and initialize the plugin system.
Future<void> bootstrapApp() async {
  // Initialize flutter_rust_bridge before any Rust API call.
  await RustLib.init();

  final String appDocPath = (await getApplicationDocumentsDirectory()).path;
  final String appSuppPath = (await getApplicationSupportDirectory()).path;

  // Open DB and schedule maintenance with error boundary.
  try {
    await DBProvider.init(
        appSupportPath: appSuppPath, appDocumentsPath: appDocPath);
    DBProvider.scheduleMaintenance();

    // DI wiring (registers singletons).
    await ServiceLocator.setup();
  } catch (e, stack) {
    log('Database initialization failed during bootstrap: $e',
        error: e, stackTrace: stack, name: 'Bootstrap');
    // Early exit: DB-dependent services must not be initialized before the DB is healthy.
    return;
  }

  // Ensure default plugin repository URLs are seeded in settings (idempotent, local, non-blocking).
  // Background network update is dispatched asynchronously without blocking startup/first frame.
  try {
    await PluginBootstrapService.ensureHostedRepositoriesPresent(
      repositoryService: ServiceLocator.pluginRepositoryService,
      skipNetwork: true,
    );
    // Non-blocking background sync post-first-frame
    unawaited(Future.delayed(const Duration(seconds: 3), () {
      PluginBootstrapService.ensureHostedRepositoriesPresent(
        repositoryService: ServiceLocator.pluginRepositoryService,
        skipNetwork: false,
      );
    }));
  } catch (e) {
    log('Hosted repository reconciliation skipped',
        error: e, name: 'Bootstrap');
  }

  // Initialize plugin system:
  //   Creates Rust PluginManager → connects event bus →
  //   preloads storage from Isar → starts storage event handler.
  try {
    await ServiceLocator.initializePluginSystem();
    log('Plugin system initialized successfully', name: 'Bootstrap');
  } catch (e, stack) {
    // Plugin system failure is non-fatal — the app can still run
    // with degraded functionality (no plugin content).
    log('Plugin system initialization failed (non-fatal)',
        error: e, stackTrace: stack, name: 'Bootstrap');
  }

  // Auto-scan local music folders if enabled (fire-and-forget).
  try {
    final settingsDao = SettingsDAO(DBProvider.db);
    final autoScan =
        await settingsDao.getSettingBool(SettingKeys.localMusicAutoScan) ??
            true;
    if (autoScan) {
      // Defer local music scan until after initial launch transition and first frame
      unawaited(Future.delayed(const Duration(seconds: 4), () {
        LocalMusicService.create().scanAndPersist();
      }));
    }
  } catch (e) {
    log('Local music auto-scan skipped', error: e, name: 'Bootstrap');
  }

  // Pre-load the plugin-bootstrap done-flag so that _MyAppState can check
  // it synchronously in initState() without an async call.
  try {
    final settingsDao = SettingsDAO(DBProvider.db);
    await OnboardingService.checkAndCacheDone(settingsDao);
    await PluginBootstrapService.checkAndCacheDone(settingsDao);
  } catch (e) {
    log('Could not load bootstrap flag (will re-run bootstrap)',
        error: e, name: 'Bootstrap');
  }
}
