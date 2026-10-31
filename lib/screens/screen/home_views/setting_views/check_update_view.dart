import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';
import 'package:Orvia/services/updater/in_app_update_manager.dart';

class CheckUpdateView extends StatefulWidget {
  final Future<UpdateCheckResult>? initialFuture;
  const CheckUpdateView({super.key, this.initialFuture});

  @override
  State<CheckUpdateView> createState() => _CheckUpdateViewState();
}

class _CheckUpdateViewState extends State<CheckUpdateView> {
  late Future<UpdateCheckResult> _updateFuture;

  @override
  void initState() {
    super.initState();
    if (widget.initialFuture != null) {
      _updateFuture = widget.initialFuture!;
    } else {
      _startCheck();
    }
  }

  void _startCheck() {
    setState(() {
      _updateFuture = OrviaUpdateService.instance.checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Default_Theme.themeColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.updateCheckTitle,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ).merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: Center(
        child: FutureBuilder<UpdateCheckResult>(
          future: _updateFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildCheckingView(l10n);
            }

            if (snapshot.hasError) {
              return _buildFailedView(
                title: 'Check Failed',
                message: snapshot.error.toString(),
                currentVer: '',
                currentBuild: '',
              );
            }

            final result = snapshot.data;
            if (result == null) {
              return _buildFailedView(
                title: 'Check Failed',
                message: 'No update response received.',
                currentVer: '',
                currentBuild: '',
              );
            }

            switch (result.status) {
              case UpdateStatus.updateAvailable:
                return _buildUpdateAvailableView(l10n, result);
              case UpdateStatus.upToDate:
                return _buildUpToDateView(l10n, result);
              case UpdateStatus.checkFailed:
              case UpdateStatus.downloadFailed:
              default:
                return _buildFailedView(
                  title: 'Unable to Check for Updates',
                  message: result.errorMessage ??
                      'An unexpected error occurred while checking for updates.',
                  currentVer: result.currentVersion ?? '',
                  currentBuild: result.currentBuild ?? '',
                );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCheckingView(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(
              color: Default_Theme.accentColor2,
              strokeWidth: 3,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth * 0.7,
              child: Text(
                l10n.updateChecking,
                style: const TextStyle(
                  color: Default_Theme.accentColor2,
                  fontSize: 18,
                ).merge(Default_Theme.tertiaryTextStyle),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpToDateView(AppLocalizations l10n, UpdateCheckResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Default_Theme.accentColor2.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Default_Theme.accentColor2.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.5),
              child: Image.asset(
                'assets/icons/OrviaLogo_Master.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.updateUpToDate,
            style: const TextStyle(
              color: Default_Theme.accentColor2,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ).merge(Default_Theme.secondoryTextStyleMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: _startCheck,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(MingCute.refresh_3_line, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Check Again',
                  style: const TextStyle(fontSize: 15)
                      .merge(Default_Theme.secondoryTextStyleMedium),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildVersionFooter(l10n, result.currentVersion, result.currentBuild),
        ],
      ),
    );
  }

  Widget _buildUpdateAvailableView(
      AppLocalizations l10n, UpdateCheckResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Default_Theme.accentColor2.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              MingCute.arrow_up_circle_fill,
              size: 56,
              color: Default_Theme.accentColor2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.updateNewVersionAvailable,
            style: const TextStyle(
              color: Default_Theme.accentColor2,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ).merge(Default_Theme.tertiaryTextStyle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.updateVersion(
              result.newVersion ?? '',
              result.newBuild ?? '',
            ),
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
              fontSize: 16,
            ).merge(Default_Theme.tertiaryTextStyle),
            textAlign: TextAlign.center,
          ),
          if (result.isBelowMinSupportedVersion) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MingCute.alert_line, size: 16, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Your installed version is below the minimum supported baseline.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  result.releaseNotes!,
                  style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.85),
                    fontSize: 13,
                  ).merge(Default_Theme.tertiaryTextStyle),
                ),
              ),
            ),
          ],
          if (result.sha256 != null && result.sha256!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'SHA-256: ${result.sha256!.substring(0, 16)}...',
              style: TextStyle(
                color: Default_Theme.primaryColor2.withValues(alpha: 0.45),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              InAppUpdateManager.instance.showUpdateDialog(context, result);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(MingCute.download_2_fill, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.updateDownloadNow,
                  style: const TextStyle(fontSize: 16)
                      .merge(Default_Theme.secondoryTextStyleMedium),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildVersionFooter(l10n, result.currentVersion, result.currentBuild),
        ],
      ),
    );
  }

  Widget _buildFailedView({
    required String title,
    required String message,
    required String currentVer,
    required String currentBuild,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              MingCute.alert_fill,
              size: 54,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Default_Theme.primaryColor1,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ).merge(Default_Theme.secondoryTextStyleMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Default_Theme.primaryColor2.withValues(alpha: 0.75),
              fontSize: 14,
            ).merge(Default_Theme.tertiaryTextStyle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _startCheck,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(MingCute.refresh_3_line, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Retry',
                  style: const TextStyle(fontSize: 15)
                      .merge(Default_Theme.secondoryTextStyleMedium),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (currentVer.isNotEmpty)
            _buildVersionFooter(
                AppLocalizations.of(context)!, currentVer, currentBuild),
        ],
      ),
    );
  }

  Widget _buildVersionFooter(
      AppLocalizations l10n, String? currentVer, String? currentBuild) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Text(
        l10n.updateCurrentVersion(
          currentVer ?? '',
          currentBuild ?? '',
        ),
        style: TextStyle(
          color: Default_Theme.primaryColor2.withValues(alpha: 0.5),
          fontSize: 12,
        ).merge(Default_Theme.tertiaryTextStyle),
      ),
    );
  }
}
