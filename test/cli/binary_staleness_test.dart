/// SDD-TDD suite for issue #1184 — stale installed `zfa` binary warning.
///
/// The trap: `~/.local/bin/zfa` is a compiled snapshot (see
/// `scripts/rebuild.sh`). After fixing generator source in a zuraffa
/// checkout, every shell `zfa …` invocation kept reproducing the OLD bug
/// because the snapshot predated the fix — and nothing told the operator.
///
/// Mechanism under test:
/// - `scripts/rebuild.sh` records the source commit next to the installed
///   binary (`<install-dir>/zfa.build_commit`) at build time;
/// - at startup (shell path only) and in `zfa doctor`, the CLI reads that
///   marker, resolves the enclosing zuraffa worktree (nearest pubspec.yaml
///   with `name: zuraffa`), compares its HEAD, and emits ONE warning line
///   when the two differ.
///
/// Behaviors:
/// U1  binary-dir-derivation-source-run-null (dart test runs on the VM)
/// U2  binary-dir-derivation-explicit-injection-wins
/// U3  read-marker-trims-and-normalizes / missing-marker-null
/// U4  checkout-detection-finds-enclosing-zuraffa-pubspec
/// U5  checkout-detection-null-outside-any-worktree
/// U6  probe-no-marker-silent (pre-#1184 install)
/// U7  probe-fresh-binary-silent (marker == HEAD)
/// U8  probe-stale-binary-warns-one-line (marker != HEAD)
/// U9  probe-outside-zuraffa-checkout-silent
/// U10 probe-non-git-checkout-silent (no resolvable HEAD)
/// U11 cli-run-emits-warning-once-before-dispatch (stdout keeps version)
/// U12 cli-run-capturing-stays-clean (MCP protocol output unpolluted)
/// U13 doctor-warns-with-fix-when-stale
/// U14 doctor-passes-when-fresh
/// U15 doctor-skips-when-source-run
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/binary_staleness.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/doctor_checks.dart';

Future<Directory> _sandbox(String tag) async {
  final dir = await Directory.systemTemp.createTemp('zfa-1184-$tag-');
  addTearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
  return dir;
}

