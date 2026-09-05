// CorpusWalkFixture — a throwaway driven-app project for the corpus-walk
// commands (epic #1017 CORPUS-WALK): the corpus manifest at
// `.zfa/manifests/corpus-manifest.json`, per-feature `specs/<f>/spec.md`
// files whose content drives the CORE/SKIN classification, and a scripted
// fake zfa binary (the repo's canonical fake-zfa pattern) that logs every
// argv and replies with per-(step, feature) machine lines.
//
// Shared by the catalog / run / ledger command tests so all three drive
// the same fixture shape.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One scripted (step, feature) outcome: exit code + stdout lines.
typedef WalkOutcome = ({int exit, List<String> stdout});

/// A manifest row: feature directory name + readiness mark + reason.
typedef ManifestFeature = ({String name, bool ready, String reason});

class CorpusWalkFixture {
  CorpusWalkFixture._(this.root);

  /// The driven app's project root (the temp directory itself).
  final Directory root;

  /// The canonical corpus-walk target name used by the command tests.
  static const String target = 'zik_zak';

  static Future<CorpusWalkFixture> create() async {
    final root = await Directory.systemTemp.createTemp('corpus_walk_fx_');
    await Directory(p.join(root.path, 'specs')).create(recursive: true);
    return CorpusWalkFixture._(root);
  }

  String get fakeBin => p.join(root.path, 'fake_bin', 'zfa');
  String get callsLog => p.join(root.path, 'fake_bin', 'calls.log');
  String get manifestPath =>
      p.join(root.path, '.zfa', 'manifests', 'corpus-manifest.json');
  String get catalogPath =>
      p.join(root.path, 'corpus', 'catalogs', '$target.json');
  String get ledgerPath =>
      p.join(root.path, 'corpus', 'ledgers', '$target.json');
  String get walkPath =>
      p.join(root.path, '.zfa', 'corpus', 'walks', '$target.json');

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  /// Write the corpus manifest (the #627/#050 import contract shape the
  /// walk commands consume) and each feature's `specs/<f>/tdd/` dir.
  Future<void> writeManifest(List<ManifestFeature> features) async {
    await File(manifestPath).parent.create(recursive: true);
    await File(manifestPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'features': [
          for (final f in features)
            {'name': f.name, 'ready': f.ready, 'reason': f.reason},
        ],
        'source_corpus': '/corpus',
        'imported_at': '2026-09-05T00:00:00Z',
      }),
    );
    for (final f in features) {
      await Directory(
        p.join(root.path, 'specs', f.name, 'tdd'),
      ).create(recursive: true);
    }
  }

  /// Write `specs/<name>/spec.md` (the walk's classification + hash input).
  Future<void> writeSpec(String name, String specMd) async {
    final dir = Directory(p.join(root.path, 'specs', name));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'spec.md')).writeAsString(specMd);
  }

  /// A spec whose signals classify CORE (engine seam: entities, mocks,
  /// repositories, DI, use cases).
  static String coreSpec(String name) =>
      '# $name engine\n'
      '\n'
      '## Acceptance Scenarios\n'
      '\n'
      '1. **Given** the `$name` entity, **When** the repository persists '
      'it, **Then** the use case returns the saved entity.\n'
      '2. **Given** a certified mock of the entity datasource, **When** '
      'the service boots the DI injection, **Then** the domain contract '
      'holds.\n'
      '\n'
      '## Functional Requirements\n'
      '\n'
      '- FR-1: The entity model MUST validate its fields through the '
      'domain policy.\n'
      '- FR-2: The repository MUST bind through the service locator; '
      'mocks MUST be certified before any engine pipeline proceeds.\n';

  /// A spec whose signals classify SKIN (presentation seam: views, routes,
  /// adaptive layouts, platforms).
  static String skinSpec(String name) =>
      '# $name screen\n'
      '\n'
      '## Acceptance Scenarios\n'
      '\n'
      '1. **Given** the `$name` view, **When** the adaptive layout picks '
      'the platform variant, **Then** the page renders behind the shell.\n'
      '2. **Given** the route `/wonderland`, **When** the router '
      'navigates to the screen, **Then** the widget tree paints.\n'
      '\n'
      '## Functional Requirements\n'
      '\n'
      '- FR-1: The view MUST compose an adaptive layout for every '
      'platform (mobile, macos).\n'
      '- FR-2: The route MUST register in the host router; the page MUST '
      'animate the navigation transition.\n';

  /// A spec with no class signals (the feature name decides).
  static String neutralSpec(String name) =>
      '# $name\n'
      '\n'
      '## Acceptance Scenarios\n'
      '\n'
      '1. **Given** neutral, **When** neutral, **Then** neutral.\n'
      '\n'
      '## Functional Requirements\n'
      '\n'
      '- FR-1: Neutral behavior.\n';

  /// Write the scripted fake zfa binary — the repo's canonical fake-zfa
  /// conventions: ARGV substring dispatch, LOG-variable append, scripted
  /// machine lines. [outcomes] keys are `<step>:<feature>`
  /// (`run:f1-bad`, `verify:f2-gap`); unmatched invocations default to
  /// success lines (a completing run + a passing gate).
  Future<void> writeFakeZfa({
    Map<String, WalkOutcome> outcomes = const {},
  }) async {
    final dir = Directory(p.dirname(fakeBin));
    await dir.create(recursive: true);
    await File(callsLog).writeAsString('');

    final buf = StringBuffer()
      ..writeln('#!/usr/bin/env bash')
      ..writeln('set -e')
      ..writeln('LOG="$callsLog"')
      ..writeln('ARGV="\$*"')
      ..writeln('echo "\$ARGV" >> "\$LOG"');
    outcomes.forEach((key, outcome) {
      final parts = key.split(':');
      final pattern = parts.first == 'run'
          ? 'run ${parts.last}'
          : 'verify --feature ${parts.last}';
      buf.writeln('if [[ "\$ARGV" == *"$pattern"* ]]; then');
      for (final line in outcome.stdout) {
        buf.writeln('  echo ${_shellQuote(line)}');
      }
      buf.writeln('  exit ${outcome.exit}');
      buf.writeln('fi');
    });
    buf
      ..writeln('if [[ "\$ARGV" == *" run "* ]]; then')
      ..writeln('  FEATURE="${'\$'}{ARGV#* run }"')
      ..writeln('  FEATURE="${'\$'}{FEATURE%% *}"')
      ..writeln(
        '  echo "run: feature=${'\$'}{FEATURE} result=complete pending=0 '
        'red=0 green=1 done=1"',
      )
      ..writeln('  exit 0')
      ..writeln('fi')
      ..writeln('if [[ "\$ARGV" == *" verify "* ]]; then')
      ..writeln(
        '  echo "mutation: gate=pass killed=1 survived=0 timed_out=0 '
        'mutation_was_run=true"',
      )
      ..writeln('  exit 0')
      ..writeln('fi')
      ..writeln('exit 2');
    await File(fakeBin).writeAsString(buf.toString());
    await Process.run('chmod', ['+x', fakeBin]);
  }

  /// The recorded argv lines, one per fake invocation.
  Future<List<String>> readCalls() async {
    final file = File(callsLog);
    if (!await file.exists()) return const [];
    final text = await file.readAsString();
    return text.split('\n').where((l) => l.isNotEmpty).toList();
  }

  /// Reads a JSON file under the fixture root (fails the test loudly on
  /// a missing file).
  Map<String, dynamic> readJsonMap(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('expected JSON file missing: $path');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

String _shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";
