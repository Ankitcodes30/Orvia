import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';

/// Manages in-app update checks, background startup checks, and platform-specific
/// installation workflows for Android and Windows.
class InAppUpdateManager {
  static final InAppUpdateManager instance = InAppUpdateManager._();
  InAppUpdateManager._();

  static const MethodChannel _androidInstallerChannel =
      MethodChannel('ls.orvia.musicplayer/app_installer');

  /// Tracks if an update dialog has already been shown/dismissed during this app run.
  bool _sessionDismissed = false;
  bool _isUpdateCheckRunning = false;
  UpdateCheckResult? _lastResult;

  UpdateCheckResult? get lastResult => _lastResult;

  /// Check for updates in the background on app startup and prompt the user if an update is available.
  Future<void> checkOnStartup(BuildContext context) async {
    if (_sessionDismissed || _isUpdateCheckRunning) return;
    _isUpdateCheckRunning = true;

    try {
      final result = await OrviaUpdateService.instance.checkForUpdates();
      _lastResult = result;

      if (result.isUpdateAvailable && !_sessionDismissed) {
        if (context.mounted) {
          showUpdateDialog(context, result);
        }
      }
    } catch (e, st) {
      log('Background update check failed: $e\n$st',
          name: 'InAppUpdateManager');
    } finally {
      _isUpdateCheckRunning = false;
    }
  }