Future<String> _git(
  Directory dir,
  List<String> args, {
  bool identity = true,
}) async {
  final result = await Process.run('git', [
    if (identity) ...['-c', 'user.email=t@example.test', '-c', 'user.name=t'],
    ...args,
  ], workingDirectory: dir.path);
  if (result.exitCode != 0) {
    fail('git ${args.join(" ")} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

/// A minimal fake zuraffa worktree: pubspec `name: zuraffa` + one commit.
Future<Directory> _zuraffaCheckout(String tag) async {
  final dir = await _sandbox(tag);
  await File(
    '${dir.path}/pubspec.yaml',
  ).writeAsString('name: zuraffa\nenvironment:\n  sdk: ^3.11.0\n');
  await _git(dir, ['init']);
  await _commit(dir);
  return dir;
}

/// Commits and returns the resulting HEAD hash (commit's own stdout is
/// `[main abc…] message`, not the hash — always resolve via rev-parse).
Future<String> _commit(Directory dir) async {
  await _git(dir, ['commit', '--allow-empty', '-m', 'commit']);
  return _git(dir, ['rev-parse', 'HEAD'], identity: false);
}

/// A fake "install dir" holding the build-commit marker a compiled binary
/// would carry next to it (as written by scripts/rebuild.sh).
Future<Directory> _fakeBinDir(String tag, String commit) async {
  final dir = await _sandbox(tag);
  await File('${dir.path}/zfa.build_commit').writeAsString('$commit\n');
  return dir;
}

void main() {
  group('binary dir derivation', () {
    test(
      'U1: null under the dart test VM (source run — nothing installed)',
      () {
        expect(BinaryStaleness().binaryDir, isNull);
      },
    );

    test('U2: explicit injection wins (simulates an installed binary)', () {
      final staleness = BinaryStaleness(binaryDir: '/fake/install/bin');
      expect(staleness.binaryDir, '/fake/install/bin');
    });
  });

  group('build-commit marker', () {
    test(
      'U3: reads and trims the marker; missing marker yields null',
      () async {
        final bin = await _fakeBinDir('marker', 'abc123def456');
        final staleness = BinaryStaleness(binaryDir: bin.path);
        expect(staleness.readBuildCommit(bin.path), 'abc123def456');
        expect(
          staleness.readBuildCommit('${bin.path}-missing'),
          isNull,
          reason: 'no marker file → nothing recorded → never warn',
        );
      },
    );
  });

  group('zuraffa checkout detection', () {
    test('U4: walks up to the nearest pubspec with name: zuraffa', () async {
      final checkout = await _zuraffaCheckout('walk-up');
      final nested = Directory('${checkout.path}/lib/src/deep')
        ..createSync(recursive: true);
      expect(BinaryStaleness.findZuraffaCheckout(nested.path), checkout.path);
    });

    test('U4b: name: zuraffa does not match zuraffa_example', () async {
      final dir = await _sandbox('example-name');
      await File(
        '${dir.path}/pubspec.yaml',
      ).writeAsString('name: zuraffa_example\n');
      expect(BinaryStaleness.findZuraffaCheckout(dir.path), isNull);
    });

    test('U5: null outside any zuraffa worktree', () async {
      final dir = await _sandbox('no-checkout');
      await File('${dir.path}/pubspec.yaml').writeAsString('name: other_pkg\n');
      expect(BinaryStaleness.findZuraffaCheckout(dir.path), isNull);
    });
  });

  group('staleness probe', () {
    test('U6: no marker (pre-#1184 install) → silent', () async {
      final checkout = await _zuraffaCheckout('no-marker');
      final bin = await _sandbox('bin-no-marker');
      final staleness = BinaryStaleness(binaryDir: bin.path);
      final report = await staleness.probe(cwd: checkout.path);
      expect(report, isNull);
    });

    test('U7: fresh binary (marker == HEAD) → silent', () async {
      final checkout = await _zuraffaCheckout('fresh');
      final head = await _git(checkout, ['rev-parse', 'HEAD'], identity: false);
      final bin = await _fakeBinDir('bin-fresh', head);
      final staleness = BinaryStaleness(binaryDir: bin.path);
      final report = await staleness.probe(cwd: checkout.path);
      expect(report?.warning, isNull);
    });

    test('U8: stale binary (marker != HEAD) → ONE warning line', () async {
      final checkout = await _zuraffaCheckout('stale');
      final builtAt = await _commit(checkout);
      final head = await _commit(checkout);
      expect(builtAt, isNot(head), reason: 'scenario needs diverged commits');
      final bin = await _fakeBinDir('bin-stale', builtAt);
      final staleness = BinaryStaleness(binaryDir: bin.path);
      final report = await staleness.probe(cwd: checkout.path);
      final warning = report!.warning;
      expect(warning, isNotNull);
      expect(warning!.split('\n').length, 1, reason: 'ONE line');
      expect(warning, contains('⚠️'));
      expect(
        warning,
        contains('installed zfa (${BinaryStaleness.shortCommit(builtAt)})'),
      );
      expect(
        warning,
        contains('this checkout (${BinaryStaleness.shortCommit(head)})'),
      );
      expect(warning, contains('run scripts/rebuild.sh'));
    });

    test(
      'U9: outside a zuraffa checkout → silent even with a marker',
      () async {
        final plain = await _sandbox('plain-cwd');
        final bin = await _fakeBinDir('bin-plain', 'abc123def4567890');
        final staleness = BinaryStaleness(binaryDir: bin.path);
        expect(await staleness.probe(cwd: plain.path), isNull);
      },
    );

    test(
      'U10: zuraffa checkout without resolvable git HEAD → silent',
      () async {
        final dir = await _sandbox('no-git-head');
        await File('${dir.path}/pubspec.yaml').writeAsString('name: zuraffa\n');
        final bin = await _fakeBinDir('bin-no-git', 'abc123def4567890');
        final staleness = BinaryStaleness(binaryDir: bin.path);
        expect(await staleness.probe(cwd: dir.path), isNull);
      },
    );
  });

  group('CliRunner startup hook (shell path only)', () {
    test(
      'U11: run() emits the warning once; stdout keeps the version line',
      () async {
        final checkout = await _zuraffaCheckout('runner-stale');
        final builtAt = await _commit(checkout);
        await _commit(checkout);
        final bin = await _fakeBinDir('runner-bin', builtAt);

        final warnings = <String>[];
        final stdoutLines = <String>[];
        final runner = CliRunner(
          exitOnCompletion: false,
          staleness: BinaryStaleness(binaryDir: bin.path),
          onStalenessWarning: warnings.add,
        );
        await runZoned(
          () => runner.run(['-C', checkout.path, '--version']),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => stdoutLines.add(line),
          ),
        );
        expect(warnings.length, 1, reason: 'exactly ONE warning line');
        expect(warnings.single, contains('run scripts/rebuild.sh'));
        expect(
          stdoutLines.any((l) => l.startsWith('zfa v')),
          isTrue,
          reason: 'version output unchanged by the advisory warning',
        );
      },
    );

    test(
      'U12: runCapturing() (MCP-embedded) stays clean — no warning',
      () async {
        final checkout = await _zuraffaCheckout('mcp-stale');
        final builtAt = await _commit(checkout);
        await _commit(checkout);
        final bin = await _fakeBinDir('mcp-bin', builtAt);

        final warnings = <String>[];
        final runner = CliRunner(
          exitOnCompletion: false,
          staleness: BinaryStaleness(binaryDir: bin.path),
          onStalenessWarning: warnings.add,
        );
        final out = await runner.runCapturing([
          '-C',
          checkout.path,
          '--version',
        ]);
        expect(
          warnings,
          isEmpty,
          reason: 'machine-parsed protocol stays clean',
        );
        expect(out, contains('zfa v'));
      },
    );
  });

  group('zfa doctor binary-staleness check', () {
    test('U13: stale binary → WARN with the exact remediation', () async {
      final checkout = await _zuraffaCheckout('doctor-stale');
      final builtAt = await _commit(checkout);
      await _commit(checkout);
      final bin = await _fakeBinDir('doctor-bin', builtAt);
      final runner = DoctorChecksRunner(
        projectDir: checkout.path,
        binaryDir: bin.path,
      );
      final result = (await runner.runAll(
        fix: false,
      )).singleWhere((r) => r.id == 'binary-staleness');
      expect(result.status, DoctorCheckStatus.warn);
      expect(result.detail, contains('installed zfa'));
      expect(result.suggestedFix, 'scripts/rebuild.sh');
    });

    test('U14: fresh binary → PASS', () async {
      final checkout = await _zuraffaCheckout('doctor-fresh');
      final head = await _git(checkout, ['rev-parse', 'HEAD'], identity: false);
      final bin = await _fakeBinDir('doctor-bin-fresh', head);
      final runner = DoctorChecksRunner(
        projectDir: checkout.path,
        binaryDir: bin.path,
      );
      final result = (await runner.runAll(
        fix: false,
      )).singleWhere((r) => r.id == 'binary-staleness');
      expect(result.status, DoctorCheckStatus.pass);
    });

    test('U15: source run (no installed binary) → SKIP', () async {
      final checkout = await _zuraffaCheckout('doctor-source');
      final runner = DoctorChecksRunner(projectDir: checkout.path);
      final result = (await runner.runAll(
        fix: false,
      )).singleWhere((r) => r.id == 'binary-staleness');
      expect(result.status, DoctorCheckStatus.skipped);
    });
  });
}
