import 'package:flutter/material.dart';

class ContentProgressScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<void> Function() onRun;
  final void Function(BuildContext context)? onCompleted;

  const ContentProgressScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRun,
    this.onCompleted,
  });

  @override
  State<ContentProgressScreen> createState() => _ContentProgressScreenState();
}

class _ContentProgressScreenState extends State<ContentProgressScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await widget.onRun();
      if (!mounted) return;

      if (widget.onCompleted != null) {
        widget.onCompleted!.call(context);
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load content. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF24243A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? widget.subtitle,
                style: TextStyle(
                  color: _error == null ? Colors.white70 : Colors.redAccent,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _run,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
