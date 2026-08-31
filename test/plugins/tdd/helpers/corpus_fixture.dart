/// CorpusFixture — a throwaway driven-app project carrying the corpus
/// harness's input contracts (spec 051-corpus-harness): the manifest at
/// `.zfa/manifests/corpus-manifest.json`, per-feature `specs/<f>/tdd/`
/// dirs, and a scripted fake zfa binary that logs every argv and replies
/// with per-(step, feature) machine lines — the 049 fake-zfa pattern,
/// one level up.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One scripted (step, feature) outcome: exit code + stdout lines.
typedef FakeOutcome = ({int exit, List<String> stdout});

class CorpusFixture {
  CorpusFixture._(this.root);

  /// The driven app's project root (the temp directory itself).
  final Directory root;

  static Future<CorpusFixture> create() async {
    final root = await Directory.systemTemp.createTemp('corpus_fixture_');
    final fx = CorpusFixture._(root);
    await Directory(p.join(root.path, 'specs')).create(recursive: true);
    return fx;
  }

  String get fakeBin => p.join(root.path, 'fake_bin', 'zfa');
  String get callsLog => p.join(root.path, 'fake_bin', 'calls.log');
  String get manifestPath =>
      p.join(root.path, '.zfa', 'manifests', 'corpus-manifest.json');
  String get progressPath =>
      p.join(root.path, '.zfa', 'corpus', 'progress.json');
  String get ledgerPath =>
      p.join(root.path, '.zfa', 'corpus', 'gap-ledger.json');
  String get waiversPath => p.join(root.path, '.zfa', 'corpus', 'waivers.json');
  String get auditReportPath =>
      p.join(root.path, '.zfa', 'corpus', 'audit-report.json');

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  /// Write the corpus manifest (#627's contract) and create each
  /// feature's `specs/<f>/tdd/` directory.
  Future<void> writeManifest(
    List<({String name, bool ready, String reason})> features,
  ) async {
    await File(manifestPath).parent.create(recursive: true);
    await File(manifestPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'features': [
          for (final f in features)
            {'name': f.name, 'ready': f.ready, 'reason': f.reason},
        ],
        'sourceCorpus': '/corpus',
        'importedAt': '2026-08-31T00:00:00Z',
      }),
    );
    for (final f in features) {
      await Directory(
        p.join(root.path, 'specs', f.name, 'tdd'),
      ).create(recursive: true);
    }
  }

  /// Write the scripted fake zfa binary — the repo's canonical
  /// `TddFixture.writeFakeZfaBin` conventions (ARGV substring dispatch
  /// via `if [[ "$ARGV" == *"<pattern>"* ]]`, `LOG`-variable append),
  /// extended with the corpus's two additions: scripted stdout machine
  /// lines and success defaults. [outcomes] keys are `<step>:<feature>`
  /// (`run:f1-good`, `verify:f2-gap`); unmatched invocations default to
  /// success lines (a completing run + a passing gate), so tests only
  /// script the interesting features.
  Future<void> writeFakeZfa({
    Map<String, FakeOutcome> outcomes = const {},
    bool resetLog = true,
  }) async {
    final dir = Directory(p.dirname(fakeBin));
    await dir.create(recursive: true);
    if (resetLog) {
      await File(callsLog).writeAsString('');
    }

    final buf = StringBuffer()
      ..writeln('#!/usr/bin/env bash')
      ..writeln('set -e')
      ..writeln('LOG="$callsLog"')
      ..writeln('ARGV="\$*"')
      ..writeln('echo "\$ARGV" >> "\$LOG"');
    // outcome dispatch (substring match on argv — writeFakeZfaBin style)
    outcomes.forEach((key, outcome) {
      buf.writeln('if [[ "\$ARGV" == *"${_argvPattern(key)}"* ]]; then');
      for (final line in outcome.stdout) {
        buf.writeln('  echo ${shellQuote(line)}');
      }
      buf.writeln('  exit ${outcome.exit}');
      buf.writeln('fi');
    });
    // default: a completing run / a passing gate (the corpus extension
    // of writeFakeZfaBin's exit-0 tail — machine lines are required)
    buf
      ..writeln('if [[ "\$ARGV" == *" run "* ]]; then')
      ..writeln('  FEATURE="\${ARGV#* run }"')
      ..writeln('  FEATURE="\${FEATURE%% *}"')
      ..writeln(
        '  echo "run: feature=\$FEATURE result=complete pending=0 red=0 '
        'green=1 done=1"',
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

  /// The argv substring a `<step>:<feature>` key dispatches on — the two
  /// argv shapes the corpus runner spawns: `run <feature> …` and
  /// `verify --feature <feature> …`.
  static String _argvPattern(String key) {
    final parts = key.split(':');
    return parts.first == 'run'
        ? 'run ${parts.last}'
        : 'verify --feature ${parts.last}';
  }

  /// Re-script the fake (the "fix the gap" step of resume tests):
  /// rewrite the binary with [outcomes] merged over the previous map.
  /// The argv log is preserved — resume assertions count invocations
  /// ACROSS the re-run (SC-001).
  Future<void> rewriteFakeZfa(Map<String, FakeOutcome> outcomes) async {
    if (await File(fakeBin).exists()) {
      await File(fakeBin).delete();
    }
    await writeFakeZfa(outcomes: outcomes, resetLog: false);
  }

  /// The recorded argv lines, one per fake invocation.
  Future<List<String>> readCalls() async {
    final file = File(callsLog);
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    return raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  /// Read the persisted progress JSON (null when absent).
  Future<Map<String, dynamic>?> readProgress() async {
    final file = File(progressPath);
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  /// Read the persisted ledger entries (empty when absent).
  Future<List<dynamic>> readLedger() async {
    final file = File(ledgerPath);
    if (!await file.exists()) return const [];
    return jsonDecode(await file.readAsString()) as List<dynamic>;
  }
}

String shellQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";
