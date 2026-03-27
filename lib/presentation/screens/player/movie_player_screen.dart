import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

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
  late Player _player;
  bool _overlayVisible = true;
  Timer? _hideTimer;
  bool _isSeeking = false;
  double? _sliderDragValue;
  bool _isBuffering = true;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  int _bufferPercent = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _progressTimer;
  List<String> _audioTracks = [];
  int _selectedAudioTrack = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = Player(id: widget.streamId);

    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos.position ?? Duration.zero;
        _duration = pos.duration ?? Duration.zero;
      });
    });

    _player.bufferingProgressStream.listen((percent) {
      if (!mounted) return;
      setState(() {
        _bufferPercent = percent.toInt();
        _isBuffering = percent < 100;
      });
    });

    _player.playbackStream.listen((playback) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playback.isPlaying;
        _isBuffering = !playback.isPlaying && !playback.isCompleted;
      });
    });

    _player.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64)');

    _player.open(
      Media.network(widget.streamUrl),
      autoStart: true,
    );

    _player.currentStream.listen((current) {
      if (!mounted) return;
      final audioCount = _player.audioTrackCount;
      setState(() {
        _audioTracks = audioCount > 0
            ? List.generate(audioCount, (i) => 'Audio Track ${i + 1}')
            : [];
      });
    });

    if (widget.startAt != null && widget.startAt! > Duration.zero) {
      await Future<void>.delayed(const Duration(seconds: 2));
      _player.seek(widget.startAt!);
    }

    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });

    _scheduleHide();
  }

  Future<void> _saveProgress() async {
    if (_duration.inMilliseconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('progress_pos_${widget.streamId}', _position.inMilliseconds);
    await prefs.setInt('progress_dur_${widget.streamId}', _duration.inMilliseconds);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  void _showOverlay() {
    if (!_overlayVisible) setState(() => _overlayVisible = true);
    _scheduleHide();
  }

  void _skip(int seconds) {
    final target = _position + Duration(seconds: seconds);
    if (target < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (_duration > Duration.zero && target > _duration) {
      _player.seek(_duration);
    } else {
      _player.seek(target);
    }
  }

  Future<void> _seekTo(Duration target) async {
    setState(() => _isSeeking = true);
    try {
      _player.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _isSeeking = false);
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  Future<void> _toggleFullscreen() async {
    final newValue = !_isFullscreen;
    setState(() => _isFullscreen = newValue);
    await WindowManager.instance.setFullScreen(newValue);
  }

  Future<void> _exitFullscreen() async {
    setState(() => _isFullscreen = false);
    await WindowManager.instance.setFullScreen(false);
  }

  @override
  void dispose() {
    WindowManager.instance.setFullScreen(false);
    _saveProgress();
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds <= 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final sliderValue =
        (_sliderDragValue ?? _position.inMilliseconds.toDouble())
            .clamp(0.0, totalMs);

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) _skip(30);
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _skip(-30);
          if (event.logicalKey == LogicalKeyboardKey.space) _player.playOrPause();
          if (event.logicalKey == LogicalKeyboardKey.keyF) {
            unawaited(_toggleFullscreen());
          }
          if (event.logicalKey == LogicalKeyboardKey.escape && _isFullscreen) {
            unawaited(_exitFullscreen());
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _showOverlay(),
          child: GestureDetector(
            onTap: _showOverlay,
            child: Stack(
              children: [
                // Video
                Positioned.fill(
                  child: Video(
                    player: _player,
                    fit: BoxFit.contain,
                    showControls: false,
                  ),
                ),

                // Buffering text top center
                if (_isBuffering)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Buffering $_bufferPercent%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),

                // Seeking spinner
                if (_isSeeking)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                // Overlay
                if (_overlayVisible)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xCC000000),
                              Colors.transparent,
                              Colors.transparent,
                              Color(0xCC000000),
                            ],
                            stops: [0.0, 0.25, 0.75, 1.0],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              // Top bar
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Bottom bar
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  children: [
                                    Slider(
                                      value: sliderValue,
                                      min: 0,
                                      max: totalMs,
                                      onChangeStart: (v) =>
                                          setState(() => _sliderDragValue = v),
                                      onChanged: (v) =>
                                          setState(() => _sliderDragValue = v),
                                      onChangeEnd: (v) {
                                        setState(() => _sliderDragValue = null);
                                        _seekTo(Duration(
                                            milliseconds: v.toInt()));
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, right: 8, bottom: 12),
                                      child: Row(
                                        children: [
                                          Text(
                                            '${_fmt(_position)} / ${_fmt(_duration)}',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13),
                                          ),
                                          const Spacer(),
                                          // Skip back
                                          IconButton(
                                            icon: const Icon(Icons.replay_30,
                                                color: Colors.white),
                                            onPressed: () => _skip(-30),
                                          ),
                                          // Play/Pause
                                          IconButton(
                                            icon: Icon(
                                              _isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                            onPressed: () =>
                                                _player.playOrPause(),
                                          ),
                                          // Skip forward
                                          IconButton(
                                            icon: const Icon(Icons.forward_30,
                                                color: Colors.white),
                                            onPressed: () => _skip(30),
                                          ),
                                          // Audio tracks
                                          if (_audioTracks.isNotEmpty)
                                            PopupMenuButton<int>(
                                              tooltip: 'Audio Track',
                                              icon: const Icon(Icons.audiotrack,
                                                  color: Colors.white),
                                              onSelected: (index) {
                                                _player.setAudioTrack(index);
                                                setState(() =>
                                                    _selectedAudioTrack = index);
                                              },
                                              itemBuilder: (_) => _audioTracks
                                                  .asMap()
                                                  .entries
                                                  .map((e) => PopupMenuItem(
                                                        value: e.key,
                                                        child: Row(
                                                          children: [
                                                            if (_selectedAudioTrack ==
                                                                e.key)
                                                              const Icon(
                                                                Icons.check,
                                                                size: 16,
                                                              ),
                                                            if (_selectedAudioTrack ==
                                                                e.key)
                                                              const SizedBox(
                                                                  width: 8),
                                                            Text(e.value),
                                                          ],
                                                        ),
                                                      ))
                                                  .toList(),
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              _isFullscreen
                                                  ? Icons.fullscreen_exit
                                                  : Icons.fullscreen,
                                              color: Colors.white,
                                            ),
                                            onPressed: () =>
                                                _toggleFullscreen(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
