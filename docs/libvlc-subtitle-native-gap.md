# libVLC Embedded Subtitle Support: Native Gap Report

This repository currently cannot implement real embedded subtitle switching end-to-end
from Flutter alone because the Windows libVLC bridge is provided by the external
`dart_vlc` plugin source, not by tracked files in this app repo.

## Verified current state

- The app initializes `dart_vlc` in `lib/main.dart`.
- The Windows bridge is registered from generated Flutter plugin registrant files.
- The actual plugin implementation is expected at build time under:
  - `windows/flutter/ephemeral/.plugin_symlinks/dart_vlc/windows/...`
  - `windows/flutter/ephemeral/.plugin_symlinks/dart_vlc/lib/...`
- Those plugin source files are not present in this repository.

## Why this blocks real subtitle switching

Real embedded subtitle/CC switching requires native calls to libVLC SPU APIs and
Dart API plumbing for:

- enumerate subtitle tracks
- get current subtitle track
- set subtitle track by id
- disable subtitles

Without editing the plugin bridge itself, any in-app selector would be detect-only or fake,
which is explicitly rejected.

## Required implementation location (outside this repo)

1. `dart_vlc` Windows native plugin:
   - add SPU enumeration/get/set/disable bindings to libVLC.
2. `dart_vlc` Dart API surface:
   - expose subtitle track data and control methods.
3. App layer (this repo):
   - wire minimal subtitle menu only after real backend control exists.

## Packaging checklist for Windows runtime

When building release, ensure output contains:

- `libvlc.dll`
- `libvlccore.dll`
- VLC `plugins` directory

Missing any of these can prevent subtitle rendering even if APIs are wired.
