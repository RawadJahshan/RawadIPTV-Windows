import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class TrackInfo {
  final int index;
  final String type;
  final String name;
  final String codec;

  TrackInfo({
    required this.index,
    required this.type,
    required this.name,
    required this.codec,
  });
}

class TrackInfoService {
  static String _getFfprobePath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    // In debug mode look in build output
    final candidates = [
      '$exeDir\\ffprobe.exe',
      '$exeDir\\data\\flutter_assets\\ffprobe.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return 'ffprobe'; // fallback to PATH
  }

  static Future<List<TrackInfo>> getTracksForUrl(String url) async {
    try {
      final ffprobe = _getFfprobePath();
      debugPrint('[TrackInfoService] using ffprobe: $ffprobe');

      final result = await Process.run(
        ffprobe,
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_streams',
          '-user_agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          url,
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 15));

      if (result.exitCode != 0) {
        debugPrint('[TrackInfoService] ffprobe error: ${result.stderr}');
        return [];
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final streams = json['streams'] as List? ?? [];

      final tracks = <TrackInfo>[];
      var audioIndex = 0;
      var subIndex = 0;

      for (final stream in streams) {
        final s = stream as Map<String, dynamic>;
        final codecType = s['codec_type']?.toString() ?? '';
        final codec = s['codec_name']?.toString() ?? '';
        final tags = s['tags'] as Map? ?? {};

        final language = tags['language']?.toString() ?? '';
        final title = tags['title']?.toString() ?? '';

        var name = title.isNotEmpty
            ? title
            : language.isNotEmpty
            ? language.toUpperCase()
            : '';

        if (codecType == 'audio') {
          if (name.isEmpty) name = 'Audio ${audioIndex + 1}';
          tracks.add(
            TrackInfo(
              index: audioIndex,
              type: 'audio',
              name: name,
              codec: codec,
            ),
          );
          audioIndex++;
        } else if (codecType == 'subtitle') {
          if (name.isEmpty) name = 'Subtitle ${subIndex + 1}';
          tracks.add(
            TrackInfo(
              index: subIndex,
              type: 'subtitle',
              name: name,
              codec: codec,
            ),
          );
          subIndex++;
        }
      }

      debugPrint(
        '[TrackInfoService] found '
        '${tracks.where((t) => t.type == "audio").length} audio, '
        '${tracks.where((t) => t.type == "subtitle").length} subtitle tracks',
      );
      return tracks;
    } catch (e) {
      debugPrint('[TrackInfoService] error: $e');
      return [];
    }
  }
}
