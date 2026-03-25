import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/series.dart';
import '../../../data/models/episode.dart';
import '../../../utils/favorites_manager.dart';

class SeriesDetailScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  final Series series;

  const SeriesDetailScreen({
    super.key,
    required this.xtreamApi,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late Future<Map<String, List<Episode>>> _futureEpisodes;
  late final Player _player;
  late final VideoController _controller;

  bool _isBuffering = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isFavorite = false;
  String _resolution = '';
  String _fps = '';
  Episode? _currentEpisode;
  int _selectedSeason = 1;

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
    _futureEpisodes = _fetchEpisodes();
  }

  Future<void> _loadFavorite() async {
    final fav = await FavoritesManager.isFavoriteSeries(
      widget.series.id.toString(),
    );
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesManager.removeFavoriteSeries(
        widget.series.id.toString(),
      );
    } else {
      await FavoritesManager.addFavoriteSeries(
        widget.series.id.toString(),
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

  Future<Map<String, List<Episode>>> _fetchEpisodes() async {
    try {
      final info =
          await widget.xtreamApi.getSeriesInfo(widget.series.id);
      final rawEpisodes = info['episodes'];
      if (rawEpisodes == null) return {};

      final Map<String, dynamic> episodes =
          rawEpisodes is Map<String, dynamic>
              ? rawEpisodes
              : Map<String, dynamic>.from(rawEpisodes as Map);

      final Map<String, List<Episode>> seasonEpisodes = {};

      episodes.forEach((season, episodeList) {
        if (episodeList is List) {
          final List<Episode> eps = [];
          for (final e in episodeList) {
            try {
              eps.add(Episode.fromJson(
                Map<String, dynamic>.from(e as Map),
                widget.xtreamApi.serverUrl,
                widget.xtreamApi.username,
                widget.xtreamApi.password,
              ));
            } catch (err) {
              debugPrint('Episode parse error: $err');
            }
          }
          if (eps.isNotEmpty) {
            seasonEpisodes[season] = eps;
          }
        }
      });

      if (seasonEpisodes.isNotEmpty) {
        final firstKey = seasonEpisodes.keys.first;
        setState(() {
          _selectedSeason = int.tryParse(firstKey) ?? 1;
        });
      }

      return seasonEpisodes;
    } catch (e) {
      debugPrint('Series info error: $e');
      return {};
    }
  }

  Future<void> _playEpisode(Episode episode) async {
    setState(() {
      _currentEpisode = episode;
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
        episode.streamUrl,
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
    @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(widget.series.name),
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
      body: FutureBuilder<Map<String, List<Episode>>>(
        future: _futureEpisodes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No episodes found'));
          }

          final seasonEpisodes = snapshot.data!;
          final seasons = seasonEpisodes.keys.toList()
            ..sort((a, b) => (int.tryParse(a) ?? 0)
                .compareTo(int.tryParse(b) ?? 0));
          final currentEpisodes =
              seasonEpisodes[_selectedSeason.toString()] ?? [];

          return Row(
            children: [
              // Left: Info + Episodes 30%
              Container(
                width: size.width * 0.3,
                color: const Color(0xFF0F0F1A),
                child: Column(
                  children: [
                    // Series info
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: widget.series.logoUrl.isNotEmpty
                                ? Image.network(
                                    widget.series.logoUrl,
                                    width: 60,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                      width: 60,
                                      height: 80,
                                      color: const Color(0xFF1A1A2E),
                                      child: const Icon(
                                        Icons.video_library,
                                        color: Colors.white24,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 60,
                                    height: 80,
                                    color: const Color(0xFF1A1A2E),
                                    child: const Icon(
                                      Icons.video_library,
                                      color: Colors.white24,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.series.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (widget.series.year.isNotEmpty)
                                  Text(
                                    widget.series.year,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (widget.series.rating.isNotEmpty &&
                                    widget.series.rating != '0')
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.series.rating,
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Season tabs
                    Container(
                      height: 40,
                      color: const Color(0xFF07070F),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8),
                        itemCount: seasons.length,
                        itemBuilder: (context, index) {
                          final season = seasons[index];
                          final isSelected =
                              _selectedSeason.toString() == season;
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _selectedSeason =
                                    int.tryParse(season) ?? 1),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue
                                    : const Color(0xFF1A1A2E),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'S$season',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Episodes list
                    Expanded(
                      child: ListView.builder(
                        itemCount: currentEpisodes.length,
                        itemBuilder: (context, index) {
                          final episode = currentEpisodes[index];
                          final isSelected =
                              _currentEpisode?.id == episode.id;
                          return Material(
                            color: isSelected
                                ? const Color(0xFF1A3A5C)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => _playEpisode(episode),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue
                                            : const Color(0xFF1A1A2E),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${episode.episodeNum}',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white54,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            episode.title,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          if (episode
                                              .duration.isNotEmpty)
                                            Text(
                                              episode.duration,
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.play_arrow,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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

                            // No episode selected
                            if (!_isPlaying)
                              Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    if (widget.series.logoUrl
                                        .isNotEmpty)
                                      Opacity(
                                        opacity: 0.3,
                                        child: Image.network(
                                          widget.series.logoUrl,
                                          height: 150,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Select an episode to play',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 16,
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
                                        'Failed to load episode',
                                        style: TextStyle(
                                            color: Colors.white70),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (_currentEpisode !=
                                              null) {
                                            _playEpisode(
                                                _currentEpisode!);
                                          }
                                        },
                                        icon: const Icon(
                                            Icons.refresh),
                                        label: const Text('Retry'),
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Resolution overlay
                            if (_resolution.isNotEmpty ||
                                _fps.isNotEmpty)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withOpacity(0.7),
                                    borderRadius:
                                        BorderRadius.circular(6),
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
                    if (_currentEpisode != null)
                      Container(
                        color: const Color(0xFF0F0F1A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            // Episode title
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'S${_currentEpisode!.season} E${_currentEpisode!.episodeNum} - ${_currentEpisode!.title}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

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
                                          child: Slider(                                            value: progress.clamp(
                                                0.0, 1.0),
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
                                            inactiveColor:
                                                Colors.white24,
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
                                                _formatDuration(
                                                    position),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Text(
                                                _formatDuration(
                                                    duration),
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
                                    final pos =
                                        _player.state.position;
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
                                    final pos =
                                        _player.state.position;
                                    final dur =
                                        _player.state.duration;
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
                                    final pos =
                                        _player.state.position;
                                    final dur =
                                        _player.state.duration;
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
                                            _selectedSubtitle?.id !=
                                                'no'
                                        ? Colors.blue
                                        : Colors.white,
                                  ),
                                  tooltip: 'Subtitles',
                                ),

                                // Volume
                                StreamBuilder<double>(
                                  stream: _player.stream.volume,
                                  builder: (context, snapshot) {
                                    final volume =
                                        snapshot.data ?? 100.0;
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
                                            inactiveColor:
                                                Colors.white24,
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
          );
        },
      ),
    );
  }
}
                                            