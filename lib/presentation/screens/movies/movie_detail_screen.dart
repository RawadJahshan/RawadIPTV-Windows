import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/movie.dart';
import '../../../utils/favorites_manager.dart';

class MovieDetailScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final Movie movie;

  const MovieDetailScreen({
    super.key,
    required this.xtreamApi,
    required this.movie,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late final Player _player;
  late final VideoController _controller;

  bool _isBuffering = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isFavorite = false;
  String _resolution = '';
  String _fps = '';

  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  AudioTrack? _selectedAudio;
  SubtitleTrack? _selectedSubtitle;

  StreamSubscription? _bufferingSubscription;
  StreamSubscription? _videoParamsSubscription;
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _trackSubscription;
  StreamSubscription? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 128 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
        vo: 'gpu',
      ),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _setupListeners();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final fav = await FavoritesManager.isFavoriteMovie(
      widget.movie.id.toString(),
    );
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesManager.removeFavoriteMovie(
        widget.movie.id.toString(),
      );
    } else {
      await FavoritesManager.addFavoriteMovie(
        widget.movie.id.toString(),
      );
    }
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  void _setupListeners() {
    _bufferingSubscription =
        _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _videoParamsSubscription =
        _player.stream.videoParams.listen((params) {
      if (mounted && params.w != null && params.h != null) {
        setState(() {
          _resolution = '${params.w}x${params.h}';
          _hasError = false;
        });
      }
    });

    _tracksSubscription = _player.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() {
          _audioTracks = tracks.audio
              .where((t) => t.id != 'no' && t.id != 'auto')
              .toList();
          _subtitleTracks = tracks.subtitle
              .where((t) => t.id != 'no' && t.id != 'auto')
              .toList();
        });
        for (final track in tracks.video) {
          if (track.fps != null && track.fps! > 0) {
            if (mounted) {
              setState(() {
                _fps = '${track.fps!.toStringAsFixed(0)} FPS';
              });
            }
            break;
          }
        }
      }
    });

    _trackSubscription = _player.stream.track.listen((track) {
      if (mounted) {
        setState(() {
          _selectedAudio = track.audio;
          _selectedSubtitle = track.subtitle;
        });
      }
    });

    _errorSubscription = _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        setState(() {
          _hasError = true;
          _isBuffering = false;
        });
      }
    });
  }

  Future<void> _playMovie() async {
    setState(() {
      _isPlaying = true;
      _isBuffering = true;
      _hasError = false;
      _resolution = '';
      _fps = '';
      _audioTracks = [];
      _subtitleTracks = [];
    });

        await _player.open(
      Media(
        widget.movie.streamUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Connection': 'keep-alive',
        },
      ),
      play: true,
    );
  }

  void _showAudioDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text(
            'Audio Track',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 300,
            child: _audioTracks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No audio tracks available',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _audioTracks.length,
                    itemBuilder: (context, index) {
                      final track = _audioTracks[index];
                      final isSelected =
                          _selectedAudio?.id == track.id;
                      final label =
                          track.title?.isNotEmpty == true
                              ? track.title!
                              : track.language?.isNotEmpty == true
                                  ? track.language!
                                  : 'Track ${index + 1}';
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Colors.blue
                              : Colors.white54,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.blue
                                : Colors.white,
                          ),
                        ),
                        onTap: () {
                          _player.setAudioTrack(track);
                          setState(() => _selectedAudio = track);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubtitleDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text(
            'Subtitles',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _subtitleTracks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected =
                      _selectedSubtitle?.id == 'no' ||
                          _selectedSubtitle == null;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Colors.blue
                          : Colors.white54,
                    ),
                    title: Text(
                      'Off',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.blue
                            : Colors.white,
                      ),
                    ),
                    onTap: () {
                      _player.setSubtitleTrack(SubtitleTrack.no());
                      setState(() =>
                          _selectedSubtitle = SubtitleTrack.no());
                      Navigator.pop(context);
                    },
                  );
                }
                final track = _subtitleTracks[index - 1];
                final isSelected =
                    _selectedSubtitle?.id == track.id;
                final label = track.title?.isNotEmpty == true
                    ? track.title!
                    : track.language?.isNotEmpty == true
                        ? track.language!
                        : 'Subtitle $index';
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Colors.blue
                        : Colors.white54,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.blue
                          : Colors.white,
                    ),
                  ),
                  onTap: () {
                    _player.setSubtitleTrack(track);
                    setState(() => _selectedSubtitle = track);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bufferingSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    _tracksSubscription?.cancel();
    _trackSubscription?.cancel();
    _errorSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Widget _chip(IconData icon, String label,
      {Color color = Colors.white70}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(widget.movie.name),
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            tooltip: 'Favorite',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Movie info 30%
          Container(
            width: size.width * 0.3,
            color: const Color(0xFF0F0F1A),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.movie.logoUrl.isNotEmpty
                        ? Image.network(
                            widget.movie.logoUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: const Color(0xFF1A1A2E),
                              child: const Center(
                                child: Icon(
                                  Icons.movie,
                                  color: Colors.white24,
                                  size: 60,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 200,
                            color: const Color(0xFF1A1A2E),
                            child: const Center(
                              child: Icon(
                                Icons.movie,
                                color: Colors.white24,
                                size: 60,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.movie.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.movie.year.isNotEmpty)
                        _chip(Icons.calendar_today, widget.movie.year),
                      if (widget.movie.rating.isNotEmpty &&
                          widget.movie.rating != '0')
                        _chip(
                          Icons.star,
                          widget.movie.rating,
                          color: Colors.amber,
                        ),
                      if (widget.movie.duration.isNotEmpty)
                        _chip(Icons.timer, widget.movie.duration),
                      if (_resolution.isNotEmpty)
                        _chip(Icons.hd, _resolution),
                      if (_fps.isNotEmpty)
                        _chip(Icons.speed, _fps),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.movie.genre.isNotEmpty) ...[
                    Text(
                      widget.movie.genre,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.movie.plot.isNotEmpty) ...[
                    const Text(
                      'Plot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.movie.plot,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.movie.director.isNotEmpty) ...[
                    const Text(
                      'Director',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.movie.director,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.movie.cast.isNotEmpty) ...[
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.movie.cast,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Right: Video player 70%
          Expanded(
            child: Column(
              children: [
                // Video area
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        if (_isPlaying)
                          SizedBox.expand(
                            child: Video(
                              controller: _controller,
                              fit: BoxFit.contain,
                            ),
                          ),

                        // Play button
                        if (!_isPlaying)
                          Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                if (widget.movie.logoUrl.isNotEmpty)
                                  Opacity(
                                    opacity: 0.3,
                                    child: Image.network(
                                      widget.movie.logoUrl,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _playMovie,
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    size: 28,
                                  ),
                                  label: const Text(
                                    'Play Movie',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Buffering
                        if (_isBuffering && _isPlaying)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // Error
                        if (_hasError)
                          Container(
                            color: Colors.black87,
                            child: Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Failed to load movie',
                                    style: TextStyle(
                                        color: Colors.white70),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _playMovie,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Resolution overlay
                        if (_resolution.isNotEmpty || _fps.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  if (_resolution.isNotEmpty)
                                    Text(
                                      _resolution,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (_fps.isNotEmpty)
                                    Text(
                                      _fps,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
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

                // Controls
                if (_isPlaying)
                  Container(
                    color: const Color(0xFF0F0F1A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        // Progress bar
                        StreamBuilder<Duration>(
                          stream: _player.stream.position,
                          builder: (context, snapshot) {
                            final position =
                                snapshot.data ?? Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: _player.stream.duration,
                              builder: (context, durationSnapshot) {
                                final duration =
                                    durationSnapshot.data ??
                                        Duration.zero;
                                final progress =
                                    duration.inMilliseconds > 0
                                        ? position.inMilliseconds /
                                            duration.inMilliseconds
                                        : 0.0;
                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context)
                                          .copyWith(
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        trackHeight: 3,
                                      ),
                                      child: Slider(
                                        value:
                                            progress.clamp(0.0, 1.0),
                                        onChanged: (value) {
                                          final newPos = Duration(
                                            milliseconds: (value *
                                                    duration
                                                        .inMilliseconds)
                                                .toInt(),
                                          );
                                          _player.seek(newPos);
                                        },
                                        activeColor: Colors.blue,
                                        inactiveColor: Colors.white24,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),

                        // Buttons row
                        Row(
                          children: [
                            // Play/Pause
                            StreamBuilder<bool>(
                              stream: _player.stream.playing,
                              builder: (context, snapshot) {
                                final isPlaying =
                                    snapshot.data ?? false;
                                return IconButton(
                                  onPressed: () =>
                                      _player.playOrPause(),
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),

                            // Stop
                            IconButton(
                              onPressed: () {
                                _player.stop();
                                setState(() {
                                  _isPlaying = false;
                                  _resolution = '';
                                  _fps = '';
                                  _audioTracks = [];
                                  _subtitleTracks = [];
                                });
                              },
                              icon: const Icon(
                                Icons.stop,
                                color: Colors.white,
                              ),
                            ),

                            // Replay 10s
                            IconButton(
                              onPressed: () async {
                                final pos = _player.state.position;
                                final newPos = Duration(
                                  seconds: (pos.inSeconds - 10)
                                      .clamp(0, 999999),
                                );
                                await _player.seek(newPos);
                              },
                              icon: const Icon(
                                Icons.replay_10,
                                color: Colors.white,
                              ),
                            ),

                            // Forward 10s
                            IconButton(
                              onPressed: () async {
                                final pos = _player.state.position;
                                final dur = _player.state.duration;
                                final newPos = Duration(
                                  seconds: (pos.inSeconds + 10)
                                      .clamp(0, dur.inSeconds),
                                );
                                await _player.seek(newPos);
                              },
                              icon: const Icon(
                                Icons.forward_10,
                                color: Colors.white,
                              ),
                            ),

                            // Forward 30s
                            IconButton(
                              onPressed: () async {
                                final pos = _player.state.position;
                                final dur = _player.state.duration;
                                final newPos = Duration(
                                  seconds: (pos.inSeconds + 30)
                                      .clamp(0, dur.inSeconds),
                                );
                                await _player.seek(newPos);
                              },
                              icon: const Icon(
                                Icons.forward_30,
                                color: Colors.white,
                              ),
                            ),

                            const Spacer(),

                            // Audio track
                            IconButton(
                              onPressed: _showAudioDialog,
                              icon: Icon(
                                Icons.audiotrack,
                                color: _audioTracks.isEmpty
                                    ? Colors.white24
                                    : Colors.white,
                              ),
                                                            tooltip: 'Audio Track',
                            ),

                            // Subtitles
                            IconButton(
                              onPressed: _showSubtitleDialog,
                              icon: Icon(
                                Icons.subtitles,
                                color: _selectedSubtitle != null &&
                                        _selectedSubtitle?.id != 'no'
                                    ? Colors.blue
                                    : Colors.white,
                              ),
                              tooltip: 'Subtitles',
                            ),

                            // Volume
                            StreamBuilder<double>(
                              stream: _player.stream.volume,
                              builder: (context, snapshot) {
                                final volume = snapshot.data ?? 100.0;
                                return Row(
                                  children: [
                                    Icon(
                                      volume == 0
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Slider(
                                        value: volume,
                                        min: 0,
                                        max: 100,
                                        onChanged: (value) {
                                          _player.setVolume(value);
                                        },
                                        activeColor: Colors.blue,
                                        inactiveColor: Colors.white24,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}