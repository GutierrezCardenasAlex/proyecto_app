import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import 'app_update_manifest.dart';
import 'app_update_service.dart';

class DriverAppUpdateGate extends StatefulWidget {
  const DriverAppUpdateGate({
    super.key,
    required this.child,
    required this.appId,
  });

  final Widget child;
  final String appId;

  @override
  State<DriverAppUpdateGate> createState() => _DriverAppUpdateGateState();
}

class _DriverAppUpdateGateState extends State<DriverAppUpdateGate> {
  late final AppUpdateService _service;
  bool _checked = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _service = AppUpdateService(appId: widget.appId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scheduleCheck());
    });
  }

  Future<void> _scheduleCheck() async {
    if (_checked || !Platform.isAndroid || !mounted) {
      return;
    }
    _checked = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    final result = await _service.checkForUpdate();
    final update = result.update;
    if (!mounted || update == null || _dialogVisible) {
      return;
    }
    _dialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (context) => _DriverUpdateDialog(
        manifest: update,
        localVersion: result.localVersion,
        onIgnore: update.mandatory
            ? null
            : () async {
                await _service.ignoreVersion(update.buildNumber);
              },
        onInstall: (onProgress) {
          return _service.downloadAndInstall(
            update,
            packageName: result.packageName,
            onProgress: onProgress,
          );
        },
      ),
    );
    _dialogVisible = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DriverUpdateDialog extends StatefulWidget {
  const _DriverUpdateDialog({
    required this.manifest,
    required this.localVersion,
    required this.onInstall,
    this.onIgnore,
  });

  final AppUpdateManifest manifest;
  final String localVersion;
  final Future<void> Function(void Function(double progress) onProgress) onInstall;
  final Future<void> Function()? onIgnore;

  @override
  State<_DriverUpdateDialog> createState() => _DriverUpdateDialogState();
}

class _DriverUpdateDialogState extends State<_DriverUpdateDialog> {
  bool _installing = false;
  double _progress = 0;
  String? _error;

  Future<void> _startInstall() async {
    if (_installing) {
      return;
    }
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await widget.onInstall((progress) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = progress;
        });
      });
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _installing = false;
        _error = 'No se pudo iniciar la actualizacion. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !widget.manifest.mandatory && !_installing,
      child: AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppBrand.accentYellow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.system_update_alt_rounded, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.manifest.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.manifest.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Version actual ${widget.localVersion}  •  Nueva ${widget.manifest.version}+${widget.manifest.buildNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
              if (widget.manifest.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...widget.manifest.notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.check_circle, color: AppBrand.accentYellow, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_installing) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: _progress <= 0 ? null : _progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(AppBrand.accentYellow),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress > 0
                      ? 'Descargando ${(100 * _progress).toStringAsFixed(0)}%'
                      : 'Preparando instalacion...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent.shade100,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.manifest.mandatory && !_installing)
            TextButton(
              onPressed: () async {
                await widget.onIgnore?.call();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Ignorar esta version'),
            ),
          if (!widget.manifest.mandatory && !_installing)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mas tarde'),
            ),
          FilledButton.icon(
            onPressed: _installing ? null : _startInstall,
            style: FilledButton.styleFrom(
              backgroundColor: AppBrand.accentYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.download_rounded),
            label: Text(_installing ? 'Descargando...' : 'Actualizar ahora'),
          ),
        ],
      ),
    );
  }
}
