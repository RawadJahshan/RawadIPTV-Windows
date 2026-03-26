import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoviePlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final int streamId;
  final Duration? startAt;

  const MoviePlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    required this.streamId,
    this.startAt,
  });

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> {
  final player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 64 * 1024 * 1024,
    ),
  );
  late final controller = VideoController(player);

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;
  Timer? _overlayTimer;
  Timer? _saveTimer;
  Timer? _initialOpenTimeout;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _showControls = true;
  bool _isSeeking = false;
  bool _showError = false;
  String _errorMessage = '';
  Duration _buffered = Duration.zero;
  double _bufferPercent = 0;
  late final String _streamType;
  Completer<void>? _videoReadyCompleter;

  Tracks _tracks = const Tracks();
  Track _selectedTrack = const Track();

  String get _progressKey => 'movie_progress_${widget.streamId}';

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _streamType = getStreamType(widget.streamUrl);
    _configurePlayer();
    _listen();
    _showControlsAndResetTimer();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveWatchProgress());
    _open();
  }

  String getStreamType(String url) {
    final lower = url.toLowerCase().split('?').first;
    if (lower.endsWith('.m3u8')) return 'm3u8';
    if (lower.endsWith('.mp4')) return 'mp4';
    if (lower.endsWith('.mkv')) return 'mkv';
    if (lower.endsWith('.ts')) return 'ts';
    if (lower.endsWith('.avi')) return 'avi';
    return 'unknown';
  }

  void _configurePlayer() {
    if (player.platform is NativePlayer) {
      final native = player.platform as NativePlayer;
      native.setProperty('cache', 'yes');
      native.setProperty('cache-pause', 'no');
      native.setProperty('cache-pause-initial', 'no');
      native.setProperty('network-timeout', '15');
      native.setProperty('demuxer-max-bytes', '50MiB');
      native.setProperty('demuxer-max-back-bytes', '10MiB');

      if (_streamType == 'm3u8') {
        native.setProperty('hls-bitrate', 'max');
        native.setProperty('demuxer-readahead-secs', '10');
        native.setProperty('cache-secs', '30');
        native.setProperty('hr-seek', 'yes');
        native.setProperty('hr-seek-framedrop', 'yes');
      } else if (_streamType == 'mkv' || _streamType == 'avi') {
        native.setProperty('demuxer-readahead-secs', '30');
        native.setProperty('cache-secs', '60');
        native.setProperty('hr-seek', 'yes');
        native.setProperty('hr-seek-framedrop', 'yes');
        native.setProperty('index-mode', 'default');
        native.setProperty('stream-buffer-size', '1m');
      } else if (_streamType == 'mp4' || _streamType == 'ts') {
        native.setProperty('demuxer-readahead-secs', '15');
        native.setProperty('cache-secs', '30');
        native.setProperty('hr-seek', 'yes');
        native.setProperty('hr-seek-framedrop', 'yes');
      }
    }
  }

  Media _media() {
    return Media(
      widget.streamUrl,
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Connection': 'keep-alive',
      },
    );
  }

  Future<void> _open({Duration? startAt}) async {
    _initialOpenTimeout?.cancel();
    _videoReadyCompleter = Completer<void>();
    if (mounted) {
      setState(() {
        _showError = false;
        _errorMessage = '';
      });
    }
    _initialOpenTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && !(_videoReadyCompleter?.isCompleted ?? true)) {
        _handlePlaybackError('Unable to play this stream. Tap to retry.');
      }
    });

    try {
      await player.open(_media(), play: true);

      if (startAt != null && startAt > Duration.zero) {
        await player.seek(startAt);
      } else if (widget.startAt != null && widget.startAt! > Duration.zero) {
        await player.seek(widget.startAt!);
      }

      await player.play();
    } catch (_) {
      _handlePlaybackError('Unable to play this stream. Tap to retry.');
    }
  }

  void _listen() {
    _positionSub = player.stream.position.listen((value) {
      if (!mounted || _isSeeking) return;
      setState(() => _position = value);
    });

    _durationSub = player.stream.duration.listen((value) {
      if (!mounted) return;
      setState(() {
        _duration = value;
        _updateBufferPercent();
      });
    });

    _playingSub = player.stream.playing.listen((value) {
      if (!mounted) return;
      setState(() => _isPlaying = value);
    });

    _bufferingSub = player.stream.buffering.listen((value) {
      if (!mounted) return;
      setState(() => _isBuffering = value);
    });

    _bufferSub = player.stream.buffer.listen((value) {
      if (!mounted) return;
      setState(() {
        _buffered = value;
        _updateBufferPercent();
      });
    });

    _errorSub = player.stream.error.listen((error) {
      if (!mounted || error.isEmpty) return;
      _handlePlaybackError('Unable to play this stream. Tap to retry.');
    });

    _videoParamsSub = player.stream.videoParams.listen((value) {
      if (!mounted) return;
      if (value.w != null && value.h != null) {
        _initialOpenTimeout?.cancel();
        if (!(_videoReadyCompleter?.isCompleted ?? true)) {
          _videoReadyCompleter?.complete();
        }
        setState(() {
          _showError = false;
          _errorMessage = '';
        });
      }
    });

    _tracksSub = player.stream.tracks.listen((value) {
      if (!mounted) return;
      setState(() => _tracks = value);
    });

    _trackSub = player.stream.track.listen((value) {
      if (!mounted) return;
      setState(() => _selectedTrack = value);
    });
  }

  void _showControlsAndResetTimer() {
    _overlayTimer?.cancel();
    if (mounted) {
      setState(() => _showControls = true);
    }
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  Future<void> _seekWithPausePlay(double value) async {
    final target = Duration(milliseconds: value.round());
    setState(() {
      _isSeeking = false;
      _position = target;
    });
    await seekSmart(target);
  }

  Future<void> seekSmart(Duration target) async {
    if (_streamType == 'mkv' || _streamType == 'avi') {
      try {
        await player.open(_media(), play: true);
        await _waitForBufferingToSettle();
        await player.seek(target);
        await player.play();
      } catch (_) {
        _handlePlaybackError('Unable to play this stream. Tap to retry.');
      }
      return;
    }
    await player.pause();
    await player.seek(target);
    await player.play();
  }

  Future<void> _waitForBufferingToSettle() async {
    final completer = Completer<void>();
    late final StreamSubscription<bool> bufferingWaitSub;
    bufferingWaitSub = player.stream.buffering.listen((value) {
      if (!completer.isCompleted && value == false) {
        completer.complete();
      }
    });
    try {
      await completer.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep seeking even if buffering status is delayed.
    } finally {
      await bufferingWaitSub.cancel();
    }
  }

  void _updateBufferPercent() {
    if (_duration.inMilliseconds <= 0) {
      _bufferPercent = 0;
      return;
    }
    _bufferPercent = (_buffered.inMilliseconds / _duration.inMilliseconds * 100).clamp(0, 100).toDouble();
  }

  void _handlePlaybackError(String message) {
    _initialOpenTimeout?.cancel();
    if (!mounted) return;
    setState(() {
      _showError = true;
      _errorMessage = message;
    });
  }

  Future<void> _retryOpen() async {
    final resumeAt = _position > Duration.zero ? _position : null;
    await _open(startAt: resumeAt);
  }

  Future<void> _saveWatchProgress() async {
    final durationMs = _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds;
    if (durationMs <= 0 || positionMs < 0) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'positionMs': positionMs,
      'durationMs': durationMs,
    });
    await prefs.setString(_progressKey, payload);
  }

  String _format(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _trackLabel(dynamic track, int index) {
    if (track is AudioTrack || track is SubtitleTrack) {
      final title = track.title?.trim();
      final language = track.language?.trim();
      if (title != null && title.isNotEmpty) return title;
      if (language != null && language.isNotEmpty) return language;
      return 'Track ${index + 1}';
    }
    return 'Track ${index + 1}';
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _saveTimer?.cancel();
    _initialOpenTimeout?.cancel();
    _saveWatchProgress();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _bufferSub?.cancel();
    _errorSub?.cancel();
    _videoParamsSub?.cancel();
    _tracksSub?.cancel();
    _trackSub?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final positionMs = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();
    final audioTracks = _tracks.audio;
    final subtitleTracks = _tracks.subtitle;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _showControlsAndResetTimer(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showControlsAndResetTimer,
          onPanDown: (_) => _showControlsAndResetTimer(),
          child: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: controller,
                  fit: BoxFit.contain,
                  controls: NoVideoControls,
                ),
              ),
              if (_isBuffering)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              if (_isBuffering)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Buffering ${_bufferPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showError)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: GestureDetector(
                        onTap: _retryOpen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showControls ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
                        color: Colors.black54,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        color: Colors.black54,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: positionMs,
                              max: maxMs,
                              onChangeStart: (_) => setState(() => _isSeeking = true),
                              onChanged: (value) {
                                setState(() => _position = Duration(milliseconds: value.round()));
                              },
                              onChangeEnd: _seekWithPausePlay,
                            ),
                            Row(
                              children: [
                                Text(
                                  '${_format(_position)} / ${_format(_duration)}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    if (_isPlaying) {
                                      player.pause();
                                    } else {
                                      player.play();
                                    }
                                  },
                                  icon: Icon(
                                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    size: 34,
                                    color: Colors.white,
                                  ),
                                ),
                                if (audioTracks.isNotEmpty)
                                  PopupMenuButton<AudioTrack>(
                                    tooltip: 'Audio tracks',
                                    onSelected: (track) => player.setAudioTrack(track),
                                    itemBuilder: (context) {
                                      return List.generate(audioTracks.length, (index) {
                                        final track = audioTracks[index];
                                        final selected = track.id == _selectedTrack.audio.id;
                                        return PopupMenuItem<AudioTrack>(
                                          value: track,
                                          child: Row(
                                            children: [
                                              if (selected) const Icon(Icons.check, size: 16),
                                              if (selected) const SizedBox(width: 6),
                                              Flexible(child: Text(_trackLabel(track, index))),
                                            ],
                                          ),
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                                  ),
                                if (subtitleTracks.isNotEmpty)
                                  PopupMenuButton<SubtitleTrack>(
                                    tooltip: 'Subtitles',
                                    onSelected: (track) => player.setSubtitleTrack(track),
                                    itemBuilder: (context) {
                                      final items = <PopupMenuEntry<SubtitleTrack>>[
                                        PopupMenuItem<SubtitleTrack>(
                                          value: SubtitleTrack.no(),
                                          child: Row(
                                            children: [
                                              if (_selectedTrack.subtitle.id == 'no') const Icon(Icons.check, size: 16),
                                              if (_selectedTrack.subtitle.id == 'no') const SizedBox(width: 6),
                                              const Text('Off'),
                                            ],
                                          ),
                                        ),
                                      ];
                                      items.addAll(
                                        List.generate(subtitleTracks.length, (index) {
                                          final track = subtitleTracks[index];
                                          final selected = track.id == _selectedTrack.subtitle.id;
                                          return PopupMenuItem<SubtitleTrack>(
                                            value: track,
                                            child: Row(
                                              children: [
                                                if (selected) const Icon(Icons.check, size: 16),
                                                if (selected) const SizedBox(width: 6),
                                                Flexible(child: Text(_trackLabel(track, index))),
                                              ],
                                            ),
                                          );
                                        }),
                                      );
                                      return items;
                                    },
                                    icon: const Icon(Icons.closed_caption, color: Colors.white),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
