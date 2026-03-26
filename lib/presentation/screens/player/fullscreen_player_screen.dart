import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/services/performance_logger.dart';
import '../../../data/services/persistent_player_service.dart';
import '../../../data/services/watch_progress_service.dart';

enum PlaybackType { movie, episode }

class FullscreenPlayerArgs {
  final String title;
  final String streamUrl;
  final PlaybackType type;
  final int contentId;
  final int? seriesId;
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? poster;
  final Duration? startAt;
  final Duration triggerElapsed;

  FullscreenPlayerArgs({
    required this.title,
    required this.streamUrl,
    required this.type,
    required this.contentId,
    required this.triggerElapsed,
    this.seriesId,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
    this.poster,
    this.startAt,
  });
}

class FullscreenPlayerScreen extends StatefulWidget {
  final FullscreenPlayerArgs args;
  const FullscreenPlayerScreen({super.key, required this.args});

  @override
  State<FullscreenPlayerScreen> createState() => _FullscreenPlayerScreenState();
}

class _FullscreenPlayerScreenState extends State<FullscreenPlayerScreen> {
  final _playerService = PersistentPlayerService.instance;

  Timer? _hideTimer;
  bool _overlayVisible = true;
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  AudioTrack? _selectedAudio;
  SubtitleTrack? _selectedSubtitle;

  late final Stopwatch _openSw;
  StreamSubscription? _tracksSub;
  StreamSubscription? _trackSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _videoParamsSub;
  StreamSubscription? _seekResumeSub;
  double? _sliderDragValueMs;
  bool _seekInFlight = false;
  Duration? _pendingSeekTarget;
  Stopwatch? _seekSw;
  bool _isStoppingForClose = false;

  @override
  void initState() {
    super.initState();
    _openSw = Stopwatch()..start();
    _open();
    _attachListeners();
    _scheduleHide();
  }

