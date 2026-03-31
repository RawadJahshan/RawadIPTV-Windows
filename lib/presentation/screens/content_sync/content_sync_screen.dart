import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/content_sync_service.dart';

class ContentSyncScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final ContentSyncService syncService;
  final Future<void> Function(ContentSyncService service) onSync;
  final ValueChanged<BuildContext> onDone;

  const ContentSyncScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.syncService,
    required this.onSync,
    required this.onDone,
  });

  @override
  State<ContentSyncScreen> createState() => _ContentSyncScreenState();
}

class _ContentSyncScreenState extends State<ContentSyncScreen> {
  late final StreamSubscription<ContentSyncProgress> _progressSubscription;
  double _progress = 0;
  String _stepLabel = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _progressSubscription = widget.syncService.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _progress = progress.value.clamp(0, 1);
        _stepLabel = progress.stepLabel;
      });
    });
    _runSync();
  }

  Future<void> _runSync() async {
    try {
      await widget.onSync(widget.syncService);
      if (!mounted) return;
      widget.onDone(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    widget.syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress <= 0 ? null : _progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 12),
              Text(
                _hasError
                    ? 'Failed to sync content. Please try again.'
                    : (_stepLabel.isEmpty ? 'Preparing...' : _stepLabel),
                style: TextStyle(
                  color: _hasError ? Colors.redAccent : Colors.white60,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
