/// HostReferenceScanner (feature 073, issue #961): the self-containment
/// half of `slice verify` — any reference escaping the sandbox root to
/// the host fails self-containment, named.
///
/// Pure file scan: no host cooperation needed; the sandbox must carry
/// no path, import, or string pointing back at the host it was cut
/// from (spec US1 AC-2, plan decision 2).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// One host reference found inside the sandbox.
class HostReference {
  /// Sandbox-relative path of the offending file.
  final String file;

  /// 1-based line of the reference.
  final int line;

  /// The offending reference text.
  final String reference;

  const HostReference(this.file, this.line, this.reference);

  @override
  String toString() => '$file:$line: "$reference"';
}

/// Scans a sandbox for references to its host project root.
abstract final class HostReferenceScanner {
  /// Scan every text file under [sandboxDir] for references to
  /// [hostRoot] (or the raw [hostMarker] string when the host path is
  /// unavailable, e.g. a tarball import).
  ///
  /// The cut's provenance records — `slice.yaml` and `SLICE.md` at the
  /// sandbox root — are excluded: they ARE the audit trail of where the
  /// slice came from, by design. Self-containment covers everything
  /// else: no wiring, no receipt, no generated file may reference the
  /// host.
  static List<HostReference> scan({
    required String sandboxDir,
    String? hostRoot,
    String? hostMarker,
  }) {
    final needles = <String>{
      if (hostRoot != null && hostRoot.isNotEmpty) p.canonicalize(hostRoot),
      if (hostMarker != null && hostMarker.isNotEmpty) hostMarker,
      if (hostRoot != null && hostRoot.isNotEmpty) ..._pathVariants(hostRoot),
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    if (needles.isEmpty) return const [];

    const provenanceRecords = {'slice.yaml', 'SLICE.md'};
    final root = Directory(sandboxDir);
    if (!root.existsSync()) return const [];

    final issues = <HostReference>[];
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !_isBinary(f.path))
            .where(
              (f) => !provenanceRecords.contains(p.basename(f.path)),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      List<String> lines;
      try {
        lines = file.readAsStringSync().split('\n');
      } on FileSystemException {
        continue;
      }
      final rel = p.relative(file.path, from: sandboxDir);
      for (var i = 0; i < lines.length; i++) {
        for (final needle in needles) {
          final idx = lines[i].indexOf(needle);
          if (idx >= 0) {
            issues.add(HostReference(rel, i + 1, needle));
            break;
          }
        }
      }
    }
    return issues;
  }

  /// Windows- and POSIX-style spellings of the host path, so a sandbox
  /// cut on either platform is scanned for both.
  static List<String> _pathVariants(String hostRoot) {
    final variants = <String>[];
    final posix = hostRoot.replaceAll('\\', '/');
    final windows = hostRoot.replaceAll('/', '\\');
    if (posix != hostRoot) variants.add(posix);
    if (windows != hostRoot) variants.add(windows);
    return variants;
  }

  static bool _isBinary(String path) {
    const binaryExtensions = {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.ico',
      '.ttf',
      '.otf',
      '.woff',
      '.zip',
      '.tar',
      '.gz',
      '.class',
      '.so',
      '.dylib',
      '.dll',
    };
    final ext = p.extension(path).toLowerCase();
    return binaryExtensions.contains(ext);
  }
}
