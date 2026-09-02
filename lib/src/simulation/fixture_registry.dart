/// Fixture infrastructure for the certified simulation worlds
/// (bug #832, requirement 3: "Fixtures are committed under
/// `specs/<feature>/tdd/fixtures/` and hashed into cycle-log evidence").
///
/// - [SimulationFixtures.scaffold] materializes the certified worlds
///   (`certified_worlds.dart`) into a feature's `tdd/fixtures/` directory
///   — fixture commitment is automated, not manual.
/// - [FixtureRegistry] writes/verifies the SHA-256 manifest for the
///   committed fixtures and appends a hash-chained evidence entry to the
///   feature's TDD cycle log, using the same schema-1 hash-chain format
///   (`- prev-hash:` / `- hash:`) the run driver and doctor already parse
///   (spec 049; bug #828).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../plugins/tdd/services/cycle_evidence.dart';
import 'certified_worlds.dart';

/// Raised when a committed fixture no longer matches its manifest hash,
/// or the manifest itself is missing/corrupt. The world refuses to boot
/// from a tampered contract.
final class FixtureMismatch implements Exception {
  const FixtureMismatch(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => 'FixtureMismatch: $path — $reason';
}

/// SHA-256 hashing, manifest writing/verification, and cycle-log
/// evidence for one fixtures directory.
class FixtureRegistry {
  FixtureRegistry(this.fixturesDir);

  /// The fixtures directory (`specs/<feature>/tdd/fixtures/`).
  final String fixturesDir;

  static String get manifestFileName => 'manifest.json';

