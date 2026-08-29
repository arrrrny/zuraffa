/// Exports a bone directory as a `.tar.gz` archive.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Packages a bone directory into a compressed tar.gz file.
class BoneExporter {
  /// Exports [boneDir] to a `.tar.gz` file at [outputPath].
  ///
  /// [outputPath] should end with `.tar.gz`.
  /// Throws if the directory does not exist.
  Future<void> export(Directory boneDir, String outputPath) async {
    if (!await boneDir.exists()) {
      throw ArgumentError('Bone directory does not exist: ${boneDir.path}');
    }

    // Collect all files in the bone directory.
    final files = <_ArchiveFile>[];
    for (final entity in boneDir.listSync(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: boneDir.path).replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        files.add(_ArchiveFile(relativePath, bytes));
      }
    }

    // Create a tar archive.
    final archive = Archive();
    for (final file in files) {
      archive.addFile(ArchiveFile(file.path, file.bytes.length, file.bytes));
    }

    // Compress to gzip.
    final tarBytes = TarEncoder().encode(archive);
    final gzBytes = GZipEncoder().encode(tarBytes);

    // Write the output file.
    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(Uint8List.fromList(gzBytes));
  }
}

class _ArchiveFile {
  const _ArchiveFile(this.path, this.bytes);
  final String path;
  final Uint8List bytes;
}
