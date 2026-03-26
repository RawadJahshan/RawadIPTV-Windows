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
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;
  Timer? _overlayTimer;
  Timer? _saveTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _showControls = true;
  bool _isSeeking = false;

  Tracks _tracks = const Tracks();
  Track _selectedTrack = const Track();

  String get _progressKey => 'movie_progress_${widget.streamId}';

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _configurePlayer();
    _listen();
    _showControlsAndResetTimer();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveWatchProgress());
    _open();
  }

  void _configurePlayer() {
    if (player.platform is NativePlayer) {
      final native = player.platform as NativePlayer;
      native.setProperty('cache', 'yes');
      native.setProperty('cache-secs', '30');
      native.setProperty('demuxer-max-bytes', '50MiB');
      native.setProperty('demuxer-readahead-secs', '20');
      native.setProperty('cache-pause', 'no');
      native.setProperty('cache-pause-initial', 'no');
      native.setProperty('network-timeout', '10');
      native.setProperty('hr-seek', 'yes');
      native.setProperty('hr-seek-framedrop', 'yes');
    }
  }

  Future<void> _open() async {
    await player.open(
      Media(
        widget.streamUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Connection': 'keep-alive',
        },
      ),
    );

    if (widget.startAt != null && widget.startAt! > Duration.zero) {
      await player.seek(widget.startAt!);
    }

    await player.play();
  }

  void _listen() {
    _positionSub = player.stream.position.listen((value) {
      if (!mounted || _isSeeking) return;
      setState(() => _position = value);
    });

    _durationSub = player.stream.duration.listen((value) {
      if (!mounted) return;
      setState(() => _duration = value);
    });

    _playingSub = player.stream.playing.listen((value) {
      if (!mounted) return;
      setState(() => _isPlaying = value);
    });

    _bufferingSub = player.stream.buffering.listen((value) {
      if (!mounted) return;
      setState(() => _isBuffering = value);
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
    await player.pause();
    await player.seek(target);
    await player.play();
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
    _saveWatchProgress();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
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
