import 'dart:convert';
import 'dart:io';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/foundation.dart';

class VlcSubtitleTrack {
  const VlcSubtitleTrack({
    required this.id,
    required this.label,
    this.language,
    this.isEmbedded = true,
  });

  final int id;
  final String label;
  final String? language;
  final bool isEmbedded;
}

class VlcRuntimeCheckResult {
  const VlcRuntimeCheckResult({
    required this.hasLibVlc,
    required this.hasLibVlcCore,
    required this.hasPluginsFolder,
    required this.checkedDirectory,
  });

  final bool hasLibVlc;
  final bool hasLibVlcCore;
  final bool hasPluginsFolder;
  final String checkedDirectory;

  bool get isComplete => hasLibVlc && hasLibVlcCore && hasPluginsFolder;
}

class VlcSubtitleSupport {
  static const int disabledTrackId = -1;

  static int? getCurrentSubtitleTrack(Player player) {
    final dynamic p = player;
    for (final getter in [
      () => p.subtitleTrack,
      () => p.spuTrack,
      () => p.currentSubtitleTrack,
    ]) {
      try {
        final value = getter();
        if (value is int) return value;
      } catch (_) {
        // Ignore missing API.
      }
    }
    return null;
  }

  static Future<bool> setSubtitleTrack(Player player, int id) async {
    final dynamic p = player;
    for (final setter in [
      (int value) => p.setSubtitleTrack(value),
      (int value) => p.setSpuTrack(value),
      (int value) => p.setSPUTrack(value),
    ]) {
      try {
        setter(id);
        return true;
      } catch (_) {
        // Try next possible method name.
      }
    }
    return false;
  }

  static int? getSubtitleTrackCount(Player player) {
    final dynamic p = player;
    for (final getter in [
      () => p.subtitleTrackCount,
      () => p.spuTrackCount,
      () => p.subtitleCount,
    ]) {
      try {
        final value = getter();
        if (value is int) return value;
      } catch (_) {
        // Ignore missing API.
      }
    }
    return null;
  }

  static Future<List<VlcSubtitleTrack>> getEmbeddedSubtitleTracks(
    Player player,
  ) async {
    final count = getSubtitleTrackCount(player);
    if (count == null || count <= 0) return const [];

    return List.generate(
      count,
      (index) => VlcSubtitleTrack(
        id: index,
        label: 'Subtitle Track ${index + 1}',
      ),
    );
  }

  static Future<List<VlcSubtitleTrack>> inspectEmbeddedTracksWithFfprobe(
    String source,
  ) async {
    try {
      final result = await Process.run(
        'ffprobe',
        [
          '-v',
          'error',
          '-select_streams',
          's',
          '-show_entries',
          'stream=index:stream_tags=language,title',
          '-of',
          'json',
          source,
        ],
      );

      if (result.exitCode != 0) return const [];
      final decoded = jsonDecode(result.stdout as String);
      final streams = (decoded['streams'] as List?) ?? const [];
      return streams.map<VlcSubtitleTrack>((stream) {
        final index = stream['index'] as int? ?? 0;
        final tags = (stream['tags'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final language = tags['language']?.toString();
        final title = tags['title']?.toString();
        final buffer = StringBuffer('Subtitle #$index');
        if (language != null && language.isNotEmpty) {
          buffer.write(' ($language)');
        }
        if (title != null && title.isNotEmpty) {
          buffer.write(' - $title');
        }
        return VlcSubtitleTrack(
          id: index,
          label: buffer.toString(),
          language: language,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static VlcRuntimeCheckResult verifyWindowsRuntime({
    String? executableDirectory,
  }) {
    if (!Platform.isWindows) {
      return const VlcRuntimeCheckResult(
        hasLibVlc: true,
        hasLibVlcCore: true,
        hasPluginsFolder: true,
        checkedDirectory: 'non-windows',
      );
    }

    final dir = Directory(
      executableDirectory ?? File(Platform.resolvedExecutable).parent.path,
    );
    final libVlc = File('${dir.path}${Platform.pathSeparator}libvlc.dll');
    final libVlcCore =
        File('${dir.path}${Platform.pathSeparator}libvlccore.dll');
    final plugins = Directory('${dir.path}${Platform.pathSeparator}plugins');

    return VlcRuntimeCheckResult(
      hasLibVlc: libVlc.existsSync(),
      hasLibVlcCore: libVlcCore.existsSync(),
      hasPluginsFolder: plugins.existsSync(),
      checkedDirectory: dir.path,
    );
  }

  static void logRuntimeCheck() {
    final check = verifyWindowsRuntime();
    debugPrint(
      '[VLC Runtime] path=${check.checkedDirectory} libvlc=${check.hasLibVlc} '
      'libvlccore=${check.hasLibVlcCore} plugins=${check.hasPluginsFolder}',
    );
  }
}
