import 'dart:io';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/storage_backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// Screen displayed when the local Isar database fails to initialize at startup.
///
/// Prevents instantiating DB-dependent DAOs, Blocs, or background tasks until
/// the database is successfully restored or cleanly initialized.
class DatabaseRecoveryScreen extends StatefulWidget {
  final DbInitError error;
  final VoidCallback onRecovered;

  const DatabaseRecoveryScreen({
    super.key,
    required this.error,
    required this.onRecovered,
  });

  @override
  State<DatabaseRecoveryScreen> createState() => _DatabaseRecoveryScreenState();
}

class _DatabaseRecoveryScreenState extends State<DatabaseRecoveryScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  String? _errorMessage;

  Future<void> _handleRetry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Retrying database connection...';
    });

    try {
      final success = await DBProvider.retryInit();
      if (!mounted) return;

      if (success && DBProvider.isHealthy) {
        widget.onRecovered();
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage =
              'Database is still unavailable. If another Orvia window or background process is running, please close it and try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = null;
        _errorMessage = 'Retry failed: $e';
      });
    }
  }

  Future<void> _handleRestoreBackup() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['isar', 'json', 'db'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = result.files.first.path;
      if (path == null) {
        setState(() {
          _errorMessage = 'Unable to read selected file path.';
        });
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'Selected file does not exist: $path';
        });
        return;
      }

      final ext = path.toLowerCase().split('.').last;
      if (ext != 'isar' && ext != 'db' && ext != 'json') {
        setState(() {
          _errorMessage =
              'Unsupported format (.$ext). Only .isar database snapshots and .json backups are supported.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _statusMessage = 'Restoring database from backup...';
      });

      // If restoring from JSON and current DB is unreadable, we need an empty DB first
      if (ext == 'json' && !DBProvider.isHealthy) {
        final freshOk = await DBProvider.safeStartFresh();
        if (!freshOk) {
          throw Exception('Failed to prepare clean database for JSON import.');
        }
      }

      final restoreResult = await StorageBackupService.restoreBackup(path);
      if (!mounted) return;

      if (restoreResult['success'] == true) {
        widget.onRecovered();
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage =
              restoreResult['error']?.toString() ?? 'Restore failed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = null;
        _errorMessage = 'Backup restore error: $e';
      });
    }
  }

  Future<void> _handleStartFresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(MingCute.alert_line, color: Colors.amber, size: 24),
            SizedBox(width: 10),
            Text('Start Fresh Database?',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your existing database file will NOT be deleted.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A verified copy with SHA-256 validation will be archived in the support folder before initializing a fresh library. You can restore your data from that archive later.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Text(
                'Residual Risk: Any uncommitted writes or corrupted sectors in the old file cannot be recovered automatically.',
                style: TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start Fresh'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Safely archiving old data and creating fresh database...';
    });

    try {
      final success = await DBProvider.safeStartFresh();
      if (!mounted) return;

      if (success && DBProvider.isHealthy) {
        widget.onRecovered();
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage =
              'Failed to create fresh database. Please check disk space and permissions.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = null;
        _errorMessage = 'Start fresh error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransient = widget.error.isTransient;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF181822),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isTransient
                      ? Colors.amber.withOpacity(0.4)
                      : Colors.redAccent.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header icon
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTransient
                            ? Colors.amber.withOpacity(0.15)
                            : Colors.redAccent.withOpacity(0.15),
                      ),
                      child: Icon(
                        isTransient
                            ? MingCute.lock_line
                            : MingCute.shield_shape_line,
                        size: 32,
                        color: isTransient ? Colors.amber : Colors.redAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    isTransient
                        ? 'Database File is Busy or Locked'
                        : 'Database Startup Protection',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // User-friendly description
                  Text(
                    widget.error.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quarantined info box if present
                  if (widget.error.quarantinedCopyPath != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blueGrey.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(MingCute.save_2_line,
                                  size: 16, color: Colors.lightBlueAccent),
                              SizedBox(width: 8),
                              Text(
                                'Safety Backup Preserved',
                                style: TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A verified copy was saved before quarantine:\n${widget.error.quarantinedCopyPath}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Residual risk notice
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Safety Notice: Orvia protects all existing files and never silently deletes data. However, unwritten in-memory changes or hardware disk corruptions cannot be reconstructed automatically.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status / Error message
                  if (_statusMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],

                  // Actions
                  if (_isLoading) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else ...[
                    // Primary Action: Retry
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isTransient ? Colors.amber : const Color(0xFF6366F1),
                        foregroundColor:
                            isTransient ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(MingCute.refresh_3_line, size: 18),
                      label: const Text('Retry Connection',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _handleRetry,
                    ),
                    const SizedBox(height: 10),

                    // Secondary Action: Restore Backup
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(MingCute.upload_2_line, size: 18),
                      label: const Text('Restore from Backup (.isar / .json)'),
                      onPressed: _handleRestoreBackup,
                    ),
                    const SizedBox(height: 10),

                    // Tertiary Action: Start Fresh
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(MingCute.delete_2_line, size: 16),
                      label: const Text('Safely Archive & Start Fresh'),
                      onPressed: _handleStartFresh,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