  /// Present the theme-consistent In-App Update Dialog.
  Future<void> showUpdateDialog(
    BuildContext context,
    UpdateCheckResult result,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _InAppUpdateDialog(
        result: result,
        onDismiss: () {
          _sessionDismissed = true;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  /// Android helper to check if unknown apps can be requested.
  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool allowed = await _androidInstallerChannel
              .invokeMethod('canRequestPackageInstalls') ??
          true;
      return allowed;
    } catch (_) {
      return true;
    }
  }

  /// Android helper to open the unknown apps settings screen.
  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidInstallerChannel
          .invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      log('Could not open install settings: $e', name: 'InAppUpdateManager');
    }
  }

  /// Android helper to trigger package installer intent.
  static Future<void> installAndroidApk(String filePath) async {
    if (!Platform.isAndroid) return;
    await _androidInstallerChannel
        .invokeMethod('installApk', {'filePath': filePath});
  }

  /// Windows helper to stage, replace and relaunch portable ZIP distribution.
  static Future<void> installWindowsZip({
    required File zipFile,
    required String expectedVersion,
    String? targetAppDir,
    String? targetExecutablePath,
    bool autoExitOnSuccess = true,
    void Function(String message)? onStatus,
    Directory? customTempDir,
    bool launchAfterUpdate = true,
    @visibleForTesting bool simulateCopyFailureForTesting = false,
    @visibleForTesting bool simulateRollbackFailureForTesting = false,
  }) async {
    if (!Platform.isWindows) return;

    onStatus?.call('Extracting update package...');
    final tempDir = customTempDir ?? await getTemporaryDirectory();
    final updateDir = Directory(p.join(
      tempDir.path,
      'OrviaUpdate_${DateTime.now().microsecondsSinceEpoch}',
    ));
    updateDir.createSync();
    final stagingDir = Directory(p.join(updateDir.path, 'staging'));
    stagingDir.createSync(recursive: true);
    final canonicalStaging = p.canonicalize(stagingDir.path);

    // 1. Extract ZIP with strict Zip Slip protection (CWE-22)
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (filename.trim().isEmpty) continue;

      // Reject path traversal attempts, absolute paths, alternate data streams, or UNC drives
      if (filename.contains('\x00') ||
          filename.contains(':') ||
          filename.startsWith('/') ||
          filename.startsWith('\\') ||
          filename.contains(r'\\')) {
        updateDir.deleteSync(recursive: true);
        throw FileSystemException(
          'Security Exception: Malicious ZIP entry with invalid characters or absolute/UNC path: $filename',
        );
      }

      final outPath = p.join(stagingDir.path, filename);
      final canonicalOut = p.canonicalize(outPath);

      if (!p.isWithin(canonicalStaging, canonicalOut) || canonicalOut == canonicalStaging) {
        updateDir.deleteSync(recursive: true);
        throw FileSystemException(
          'Security Exception: Malicious ZIP entry attempted path traversal outside staging directory: $filename',
          outPath,
        );
      }

      if (file.isFile) {
        final outFile = File(canonicalOut);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(canonicalOut).createSync(recursive: true);
      }
    }

    // 2. Identify the root containing orvia.exe
    Directory contentRoot = stagingDir;
    File? foundExe;
    for (final entity in stagingDir.listSync(recursive: true)) {
      if (entity is File &&
          p.basename(entity.path).toLowerCase() == 'orvia.exe') {
        foundExe = entity;
        contentRoot = entity.parent;
        break;
      }
    }

    if (foundExe == null || !foundExe.existsSync()) {
      updateDir.deleteSync(recursive: true);
      throw Exception(
          'Update package is invalid: orvia.exe was not found in extracted archive.');
    }

    // Pre-installation staging validation: verify critical supporting runtime files
    final flutterDll = File(p.join(contentRoot.path, 'flutter_windows.dll'));
    final dataDir = Directory(p.join(contentRoot.path, 'data'));
    if (!flutterDll.existsSync() || !dataDir.existsSync()) {
      updateDir.deleteSync(recursive: true);
      throw Exception(
          'Update package is incomplete: missing required runtime files (flutter_windows.dll or data directory).');
    }

    final executablePath = targetExecutablePath ?? Platform.resolvedExecutable;
    final appDir = targetAppDir ?? File(executablePath).parent.path;
    final currentPid = pid;
    final cleanExpectedVer = expectedVersion.trim().replaceFirst(
          RegExp(r'^v', caseSensitive: false),
          '',
        );
    if (cleanExpectedVer.isEmpty) {
      updateDir.deleteSync(recursive: true);
      throw ArgumentError.value(expectedVersion, 'expectedVersion',
          'Must include version and build number.');
    }

    // Detect if running from a temporary or virtual directory
    final tempPath = tempDir.path.toLowerCase();
    final appDirPath = appDir.toLowerCase();
    if (p.isWithin(tempPath, appDirPath) ||
        appDirPath.contains(r'\appdata\local\temp\temp') ||
        appDirPath.contains(r'\appdata\local\temp\tmp')) {
      log(
          'WARNING: Orvia is executing from a temporary location ($appDir). '
          'If launched directly from a compressed archive, please extract the complete ZIP before updating.',
          name: 'InAppUpdateManager');
    }

    onStatus?.call('Applying update and restarting...');

    final cleanSrcDir = normalizeWindowsPath(contentRoot.path);
    final cleanAppDir = normalizeWindowsPath(appDir);
    final cleanAppExe = normalizeWindowsPath(executablePath);
    final cleanStagingDir = normalizeWindowsPath(stagingDir.path);
    final cleanBackupDir =
        normalizeWindowsPath(p.join(updateDir.path, 'backup'));
    final cleanVerifyScript =
        normalizeWindowsPath(p.join(updateDir.path, 'verify_tree.ps1'));
    final cleanUpdateDir = normalizeWindowsPath(updateDir.path);

    // 3. Create a reliable self-updating batch script
    final scriptFile = File(p.join(updateDir.path, 'apply_update.bat'));
    final logFile = normalizeWindowsPath(p.join(updateDir.path, 'update.log'));
    final verifyScript = File(cleanVerifyScript);
    verifyScript.writeAsStringSync(r'''
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [switch]$AllowExtraDestination
)
$ErrorActionPreference = 'Stop'
function Get-TreeHashes([string]$Path) {
    $root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/') + '\'
    Get-ChildItem -LiteralPath $Path -File -Recurse -Force | ForEach-Object {
        [pscustomobject]@{
            RelativePath = $_.FullName.Substring($root.Length)
            Length = $_.Length
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } | Sort-Object RelativePath
}
try {
    $differences = Compare-Object `
        (Get-TreeHashes -Path $Source) `
        (Get-TreeHashes -Path $Destination) `
        -Property RelativePath, Length, Hash
    if ($AllowExtraDestination) {
        $differences = $differences | Where-Object { $_.SideIndicator -eq '<=' }
    }
    if ($differences) { exit 1 }
    exit 0
} catch {
    Write-Error $_
    exit 2
}
''');

    final batchContent = '''
@echo off
setlocal EnableDelayedExpansion
title Orvia Updater

set "TARGET_PID=${autoExitOnSuccess ? currentPid : 0}"
set "SRC_DIR=$cleanSrcDir"
set "APP_DIR=$cleanAppDir"
set "APP_EXE=$cleanAppExe"
set "STAGING_DIR=$cleanStagingDir"
set "BACKUP_DIR=$cleanBackupDir"
set "UPDATE_DIR=$cleanUpdateDir"
set "VERIFY_SCRIPT=$cleanVerifyScript"
set "LOG_FILE=$logFile"
set "EXPECTED_VER=$cleanExpectedVer"
set "BACKUP_READY=0"
set "UPDATE_STARTED=0"
set "INSTALLATION_INTACT=1"
set "SIMULATE_COPY_FAILURE=${simulateCopyFailureForTesting ? 1 : 0}"
set "SIMULATE_ROLLBACK_FAILURE=${simulateRollbackFailureForTesting ? 1 : 0}"

echo =================================================== > "!LOG_FILE!"
echo [%DATE% %TIME%] Starting Orvia Update >> "!LOG_FILE!"
echo Target PID: !TARGET_PID! >> "!LOG_FILE!"
echo Source: "!SRC_DIR!" >> "!LOG_FILE!"
echo Destination: "!APP_DIR!" >> "!LOG_FILE!"
echo Backup: "!BACKUP_DIR!" >> "!LOG_FILE!"
echo Target Executable: "!APP_EXE!" >> "!LOG_FILE!"
echo Expected Version: !EXPECTED_VER! >> "!LOG_FILE!"
echo =================================================== >> "!LOG_FILE!"

:: 1. Validate Source Directory before stopping or copying
if not exist "!SRC_DIR!\\orvia.exe" (
    echo [%DATE% %TIME%] ERROR: orvia.exe missing from staging directory: "!SRC_DIR!" >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if not exist "!SRC_DIR!\\flutter_windows.dll" (
    echo [%DATE% %TIME%] ERROR: flutter_windows.dll missing from staging directory: "!SRC_DIR!" >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if not exist "!SRC_DIR!\\data\\." (
    echo [%DATE% %TIME%] ERROR: data directory missing from staging directory: "!SRC_DIR!" >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
powershell.exe -NoProfile -Command "\$exe=Get-Item -LiteralPath \$env:SRC_DIR\\orvia.exe; \$dll=Get-Item -LiteralPath \$env:SRC_DIR\\flutter_windows.dll; \$data=Get-ChildItem -LiteralPath \$env:SRC_DIR\\data -File -Recurse | Select-Object -First 1; if (\$exe.Length -le 0 -or \$dll.Length -le 0 -or -not \$data) { exit 1 }" >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo [%DATE% %TIME%] ERROR: staged executable, runtime DLL, or data directory is invalid. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if "!EXPECTED_VER!"=="" (
    echo [%DATE% %TIME%] ERROR: expected version and build number are required. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
set "STAGED_VER="
for /f "usebackq tokens=*" %%V in (`powershell.exe -NoProfile -Command "(Get-Item -LiteralPath \$env:SRC_DIR\\orvia.exe).VersionInfo.ProductVersion" 2^>nul`) do set "STAGED_VER=%%V"
if not "!STAGED_VER!"=="!EXPECTED_VER!" (
    echo [%DATE% %TIME%] ERROR: staged executable version mismatch. Expected: [!EXPECTED_VER!], Found: [!STAGED_VER!] >> "!LOG_FILE!"
    goto UPDATE_FAILED
)

:: 2. Wait for running application to terminate
echo Waiting for Orvia process (!TARGET_PID!) to exit...
set /a WAIT_COUNT=0
:WAIT_PROCESS
if "!TARGET_PID!"=="0" goto DO_COPY
tasklist /FI "PID eq !TARGET_PID!" 2>nul | findstr /i "!TARGET_PID!" >nul
if !ERRORLEVEL! equ 0 (
    set /a WAIT_COUNT+=1
    if !WAIT_COUNT! geq 20 (
        echo [%DATE% %TIME%] Process !TARGET_PID! still running after 20 seconds. Forcing termination... >> "!LOG_FILE!"
        taskkill /F /PID !TARGET_PID! >nul 2>&1
        ping 127.0.0.1 -n 2 > nul
        goto DO_COPY
    )
    ping 127.0.0.1 -n 2 > nul
    goto WAIT_PROCESS
)

:DO_COPY
echo [%DATE% %TIME%] Orvia process has exited. Applying update files... >> "!LOG_FILE!"

if not exist "!APP_DIR!\\orvia.exe" (
    echo [%DATE% %TIME%] ERROR: current installation executable is missing. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if not exist "!APP_DIR!\\flutter_windows.dll" (
    echo [%DATE% %TIME%] ERROR: current installation runtime DLL is missing. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if not exist "!APP_DIR!\\data\\." (
    echo [%DATE% %TIME%] ERROR: current installation data directory is missing. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)

:: Back up the complete installation and verify every file hash before mutation.
robocopy "!APP_DIR!" "!BACKUP_DIR!" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NP >> "!LOG_FILE!" 2>&1
set "BACKUP_EXIT=!ERRORLEVEL!"
if !BACKUP_EXIT! geq 8 (
    echo [%DATE% %TIME%] ERROR: backup copy failed with Robocopy exit code !BACKUP_EXIT!. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!VERIFY_SCRIPT!" "!APP_DIR!" "!BACKUP_DIR!" >> "!LOG_FILE!" 2>&1
if !ERRORLEVEL! neq 0 (
    echo [%DATE% %TIME%] ERROR: backup hash verification failed; installation was not modified. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
set "BACKUP_READY=1"
echo [%DATE% %TIME%] Backup hash verification succeeded. >> "!LOG_FILE!"

:: Robocopy exit codes 0-7 are non-fatal; 8 and above indicate a copy failure.
set "UPDATE_STARTED=1"
set "INSTALLATION_INTACT=0"
robocopy "!SRC_DIR!" "!APP_DIR!" /E /IS /IT /R:5 /W:1 /NP >> "!LOG_FILE!" 2>&1
set "COPY_EXIT=!ERRORLEVEL!"
if !COPY_EXIT! geq 8 (
    echo [%DATE% %TIME%] ERROR: update copy failed with Robocopy exit code !COPY_EXIT!. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
echo [%DATE% %TIME%] Update copy completed with Robocopy exit code !COPY_EXIT!. >> "!LOG_FILE!"
if "!SIMULATE_COPY_FAILURE!"=="1" (
    echo Injected partial-copy failure for updater test > "!APP_DIR!\\flutter_windows.dll"
    goto UPDATE_FAILED
)

:: 3. Post-Copy Verification: ensure critical files exist and version matches
if not exist "!APP_EXE!" (
    echo [%DATE% %TIME%] ERROR: Target executable "!APP_EXE!" missing after file copy! >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if not exist "!APP_DIR!\\flutter_windows.dll" (
    echo [%DATE% %TIME%] ERROR: Core DLL flutter_windows.dll missing after file copy! >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
if not exist "!APP_DIR!\\data\\." (
    echo [%DATE% %TIME%] ERROR: Core data directory missing after file copy! >> "!LOG_FILE!"
    goto UPDATE_FAILED
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!VERIFY_SCRIPT!" "!SRC_DIR!" "!APP_DIR!" -AllowExtraDestination >> "!LOG_FILE!" 2>&1
if !ERRORLEVEL! neq 0 (
    echo [%DATE% %TIME%] ERROR: installed update files do not match the staged files. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)

set "ACTUAL_VER="
for /f "usebackq tokens=*" %%V in (`powershell.exe -NoProfile -Command "(Get-Item -LiteralPath \$env:APP_EXE).VersionInfo.ProductVersion" 2^>nul`) do set "ACTUAL_VER=%%V"
echo [%DATE% %TIME%] Verifying installed version. Expected: [!EXPECTED_VER!], Found: [!ACTUAL_VER!] >> "!LOG_FILE!"
if not "!ACTUAL_VER!"=="!EXPECTED_VER!" (
    echo [%DATE% %TIME%] ERROR: Installed executable version mismatch. >> "!LOG_FILE!"
    goto UPDATE_FAILED
)

echo [%DATE% %TIME%] Update verified and successfully applied. Relaunching Orvia... >> "!LOG_FILE!"
set "INSTALLATION_INTACT=1"
if "${launchAfterUpdate ? 1 : 0}"=="1" (
    cd /d "!APP_DIR!"
    start "" "!APP_EXE!"
)
start "" /B powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Milliseconds 750; Remove-Item -LiteralPath \$env:UPDATE_DIR -Recurse -Force -ErrorAction SilentlyContinue"
exit /b 0

:UPDATE_FAILED
if "!UPDATE_STARTED!"=="1" goto ROLLBACK_UPDATE
goto REPORT_UPDATE_FAILED

:ROLLBACK_UPDATE
echo [%DATE% %TIME%] Update failed; restoring verified backup... >> "!LOG_FILE!"
if not "!BACKUP_READY!"=="1" goto ROLLBACK_FAILED
if "!SIMULATE_ROLLBACK_FAILURE!"=="1" (
    set "INSTALLATION_INTACT=0"
    echo [%DATE% %TIME%] CRITICAL: rollback could not be verified. Backup retained at "!BACKUP_DIR!". >> "!LOG_FILE!"
    goto REPORT_UPDATE_FAILED
)
robocopy "!BACKUP_DIR!" "!APP_DIR!" /MIR /IS /IT /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NP >> "!LOG_FILE!" 2>&1
set "ROLLBACK_EXIT=!ERRORLEVEL!"
if !ROLLBACK_EXIT! geq 8 goto ROLLBACK_FAILED
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!VERIFY_SCRIPT!" "!APP_DIR!" "!BACKUP_DIR!" >> "!LOG_FILE!" 2>&1
if !ERRORLEVEL! neq 0 goto ROLLBACK_FAILED
set "INSTALLATION_INTACT=1"
echo [%DATE% %TIME%] Rollback verified: restored files match the backup hashes. >> "!LOG_FILE!"
goto REPORT_UPDATE_FAILED

:ROLLBACK_FAILED
set "INSTALLATION_INTACT=0"
echo [%DATE% %TIME%] CRITICAL: rollback could not be verified. Backup retained at "!BACKUP_DIR!". >> "!LOG_FILE!"

:REPORT_UPDATE_FAILED
echo =================================================== >> "!LOG_FILE!"
echo [%DATE% %TIME%] Update failed. Installation intact: !INSTALLATION_INTACT! >> "!LOG_FILE!"
echo =================================================== >> "!LOG_FILE!"
if "!INSTALLATION_INTACT!"=="1" if exist "!APP_EXE!" if "${launchAfterUpdate ? 1 : 0}"=="1" (
    cd /d "!APP_DIR!"
    start "" "!APP_EXE!"
)
if "!INSTALLATION_INTACT!"=="1" start "" /B powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Milliseconds 750; Remove-Item -LiteralPath \$env:UPDATE_DIR -Recurse -Force -ErrorAction SilentlyContinue"
exit /b 1
''';

    await scriptFile.writeAsString(batchContent);

    // 4. Launch detached updater script and terminate running app if requested
    if (autoExitOnSuccess) {
      await Process.start(
        'cmd.exe',
        ['/c', scriptFile.path],
        mode: ProcessStartMode.detached,
      );

      // Give process half a second to launch, then exit
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
  }

  @visibleForTesting
  static String normalizeWindowsPath(String rawPath) {
    final normalized = p.normalize(rawPath.trim());
    final root = p.rootPrefix(normalized);
    if (root.isNotEmpty && p.equals(normalized, root)) return root;
    var result = normalized;
    while (result.length > root.length &&
        (result.endsWith(r'\') || result.endsWith('/'))) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

enum _DialogState {
  prompt,
  downloading,
  verifying,
  permissionRequired,
  installing,
  error,
}

class _InAppUpdateDialog extends StatefulWidget {
  final UpdateCheckResult result;
  final VoidCallback onDismiss;

  const _InAppUpdateDialog({
    required this.result,
    required this.onDismiss,
  });

  @override
  State<_InAppUpdateDialog> createState() => _InAppUpdateDialogState();
}

class _InAppUpdateDialogState extends State<_InAppUpdateDialog> {
  _DialogState _state = _DialogState.prompt;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _statusMessage = '';
  String _errorMessage = '';
  File? _downloadedFile;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1638),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Default_Theme.accentColor2.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _DialogState.prompt:
        return _buildPromptState();
      case _DialogState.downloading:
        return _buildDownloadingState();
      case _DialogState.verifying:
      case _DialogState.installing:
        return _buildWorkingState();
      case _DialogState.permissionRequired:
        return _buildPermissionState();
      case _DialogState.error:
        return _buildErrorState();
    }
  }

  Widget _buildPromptState() {
    final currVer = widget.result.currentVersion ?? '0.0.0';
    final currBuild = widget.result.currentBuild;
    final currStr = (currBuild != null && currBuild.isNotEmpty)
        ? '$currVer+$currBuild'
        : currVer;
    final newVer = widget.result.newVersion ?? '0.0.0';
    final newBuild = widget.result.newBuild;
    final newStr = (newBuild != null && newBuild.isNotEmpty)
        ? '$newVer+$newBuild'
        : newVer;
    final notes = widget.result.releaseNotes?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                MingCute.arrow_up_circle_fill,
                color: Default_Theme.accentColor2,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Orvia Update Available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Current: v$currStr · Latest: v$newStr',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'What\'s New:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SingleChildScrollView(
            child: Text(
              (notes != null && notes.isNotEmpty)
                  ? notes
                  : 'Bug fixes and performance improvements.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Later'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _startDownloadFlow,
              style: FilledButton.styleFrom(
                backgroundColor: Default_Theme.accentColor2,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadingState() {
    final downloadedMb = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = _totalBytes > 0
        ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1)
        : '--';
    final percent = (_progress * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Downloading Update...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Default_Theme.accentColor2),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percent%',
              style: const TextStyle(
                color: Default_Theme.accentColor2,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              '$downloadedMb MB / $totalMb MB',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onDismiss,
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        const SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            color: Default_Theme.accentColor2,
            strokeWidth: 3.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _statusMessage.isNotEmpty ? _statusMessage : 'Processing update...',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildPermissionState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                color: Colors.amber,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Android requires permission to install updates directly from Orvia. Please enable "Install unknown apps" for Orvia, then tap Install.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onDismiss,
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () async {
                await InAppUpdateManager.openInstallPermissionSettings();
              },
              child: const Text('Open Settings'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (_downloadedFile != null) {
                  _proceedWithInstallation(_downloadedFile!);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Default_Theme.accentColor2,
                foregroundColor: Colors.white,
              ),
              child: const Text('Install'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                MingCute.alert_fill,
                color: Colors.redAccent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _errorMessage.isNotEmpty
              ? _errorMessage
              : 'An unexpected error occurred during update.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onDismiss,
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _startDownloadFlow,
              style: FilledButton.styleFrom(
                backgroundColor: Default_Theme.accentColor2,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startDownloadFlow() async {
    final downloadUrl = widget.result.downloadUrl;
    final expectedSha = widget.result.sha256;

    if (downloadUrl == null ||
        downloadUrl.isEmpty ||
        expectedSha == null ||
        expectedSha.isEmpty) {
      setState(() {
        _state = _DialogState.error;
        _errorMessage =
            'Download information or checksum is missing from the update release.';
      });
      return;
    }

    setState(() {
      _state = _DialogState.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = '';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = Platform.isAndroid ? 'apk' : 'zip';
      final destFile = File(p.join(
          tempDir.path, 'orvia_update_${widget.result.newVersion}.$ext'));

      final verifiedFile =
          await OrviaUpdateService.instance.downloadAndVerifyFile(
        downloadUrl: downloadUrl,
        expectedSha256: expectedSha,
        destinationFile: destFile,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              if (total > 0) {
                _progress = received / total;
              }
            });
          }
        },
      );

      _downloadedFile = verifiedFile;
      _proceedWithInstallation(verifiedFile);
    } on IntegrityCheckException catch (e) {
      if (mounted) {
        setState(() {
          _state = _DialogState.error;
          _errorMessage =
              'Package integrity check failed. The downloaded file signature does not match the published release.';
        });
      }
      log('Integrity check failed: $e', name: 'InAppUpdateDialog');
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _DialogState.error;
          _errorMessage = 'Failed to download update: ${e.toString()}';
        });
      }
      log('Download error: $e', name: 'InAppUpdateDialog');
    }
  }

  Future<void> _proceedWithInstallation(File file) async {
    if (Platform.isAndroid) {
      final canInstall = await InAppUpdateManager.canRequestPackageInstalls();
      if (!canInstall) {
        setState(() {
          _state = _DialogState.permissionRequired;
        });
        return;
      }

      setState(() {
        _state = _DialogState.installing;
        _statusMessage = 'Launching package installer...';
      });

      try {
        await InAppUpdateManager.installAndroidApk(file.path);
        // Once installer is open, dismiss the dialog
        widget.onDismiss();
      } catch (e) {
        if (mounted) {
          setState(() {
            _state = _DialogState.error;
            _errorMessage = 'Unable to open Android Package Installer: $e';
          });
        }
      }
    } else if (Platform.isWindows) {
      setState(() {
        _state = _DialogState.installing;
        _statusMessage = 'Extracting and staging update...';
      });

      try {
        final expectedVersion = widget.result.newVersion;
        final expectedBuild = widget.result.newBuild;
        if (expectedVersion == null || expectedBuild == null) {
          throw StateError(
              'The update manifest is missing its version or build number.');
        }
        await InAppUpdateManager.installWindowsZip(
          zipFile: file,
          expectedVersion: '$expectedVersion+$expectedBuild',
          onStatus: (msg) {
            if (mounted) {
              setState(() {
                _statusMessage = msg;
              });
            }
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _state = _DialogState.error;
            _errorMessage = 'Failed to apply Windows update: $e';
          });
        }
      }
    }
  }
}
