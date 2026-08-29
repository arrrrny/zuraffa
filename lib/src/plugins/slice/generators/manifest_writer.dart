/// ManifestWriter (spec 043): slice.yaml persistence.
library;

import 'dart:io';

import '../models/slice_manifest.dart';

/// Error raised for missing or corrupt slice.yaml files (U3).
class SliceManifestError implements Exception {
  /// Creates the error with a user-facing [message].
  const SliceManifestError(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'SliceManifestError: $message';
}

/// Writes and reads [SliceManifest]s as `slice.yaml` in a slice directory.
class ManifestWriter {
  /// File name of the manifest inside a slice directory.
  static const manifestFileName = 'slice.yaml';

  /// Writes [manifest] as `slice.yaml` inside [directory].
  Future<void> write(SliceManifest manifest, String directory) async {
    final file = File('$directory/$manifestFileName');
    await file.parent.create(recursive: true);
    await file.writeAsString(manifest.toYaml());
  }

  /// Reads `slice.yaml` from [directory].
  ///
  /// Throws [SliceManifestError] naming the directory when the file is
  /// missing or corrupt.
  Future<SliceManifest> read(String directory) async {
    final file = File('$directory/$manifestFileName');
    if (!await file.exists()) {
      throw SliceManifestError(
        'No slice.yaml found in slice directory "$directory" — was the slice '
        'cut from this project?',
      );
    }
    final source = await file.readAsString();
    try {
      return SliceManifest.fromYaml(source);
    } on SliceManifestYamlError catch (e) {
      throw SliceManifestError(
        'The slice.yaml in "$directory" is corrupt (${e.message}). Re-cut '
        'the slice or fix the manifest by hand.',
      );
    }
  }
}
