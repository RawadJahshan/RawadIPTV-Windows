import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';

class SubtitleOverlayButton extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final int? selectedTrackId;
  final Future<void> Function(int trackId) onSelectTrack;
  final Future<void> Function() onDisable;
  final bool visible;

  const SubtitleOverlayButton({
    super.key,
    required this.tracks,
    required this.selectedTrackId,
    required this.onSelectTrack,
    required this.onDisable,
    this.visible = true,
  });

  String get _selectedTrackName {
    if (selectedTrackId == null) return 'Off';

    final matchedTrack = tracks.where((track) => track.id == selectedTrackId);
    if (matchedTrack.isEmpty) return 'Off';

    return matchedTrack.first.name;
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final hasTracks = tracks.isNotEmpty;

    return PopupMenuButton<int?>(
      tooltip: 'Subtitles: $_selectedTrackName',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(hasTracks ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasTracks ? Colors.white54 : Colors.white38,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.closed_caption,
              size: 18,
              color: hasTracks ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              'CC',
              style: TextStyle(
                color: hasTracks ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onSelected: (trackId) async {
        if (trackId == null) {
          await onDisable();
          return;
        }

        await onSelectTrack(trackId);
      },
      itemBuilder: (_) => [
        PopupMenuItem<int?>(
          value: null,
          child: Row(
            children: [
              if (selectedTrackId == null)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check, size: 16),
                ),
              const Text('Off'),
            ],
          ),
        ),
        if (!hasTracks)
          const PopupMenuItem<int?>(
            enabled: false,
            child: Text('No subtitles available'),
          ),
        ...tracks.map(
          (track) => PopupMenuItem<int?>(
            value: track.id,
            child: Row(
              children: [
                if (selectedTrackId == track.id)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check, size: 16),
                  ),
                Expanded(
                  child: Text(
                    track.name.trim().isEmpty
                        ? 'Subtitle ${track.id}'
                        : track.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
