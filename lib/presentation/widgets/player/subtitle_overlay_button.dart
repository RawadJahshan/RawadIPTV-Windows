import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';

class SubtitleOverlayButton extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final int? selectedTrackId;
  final Future<void> Function(int trackId) onSelectTrack;
  final Future<void> Function() onDisable;
  final bool visible;
  final bool hideWhenEmpty;

  const SubtitleOverlayButton({
    super.key,
    required this.tracks,
    required this.selectedTrackId,
    required this.onSelectTrack,
    required this.onDisable,
    this.visible = true,
    this.hideWhenEmpty = true,
  });

  String get _selectedTrackName {
    if (selectedTrackId == null) return 'Off';

    final matchedTrack = tracks.where((track) => track.id == selectedTrackId);
    if (matchedTrack.isEmpty) return 'Off';

    return matchedTrack.first.name;
  }

  @override
  Widget build(BuildContext context) {
    if (!visible || (hideWhenEmpty && tracks.isEmpty)) {
      return const SizedBox.shrink();
    }

    final canOpenMenu = tracks.isNotEmpty;

    return PopupMenuButton<int?>(
      tooltip: 'Subtitles: $_selectedTrackName',
      enabled: canOpenMenu,
      icon: Icon(
        Icons.closed_caption,
        color: canOpenMenu ? Colors.white : Colors.white54,
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
                    track.name,
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
