/// Certification glue between the committed per-entity fixtures (spec 893)
/// and the #832 fixture registry: manifest writing that preserves the
/// existing certified simulation families, plus hash-chained cycle
/// evidence when the fixtures directory follows the
/// `specs/<feature>/tdd/fixtures/` convention.
///
/// Spec 1001 (issue #1001) extends this glue with
/// [certifyMockInRegistry]: `zfa mock certify <Entity>` commits the
/// `mock-cert.<Entity>.json` receipt as a certified fixture and re-writes
/// the #832 manifest with the mock's provenance (`mocks:` list), so the
/// Tier-1 mock's certification is hashed into the registry's world
/// digest.
library;

import 'dart:convert';
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

/// Registers a certified mock (spec 1001, issue #1001) in the #832
/// fixture registry entry at [fixturesDir]:
///
/// 1. writes the `mock-cert.<Entity>.json` receipt (already proven green
///    in the sandbox by the caller) into the fixtures directory;
/// 2. re-writes the manifest from disk — preserving the existing
///    `families` AND `mocks` provenance — so the receipt is hashed into
///    the world digest (byte drift outside certification is caught by
///    `verifyManifest`);
/// 3. appends a hash-chained `kind: mock-cert` cycle-log entry for the
///    feature when the directory follows `specs/<feature>/tdd/fixtures/`.
///
/// Returns the written manifest. Throws [FixtureMismatch] when the
/// directory has no fixtures to certify (the caller must have scaffolded
/// or fixture-committed it first).
Future<Map<String, dynamic>> certifyMockInRegistry({
  required String fixturesDir,
  required String entityName,
  required Map<String, dynamic> receipt,
  required String commandLine,
  bool verbose = false,
}) async {
  final registry = FixtureRegistry(fixturesDir);

  var families = <String>[];
  var mocks = <String>[];
  final manifestFile = File(
    p.join(fixturesDir, FixtureRegistry.manifestFileName),
  );
  if (manifestFile.existsSync()) {
    try {
      final existing = await registry.readManifest();
      families = (existing['families'] as List<dynamic>? ?? const [])
          .cast<String>();
      mocks = (existing['mocks'] as List<dynamic>? ?? const []).cast<String>();
    } on FixtureMismatch {
      // A corrupt manifest is replaced by the re-certification below.
    }
  }

  // 1. Commit the receipt as a fixture (deterministic bytes: the
  //    receipt's certified_at is part of the certified record, not a
  //    generation output).
  final receiptFile = File(p.join(fixturesDir, 'mock-cert.$entityName.json'));
  await receiptFile.parent.create(recursive: true);
  await receiptFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(receipt)}\n',
  );

  // 2. Re-certify the directory (the receipt is now hashed in).
  if (!mocks.contains(entityName)) {
    mocks = [...mocks, entityName];
  }
  final manifest = await registry.writeManifest(
    families: families,
    mocks: mocks,
  );

  // 3. Feature-shaped evidence chain entry.
  final parent = p.normalize(p.join(fixturesDir, '..'));
  if (p.basename(parent) == 'tdd') {
    final featureDir = p.dirname(parent);
    try {
      await registry.appendMockCertEvidence(
        featureDir: featureDir,
        entityName: entityName,
        commandLine: commandLine,
      );
    } on FixtureMismatch {
      // Evidence is best-effort; the manifest certification is the
      // integrity contract.
    }
  }

  if (verbose) {
    stdout.writeln(
      '  ⚙ mock $entityName certified: digest '
      '${manifest['digest']}',
    );
  }
  return manifest;
}
