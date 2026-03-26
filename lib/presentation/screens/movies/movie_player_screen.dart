import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models/movie_watch_progress.dart';
import '../../../data/services/movie_progress_service.dart';

class MoviePlayerScreen extends StatefulWidget {
  final int streamId;
  final String title;
  final String poster;
  final String streamUrl;
  final Duration? startAt;

  const MoviePlayerScreen({
    super.key,
    required this.streamId,
    required this.title,
    required this.poster,
    required this.streamUrl,
    this.startAt,
  });

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  Timer? _saveTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _open();
    _listen();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
  }

  Future<void> _open() async {
    await _player.open(Media(widget.streamUrl), play: true);
    if (widget.startAt != null && widget.startAt! > Duration.zero) {
      await _player.seek(widget.startAt!);
    }
  }

  void _listen() {
    _positionSub = _player.stream.position.listen((value) {
      if (!_seeking && mounted) {
        setState(() => _position = value);
      }
    });
    _durationSub = _player.stream.duration.listen((value) {
      if (mounted) setState(() => _duration = value);
    });
    _playingSub = _player.stream.playing.listen((value) {
      if (mounted) setState(() => _playing = value);
    });
  }

  Future<void> _saveProgress() async {
    final durationMs = _duration.inMilliseconds;
    if (durationMs <= 0) return;

    await MovieProgressService.saveProgress(
      MovieWatchProgress(
        streamId: widget.streamId,
        title: widget.title,
        poster: widget.poster,
        positionMs: _position.inMilliseconds,
        durationMs: durationMs,
      ),
    );
  }

  String _format(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final positionMs = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Video(
              controller: _controller,
              controls: NoVideoControls,
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  Slider(
                    value: positionMs,
                    max: maxMs,
                    onChangeStart: (_) => setState(() => _seeking = true),
                    onChanged: (value) {
                      setState(() => _position = Duration(milliseconds: value.toInt()));
                    },
                    onChangeEnd: (value) async {
                      final target = Duration(milliseconds: value.toInt());
                      await _player.seek(target);
                      setState(() {
                        _seeking = false;
                        _position = target;
                      });
                    },
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () {
                          if (_playing) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_format(_position)} / ${_format(_duration)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
