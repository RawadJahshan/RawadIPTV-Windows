import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';

class TrackInfo {
  final int index;
  final String type; // 'audio' or 'subtitle'
  final String name; // language or title
  final String codec;

  TrackInfo({
    required this.index,
    required this.type,
    required this.name,
    required this.codec,
  });
}

class TrackInfoService {
  static Future<List<TrackInfo>> getTracksForUrl(String url) async {
    try {
      final session = await FFprobeKit.getMediaInformation(url);
      final info = session.getMediaInformation();
      if (info == null) return [];

      final streams = info.getStreams();
      if (streams == null) return [];

      final tracks = <TrackInfo>[];
      var audioIndex = 0;
      var subIndex = 0;

      for (final stream in streams) {
        final props = stream.getAllProperties();
        if (props == null) continue;

        final codecType = props['codec_type']?.toString() ?? '';
        final codec = props['codec_name']?.toString() ?? '';
        final tags = props['tags'] as Map<dynamic, dynamic>?;

        final language = tags?['language']?.toString() ?? '';
        final title = tags?['title']?.toString() ?? '';

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

      return tracks;
    } catch (e) {
      debugPrint('[TrackInfoService] error: $e');
      return [];
    }
  }
}
