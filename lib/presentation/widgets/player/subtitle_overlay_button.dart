import 'package:flutter/material.dart';

class PlayerSubtitleTrackItem {
  final int id;
  final String name;

  const PlayerSubtitleTrackItem({
    required this.id,
    required this.name,
  });
}

class PlayerSubtitleOverlayButton extends StatefulWidget {
  final List<PlayerSubtitleTrackItem> tracks;
  final int? selectedTrackId;
  final Future<void> Function(int trackId) onSelectTrack;
  final Future<void> Function() onDisableTrack;
  final bool visible;
  final bool enabled;
  final bool hideWhenNoTracks;

  const PlayerSubtitleOverlayButton({
    super.key,
    required this.tracks,
    required this.selectedTrackId,
    required this.onSelectTrack,
    required this.onDisableTrack,
    this.visible = true,
    this.enabled = true,
    this.hideWhenNoTracks = true,
  });

  @override
  State<PlayerSubtitleOverlayButton> createState() =>
      _PlayerSubtitleOverlayButtonState();
}

class _PlayerSubtitleOverlayButtonState extends State<PlayerSubtitleOverlayButton> {
  bool _isApplying = false;

  String? get _selectedTrackName {
    final match = widget.tracks.where((t) => t.id == widget.selectedTrackId);
    if (match.isEmpty) return null;
    return match.first.name;
  }

  Future<void> _onSelected(int? trackId) async {
    if (_isApplying) return;

    setState(() => _isApplying = true);
    try {
      if (trackId == null) {
        await widget.onDisableTrack();
      } else {
        await widget.onSelectTrack(trackId);
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final hasTracks = widget.tracks.isNotEmpty;
    if (!hasTracks && widget.hideWhenNoTracks) {
      return const SizedBox.shrink();
    }

    final tooltipLabel = _selectedTrackName == null
        ? 'Subtitles: Off'
        : 'Subtitles: $_selectedTrackName';

    return PopupMenuButton<int?>(
      tooltip: tooltipLabel,
      enabled: widget.enabled && hasTracks && !_isApplying,
      icon: const Icon(
        Icons.closed_caption,
        color: Colors.white,
      ),
      onSelected: _onSelected,
      itemBuilder: (_) => [
        PopupMenuItem<int?>(
          value: null,
          child: Row(
            children: [
              if (widget.selectedTrackId == null)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check, size: 16),
                ),
              const Text('Off'),
            ],
          ),
        ),
        ...widget.tracks.map(
          (track) => PopupMenuItem<int?>(
            value: track.id,
            child: Row(
              children: [
                if (widget.selectedTrackId == track.id)
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
