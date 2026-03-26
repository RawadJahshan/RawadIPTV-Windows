import 'dart:async';

import 'package:flutter/foundation.dart';
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
  Future<void> _lifecycleOp = Future<void>.value();

  Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _lifecycleOp = _lifecycleOp.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> openMedia(
    Media media, {
    required String sourceUrl,
    Duration? startAt,
  }) {
    return _runExclusive(() async {
      final requestedUrl = sourceUrl;
      debugPrint('[PersistentPlayerService] next media open requested: $requestedUrl');

      final shouldReopen = _lastOpenedUrl != requestedUrl;
      if (shouldReopen) {
        debugPrint('[PersistentPlayerService] player stop started (before open)');
        await player.stop();
        debugPrint('[PersistentPlayerService] player stop completed (before open)');
      }

      try {
        await player.open(media, play: true);
        if (startAt != null && startAt > Duration.zero) {
          await player.seek(startAt);
        }
        _lastOpenedUrl = requestedUrl;
        debugPrint('[PersistentPlayerService] next media open completed: $requestedUrl');
      } catch (error) {
        debugPrint('[PersistentPlayerService] next media open failed: $requestedUrl -> $error');
        rethrow;
      }
    });
  }

  Future<void> stopAndResetForClose() {
    return _runExclusive(() async {
      debugPrint('[PersistentPlayerService] player close requested');
      debugPrint('[PersistentPlayerService] player stop started');
      await player.stop();
      debugPrint('[PersistentPlayerService] player stop completed');
      _lastOpenedUrl = null;
      debugPrint('[PersistentPlayerService] player cleanup/reset completed');
    });
  }
}
