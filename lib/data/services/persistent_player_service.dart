import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PersistentPlayerService {
  PersistentPlayerService._();
  static final PersistentPlayerService instance = PersistentPlayerService._();

  final Player player = Player(
    configuration: const PlayerConfiguration(
      title: 'IPTV Playback',
      osc: false,
      ready: true,
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

  Future<void> openMedia(Media media, {Duration? startAt}) async {
    await player.stop();
    await player.open(media, play: true);
    if (startAt != null && startAt > Duration.zero) {
      await player.seek(startAt);
    }
  }
}
