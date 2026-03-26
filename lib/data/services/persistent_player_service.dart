import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

enum PlayerLifecycleState { idle, opening, playing, stopping }

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
  PlayerLifecycleState _state = PlayerLifecycleState.idle;
  Future<void> _lifecycleOp = Future<void>.value();

  Future<T> _runExclusive<T>({
    required String operationName,
    required Future<T> Function() operation,
  }) {
    final completer = Completer<T>();
    final queuedBecauseStopping = operationName == 'open' && _state == PlayerLifecycleState.stopping;
    if (queuedBecauseStopping) {
      debugPrint('[PersistentPlayerService] next open queued because stop/reset is still in progress');
    }

    _lifecycleOp = _lifecycleOp
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[PersistentPlayerService] previous lifecycle operation failed: $error');
        })
        .then((_) async {
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
    return _runExclusive<void>(
      operationName: 'open',
      operation: () async {
        final requestedUrl = sourceUrl;
        debugPrint('[PersistentPlayerService] next media open requested: $requestedUrl');

        _state = PlayerLifecycleState.opening;
        debugPrint('[PersistentPlayerService] next media open started: $requestedUrl');

        debugPrint('[PersistentPlayerService] player stop started (before open)');
        await player.stop();
        debugPrint('[PersistentPlayerService] player stop completed (before open)');

        try {
          await player.open(media, play: true);
          if (startAt != null && startAt > Duration.zero) {
            await player.seek(startAt);
          }
          _lastOpenedUrl = requestedUrl;
          _state = PlayerLifecycleState.playing;
          debugPrint('[PersistentPlayerService] next media open completed: $requestedUrl');
        } catch (error) {
          _state = PlayerLifecycleState.idle;
          debugPrint('[PersistentPlayerService] next media open failed: $requestedUrl -> $error');
          rethrow;
        }
      },
    );
  }

  Future<void> stopAndResetForClose() {
    return _runExclusive<void>(
      operationName: 'close',
      operation: () async {
        debugPrint('[PersistentPlayerService] player close requested');
        _state = PlayerLifecycleState.stopping;

        debugPrint('[PersistentPlayerService] player stop started');
        await player.stop();
        debugPrint('[PersistentPlayerService] player stop completed');

        _lastOpenedUrl = null;
        _state = PlayerLifecycleState.idle;
        debugPrint('[PersistentPlayerService] player cleanup/reset completed');
      },
    );
  }
}