  Future<void> _open() async {
    PerformanceLogger.log(
      'play_button_to_open_start',
      widget.args.triggerElapsed,
      details: widget.args.title,
    );
    final openStart = Stopwatch()..start();
    await _playerService.openMedia(
      Media(widget.args.streamUrl, httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Connection': 'keep-alive',
      }),
      sourceUrl: widget.args.streamUrl,
      startAt: widget.args.startAt,
    );
    PerformanceLogger.log(
      'player_open_started_to_open_complete',
      openStart.elapsed,
      details: widget.args.title,
    );
  }

  void _attachListeners() {
    _tracksSub = _playerService.player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() {
        _audioTracks = tracks.audio.where((e) => e.id != 'auto' && e.id != 'no').toList();
        _subtitleTracks = tracks.subtitle.where((e) => e.id != 'auto' && e.id != 'no').toList();
      });
    });
    _trackSub = _playerService.player.stream.track.listen((track) {
      if (!mounted) return;
      setState(() {
        _selectedAudio = track.audio;
        _selectedSubtitle = track.subtitle;
      });
    });
    _videoParamsSub = _playerService.player.stream.videoParams.listen((event) {
      if (event.w != null && event.w! > 0) {
        PerformanceLogger.log(
          'player_open_start_to_first_frame',
          _openSw.elapsed,
          details: widget.args.title,
        );
        PerformanceLogger.log(
          widget.args.startAt == null ? 'play_to_first_frame' : 'resume_to_first_frame',
          _openSw.elapsed + widget.args.triggerElapsed,
          details: widget.args.title,
        );
        _videoParamsSub?.cancel();
      }
    });

    _positionSub = _playerService.player.stream.position.listen((_) async {
      final position = _playerService.player.state.position.inMilliseconds;
      final duration = _playerService.player.state.duration.inMilliseconds;
      if (duration <= 0 || position <= 0 || position % 5000 > 300) return;
      if (widget.args.type == PlaybackType.movie) {
        await WatchProgressService.saveMovieProgress(
          streamId: widget.args.contentId,
          positionMs: position,
          durationMs: duration,
          title: widget.args.title,
          poster: widget.args.poster,
        );
      } else {
        await WatchProgressService.saveEpisodeProgress(
          episodeId: widget.args.contentId,
          seriesId: widget.args.seriesId ?? 0,
          seriesName: widget.args.seriesName ?? '',
          episodeTitle: widget.args.title,
          episodeNumber: widget.args.episodeNumber ?? 0,
          seasonNumber: widget.args.seasonNumber ?? 0,
          positionMs: position,
          durationMs: duration,
        );
      }
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  @override
  void dispose() {
    unawaited(_stopPlaybackForClose());
    _hideTimer?.cancel();
    _tracksSub?.cancel();
    _trackSub?.cancel();
    _positionSub?.cancel();
    _videoParamsSub?.cancel();
    _seekResumeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _playerService.player;
    return WillPopScope(
      onWillPop: () async {
        await _stopPlaybackForClose();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) {
            if (!_overlayVisible) setState(() => _overlayVisible = true);
            _scheduleHide();
          },
          child: GestureDetector(
            onTap: () {
              setState(() => _overlayVisible = !_overlayVisible);
              _scheduleHide();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Video(controller: _playerService.videoController, fit: BoxFit.contain),
                ),
                if (_overlayVisible)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x99000000), Colors.transparent, Color(0xBB000000)],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(widget.args.title, style: const TextStyle(color: Colors.white)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () async {
                                  await _stopPlaybackForClose();
                                  if (mounted) {
                                    await Navigator.of(context).maybePop();
                                  }
                                },
                              ),
                            ),
                          const Spacer(),
                          StreamBuilder<Duration>(
                            stream: player.stream.position,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = player.state.duration;
                              final totalMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
                              final effectiveSliderValue = (_sliderDragValueMs ?? position.inMilliseconds.toDouble()).clamp(0.0, totalMs.toDouble());
                              return Column(
                                children: [
                                  Slider(
                                    value: effectiveSliderValue,
                                    min: 0,
                                    max: totalMs.toDouble(),
                                    onChangeStart: (value) {
                                      _sliderDragValueMs = value;
                                    },
                                    onChanged: (value) {
                                      setState(() => _sliderDragValueMs = value);
                                    },
                                    onChangeEnd: (value) async {
                                      setState(() => _sliderDragValueMs = null);
                                      await _seekTo(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Text('${_fmt(position)} / ${_fmt(duration)}', style: const TextStyle(color: Colors.white70)),
                                        const Spacer(),
                                        if (_subtitleTracks.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.subtitles, color: Colors.white),
                                            onPressed: _openSubtitleMenu,
                                          ),
                                        if (_audioTracks.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.audiotrack, color: Colors.white),
                                            onPressed: _openAudioMenu,
                                          ),
                                        PopupMenuButton<double>(
                                          tooltip: 'Subtitle Size',
                                          icon: const Icon(Icons.format_size, color: Colors.white),
                                          onSelected: (value) {},
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 0.8, child: Text('Small')),
                                            PopupMenuItem(value: 1.0, child: Text('Medium')),
                                            PopupMenuItem(value: 1.2, child: Text('Large')),
                                            PopupMenuItem(value: 1.4, child: Text('Extra Large')),
                                          ],
                                        ),
                                        IconButton(
                                          icon: Icon(player.state.playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                          onPressed: () => player.state.playing ? player.pause() : player.play(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          ],
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

  Future<void> _stopPlaybackForClose() async {
    if (_isStoppingForClose) return;
    _isStoppingForClose = true;
    try {
      await _playerService.player.stop();
    } finally {
      _isStoppingForClose = false;
    }
  }

  Future<void> _seekTo(Duration target) async {
    if (_seekInFlight) return;
    _seekInFlight = true;
    _pendingSeekTarget = target;
    _seekSw = Stopwatch()..start();
    PerformanceLogger.log('seek_requested', Duration.zero, details: '${widget.args.title} -> ${_fmt(target)}');
    await _playerService.player.seek(target);
    PerformanceLogger.log('seek_command_sent', _seekSw!.elapsed, details: widget.args.title);

    _seekResumeSub?.cancel();
    _seekResumeSub = _playerService.player.stream.position.listen((position) {
      final pending = _pendingSeekTarget;
      if (pending == null) return;
      final deltaMs = (position - pending).inMilliseconds.abs();
      if (deltaMs > 1500) return;

      final elapsed = _seekSw?.elapsed ?? Duration.zero;
      PerformanceLogger.log('playback_resumed_after_seek', elapsed, details: widget.args.title);
      PerformanceLogger.log('total_seek_latency', elapsed, details: widget.args.title);
      _pendingSeekTarget = null;
      _seekInFlight = false;
      _seekResumeSub?.cancel();
    });

    Future<void>.delayed(const Duration(seconds: 8), () {
      if (_pendingSeekTarget != null) {
        final elapsed = _seekSw?.elapsed ?? const Duration(seconds: 8);
        PerformanceLogger.log('seek_resume_timeout', elapsed, details: widget.args.title);
        _pendingSeekTarget = null;
        _seekInFlight = false;
        _seekResumeSub?.cancel();
      }
    });
  }

  Future<void> _openAudioMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView(
        children: _audioTracks
            .map((track) => ListTile(
                  title: Text(track.title ?? track.language ?? 'Audio ${track.id}'),
                  trailing: _selectedAudio?.id == track.id ? const Icon(Icons.check) : null,
                  onTap: () async {
                    await _playerService.player.setAudioTrack(track);
                    if (mounted) Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  Future<void> _openSubtitleMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView(
        children: [
          ListTile(
            title: const Text('Off'),
            onTap: () async {
              await _playerService.player.setSubtitleTrack(SubtitleTrack.no());
              if (mounted) Navigator.pop(context);
            },
          ),
          ..._subtitleTracks.map((track) => ListTile(
                title: Text(track.title ?? track.language ?? 'Subtitle ${track.id}'),
                trailing: _selectedSubtitle?.id == track.id ? const Icon(Icons.check) : null,
                onTap: () async {
                  await _playerService.player.setSubtitleTrack(track);
                  if (mounted) Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }
}
