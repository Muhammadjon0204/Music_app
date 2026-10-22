import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:music_app/domain/library/import.dart';

/// The system file picker filtered to audio. On iOS this is the Files
/// document picker: no media-library permission is requested, and only the
/// files the user selects become readable.
final class SystemAudioFilePicker implements AudioFilePicker {
  const SystemAudioFilePicker();

  /// On the web picked files have no persistent path, so the library cannot
  /// keep them.
  @override
  bool get isSupported => !kIsWeb;

  @override
  Future<List<PickedAudioFile>> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    return [
      for (final file in files)
        if (file.path case final path?)
          PickedAudioFile(path: path, name: file.name),
    ];
  }

  /// Removes the picker's temporary copies once they have been imported.
  static Future<void> clearTemporaryFiles() => FilePicker.clearTemporaryFiles();
}
