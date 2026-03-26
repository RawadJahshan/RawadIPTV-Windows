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
  int _operationSeq = 0;
  int _stopGeneration = 0;

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
        final operationId = ++_operationSeq;
        debugPrint('[PersistentPlayerService] [op:$operationId] next media open requested: $requestedUrl');

        _state = PlayerLifecycleState.opening;
        debugPrint('[PersistentPlayerService] [op:$operationId] next media open started: $requestedUrl');

        try {
          await player.open(media, play: true).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('[PersistentPlayerService] [op:$operationId] player.open timeout for $requestedUrl');
              throw TimeoutException('Timed out while opening media');
            },
          );

          if (startAt != null && startAt > Duration.zero) {
            await _seekWithRecovery(startAt, operationId: operationId, sourceUrl: requestedUrl);
          }

          final playbackStateAfterOpen = player.state.playing;
          debugPrint(
            '[PersistentPlayerService] [op:$operationId] playback state after open: '
            'playing=$playbackStateAfterOpen position=${player.state.position}',
          );
          if (!playbackStateAfterOpen) {
            debugPrint('[PersistentPlayerService] [op:$operationId] player.play invoked after open');
            await player.play();
          }

          _lastOpenedUrl = requestedUrl;
          _state = PlayerLifecycleState.playing;
          debugPrint('[PersistentPlayerService] [op:$operationId] next media open completed: $requestedUrl');
        } catch (error) {
          _state = PlayerLifecycleState.idle;
          debugPrint('[PersistentPlayerService] [op:$operationId] next media open failed: $requestedUrl -> $error');
          rethrow;
        }
      },
    );
  }

  Future<void> stopAndResetForClose() {
    return _runExclusive<void>(
      operationName: 'close',
      operation: () async {
        final operationId = ++_operationSeq;
        final stopGeneration = ++_stopGeneration;
        debugPrint('[PersistentPlayerService] [op:$operationId] player close requested');
        _state = PlayerLifecycleState.stopping;

        try {
          await player.pause();
        } catch (error) {
          debugPrint('[PersistentPlayerService] [op:$operationId] player pause before stop failed: $error');
        }

        debugPrint('[PersistentPlayerService] [op:$operationId] player stop started');
        await player.stop().timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            debugPrint('[PersistentPlayerService] [op:$operationId] player stop timeout; continuing reset');
          },
        );
        debugPrint('[PersistentPlayerService] [op:$operationId] player stop completed');

        // If stop races with a new open queued right after close, avoid stale stop completion
        // overriding the freshly opened session identity.
        if (stopGeneration != _stopGeneration) {
          debugPrint('[PersistentPlayerService] [op:$operationId] stale stop completion ignored');
          return;
        }

        _lastOpenedUrl = null;
        _state = PlayerLifecycleState.idle;
        debugPrint('[PersistentPlayerService] [op:$operationId] player cleanup/reset completed');
      },
    );
  }

  Future<void> clearSessionCache() async {
    _lastOpenedUrl = null;
    await stopAndResetForClose();
  }

  Future<void> _seekWithRecovery(
    Duration target, {
    required int operationId,
    required String sourceUrl,
  }) async {
    const toleranceMs = 1500;
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await player.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final current = player.state.position;
      final deltaMs = (current - target).inMilliseconds.abs();
      if (deltaMs <= toleranceMs || current >= target) {
        debugPrint('[PersistentPlayerService] [op:$operationId] startAt seek converged on attempt $attempt');
        return;
      }
      debugPrint(
        '[PersistentPlayerService] [op:$operationId] startAt seek drift detected '
        '(attempt $attempt/$maxAttempts, target=$target current=$current) for $sourceUrl',
      );
    }
  }
}
