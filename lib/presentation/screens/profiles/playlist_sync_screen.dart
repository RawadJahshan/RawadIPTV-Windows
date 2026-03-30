import 'package:flutter/material.dart';

import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/services/catalog_sync_service.dart';

class PlaylistSyncScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final String profileKey;
  final String title;

  const PlaylistSyncScreen({
    super.key,
    required this.xtreamApi,
    required this.profileKey,
    required this.title,
  });

  @override
  State<PlaylistSyncScreen> createState() => _PlaylistSyncScreenState();
}

class _PlaylistSyncScreenState extends State<PlaylistSyncScreen> {
  CatalogSyncProgress _progress = const CatalogSyncProgress(
    step: 0,
    totalSteps: 6,
    message: 'Starting...',
  );

  String? _error;

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    try {
      final summary = await CatalogSyncService.syncXtreamCatalog(
        xtreamApi: widget.xtreamApi,
        profileKey: widget.profileKey,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
          });
        },
      );
      if (!mounted) return;
      Navigator.pop(context, summary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to sync playlist content. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _progress.fraction.clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: const Color(0xFF2A2A3E),
            elevation: 8,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error ?? _progress.message,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: _error == null ? fraction : null,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                    backgroundColor: Colors.white12,
                    color: const Color(0xFF00c6ff),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_progress.step}/${_progress.totalSteps}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      if (_error != null)
                        TextButton.icon(
                          onPressed: _runSync,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
