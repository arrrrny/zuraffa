/// Certification glue between the committed per-entity fixtures (spec 893)
/// and the #832 fixture registry: manifest writing that preserves the
/// existing certified simulation families, plus hash-chained cycle
/// evidence when the fixtures directory follows the
/// `specs/<feature>/tdd/fixtures/` convention.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../simulation/fixture_registry.dart';

/// Re-certifies [fixturesDir] through the #832 [FixtureRegistry].
///
/// The manifest is rewritten from the bytes on disk (all fixture files —
/// certified simulation worlds and per-entity fixture JSON — are covered
/// by the world digest). Existing manifest families are preserved. When
/// the directory sits under a feature's `tdd/fixtures/`, a `kind:
/// fixtures` entry is appended to the feature's hash-chained cycle log.
Future<void> certifyFixturesDirectory(
  String fixturesDir, {
  required String commandLine,
  bool verbose = false,
}) async {
  final registry = FixtureRegistry(fixturesDir);

  var families = <String>[];
  final manifestFile = File(
    p.join(fixturesDir, FixtureRegistry.manifestFileName),
  );
  if (manifestFile.existsSync()) {
    try {
      final existing = await registry.readManifest();
      families = (existing['families'] as List<dynamic>? ?? const [])
          .cast<String>();
    } on FixtureMismatch {
      // A corrupt manifest is replaced by the re-certification below.
      families = <String>[];
    }
  }

  final manifest = await registry.writeManifest(families: families);

  // Append hash-chained evidence only for feature-shaped fixture
  // directories: .../<feature>/tdd/fixtures.
  final parent = p.normalize(p.join(fixturesDir, '..'));
  if (p.basename(parent) == 'tdd') {
    final featureDir = p.dirname(parent);
    try {
      await registry.appendCycleEvidence(
        featureDir: featureDir,
        families: families,
        commandLine: commandLine,
      );
    } on FixtureMismatch {
      // Evidence is best-effort; the manifest certification above is the
      // integrity contract.
    }
  }

  if (verbose) {
    stdout.writeln('  ⚙ fixtures certified: digest ${manifest['digest']}');
  }
}
