/// TarballExporter (spec 043): `.tar.gz` slice archives (US8, FR-017).
///
/// Packages the sandbox tree (mirrored `lib/` files, generated harness,
/// `SLICE.md`, `slice.yaml`) plus the FILTERED `pubspec.yaml` into a
/// compressed tarball, so the slice can be handed to an agent or a machine
/// without GitHub.
library;

import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Produces `.tar.gz` archives of a slice sandbox.
class TarballExporter {
  /// Exports the sandbox at [sandboxDir] to a `.tar.gz` at [outputPath],
  /// embedding [pubspecContent] as the archive's `pubspec.yaml`.
  ///
  /// Returns the archive path.
  Future<String> export({
    required String sandboxDir,
    required String outputPath,
    required String pubspecContent,
  }) async {
    final sandboxRoot = Directory(sandboxDir);
    if (!await sandboxRoot.exists()) {
      throw ArgumentError('Sandbox directory does not exist: $sandboxDir');
    }

    final archive = Archive();
    for (final entity in sandboxRoot.listSync(recursive: true)) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: sandboxDir)
          .replaceAll('\\', '/');
      if (rel == 'pubspec.yaml') continue; // replaced by the filtered one
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }
    final pubspecBytes = Uint8List.fromList(utf8.encode(pubspecContent));
    archive.addFile(
      ArchiveFile('pubspec.yaml', pubspecBytes.length, pubspecBytes),
    );

    final tarBytes = TarEncoder().encode(archive);
    final gzBytes = GZipEncoder().encode(tarBytes);

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(Uint8List.fromList(gzBytes));
    return outputPath;
  }
}
