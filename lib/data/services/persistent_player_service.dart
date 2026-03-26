import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PersistentPlayerService {
  PersistentPlayerService._();
  static final PersistentPlayerService instance = PersistentPlayerService._();

  final Player player = Player(
    configuration: const PlayerConfiguration(
      title: 'IPTV Playback',
      osc: false,
      logLevel: MPVLogLevel.warn,
      vo: 'gpu-next',
      bufferSize: 96 * 1024 * 1024,
      pitch: true,
      muted: false,
    ),
  );

  late final VideoController videoController = VideoController(
    player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: true,
    ),
  );

  String? _lastOpenedUrl;

  Future<void> openMedia(
    Media media, {
    required String sourceUrl,
    Duration? startAt,
  }) async {
    final requestedUrl = sourceUrl;
    final shouldReopen = _lastOpenedUrl != requestedUrl;

    if (shouldReopen) {
      await player.stop();
    }

    await player.open(media, play: true);
    if (startAt != null && startAt > Duration.zero) {
      await player.seek(startAt);
    }
    _lastOpenedUrl = requestedUrl;
  }
}