  /// SHA-256 of [bytes] as lowercase hex.
  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  /// Hash every fixture file (anything except the manifest itself).
  Future<Map<String, Map<String, dynamic>>> hashAll() async {
    final dir = Directory(fixturesDir);
    if (!dir.existsSync()) {
      throw FixtureMismatch(fixturesDir, 'fixtures directory does not exist');
    }
    final hashes = <String, Map<String, dynamic>>{};
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path) != manifestFileName)
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final relative = p.relative(file.path, from: fixturesDir);
      final bytes = file.readAsBytesSync();
      hashes[relative] = {
        'sha256': sha256Hex(bytes),
        'bytes': bytes.length,
      };
    }
    return hashes;
  }

  /// The combined world digest: SHA-256 over the sorted
  /// `"<relative-path>:<sha256>\n"` lines.
  String digestOf(Map<String, Map<String, dynamic>> hashes) {
    final lines = hashes.entries
        .map((e) => '${e.key}:${e.value['sha256']}\n')
        .toList()
      ..sort();
    return sha256Hex(ascii.encode(lines.join()));
  }

  /// Write `manifest.json` for the current fixtures ([families] recorded
  /// for provenance).
  Future<Map<String, dynamic>> writeManifest({
    List<String> families = const [],
  }) async {
    final hashes = await hashAll();
    if (hashes.isEmpty) {
      throw FixtureMismatch(fixturesDir, 'no fixture files to certify');
    }
    final manifest = <String, dynamic>{
      'schema': 1,
      'bug': 832,
      'families': families,
      'files': hashes,
      'digest': digestOf(hashes),
    };
    File(p.join(fixturesDir, manifestFileName)).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    return manifest;
  }

  /// Read and structurally validate the manifest.
  Future<Map<String, dynamic>> readManifest() async {
    final file = File(p.join(fixturesDir, manifestFileName));
    if (!file.existsSync()) {
      throw FixtureMismatch(
        p.join(fixturesDir, manifestFileName),
        'manifest.json missing — run `zfa simulate --scaffold` first',
      );
    }
    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FixtureMismatch(file.path, 'manifest.json is not valid JSON: $e');
    }
    if (manifest['files'] is! Map<String, dynamic> ||
        manifest['digest'] is! String) {
      throw FixtureMismatch(file.path, 'manifest.json missing files/digest');
    }
    return manifest;
  }

  /// Re-hash every fixture and compare with the manifest. Throws
  /// [FixtureMismatch] on any drift.
  Future<void> verifyManifest() async {
    final manifest = await readManifest();
    final recorded = (manifest['files'] as Map<String, dynamic>)
        .cast<String, Map<String, dynamic>>();
    final actual = await hashAll();
    for (final relative in recorded.keys) {
      final file = File(p.join(fixturesDir, relative));
      if (!file.existsSync()) {
        throw FixtureMismatch(file.path, 'recorded in manifest but missing');
      }
      if (actual[relative] == null) {
        throw FixtureMismatch(file.path, 'not a fixture file');
      }
      if (actual[relative]!['sha256'] != recorded[relative]!['sha256']) {
        throw FixtureMismatch(
          file.path,
          'fixture bytes do not match the certified manifest hash '
          '(expected ${recorded[relative]!['sha256']}, '
          'got ${actual[relative]!['sha256']})',
        );
      }
    }
    if (digestOf(actual) != manifest['digest']) {
      throw FixtureMismatch(
        fixturesDir,
        'world digest drift — the fixture set is not the certified one',
      );
    }
  }

  /// Append a hash-chained evidence entry to the feature's TDD cycle log
  /// (`<featureDir>/tdd/cycle-log.md`), recording the world digest under
  /// the `kind: fixtures` behavior `<featureSlug>-fixtures`. The entry
  /// follows the schema-1 chain format (`- prev-hash:` / `- hash:`) so
  /// the existing evidence tooling parses it without changes.
  Future<void> appendCycleEvidence({
    required String featureDir,
    required List<String> families,
    required String commandLine,
  }) async {
    final manifest = await readManifest();
    final digest = manifest['digest'] as String;
    final slug = p.basename(p.normalize(featureDir));
    final behaviorId = '$slug-fixtures';
    final tddDir = Directory(p.join(featureDir, 'tdd'));
    if (!tddDir.existsSync()) tddDir.createSync(recursive: true);
    final file = File(p.join(tddDir.path, 'cycle-log.md'));

    final existing = file.existsSync() ? file.readAsStringSync() : '';
    final cycleEvidence = CycleEvidence(featureDir);
    final prev = await cycleEvidence.lastHashFor(behaviorId) ?? 'genesis';
    final now = DateTime.now().toUtc().toIso8601String();

    final recorded = (manifest['files'] as Map<String, dynamic>)
        .cast<String, Map<String, dynamic>>();
    final buffer = StringBuffer()
      ..writeln('## $now: certified simulation fixtures (bug #832)')
      ..writeln('- behavior: $behaviorId')
      ..writeln('- kind: fixtures')
      ..writeln('- at: $now')
      ..writeln('- exit: 0')
      ..writeln(
        '- criterion: certified fixture world committed under '
        'tdd/fixtures/ and hashed into the manifest digest',
      )
      ..writeln('- command: `$commandLine`')
      ..writeln('- schema: 1')
      ..writeln('- prev-hash: $prev')
      ..writeln('- hash: $digest')
      ..writeln('- families: ${families.join(',')}');
    for (final relative in recorded.keys) {
      buffer.writeln('- fixtures: $relative=${recorded[relative]!['sha256']}');
    }

    final prefix = existing.isEmpty
        ? '# Cycle log — $slug\n'
        : (existing.endsWith('\n') ? existing : '$existing\n');
    file.writeAsStringSync('$prefix\n${buffer.toString()}');
  }
}

/// Automated fixture commitment: materialize the certified worlds into a
/// feature's `tdd/fixtures/` directory.
final class SimulationFixtures {
  SimulationFixtures._();

  /// Scaffold [families] (default: all five) into [fixturesDir]. Refuses
  /// to overwrite an existing certified world unless [force] is set.
  /// Returns the written manifest.
  static Future<Map<String, dynamic>> scaffold(
    String fixturesDir, {
    List<String>? families,
    bool force = false,
  }) async {
    final selected = (families == null || families.isEmpty)
        ? simulationFamilies
        : families;
    for (final family in selected) {
      if (certifiedWorldFor(family) == null) {
        throw FixtureMismatch(family, 'unknown simulation family');
      }
    }
    final manifestFile = File(p.join(fixturesDir, FixtureRegistry.manifestFileName));
    if (manifestFile.existsSync() && !force) {
      throw FixtureMismatch(
        manifestFile.path,
        'certified world already exists — re-certify with --force',
      );
    }
    Directory(fixturesDir).createSync(recursive: true);
    for (final family in selected) {
      final world = certifiedWorldFor(family)!;
      final fileName = simulationFamilyFiles[family]!;
      File(p.join(fixturesDir, fileName)).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(world)}\n',
      );
    }
    return FixtureRegistry(fixturesDir).writeManifest(families: selected);
  }
}
