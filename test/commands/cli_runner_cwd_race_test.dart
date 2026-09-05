@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Issue #1096 — cross-suite `Directory.current` race in
/// `CliRunner._withDirectory`.
///
/// `dart test` runs suites as concurrent isolates in one VM. Every suite
/// that drives the CLI with `-C <dir>` mutates the PROCESS-WIDE
/// `Directory.current` for the duration of the invocation (the chdir
/// window) and restores it afterward. The `_active` re-entrancy guard only
/// protects a single runner instance, so two suites each driving their own
/// [CliRunner] can hold overlapping chdir windows:
///
///   suite A: saved = <repo>; chdir -> tempA      (window open)
///   suite B: saved = tempA (!); chdir -> tempB   (window open)
///   suite A: writes resolve against tempB; restores <repo>
///   suite B: restores tempA — the process is left in the wrong root
///
/// A write then lands in (or resolves from) the wrong root, which is the
/// observed flake: the service verdict tests pass in isolation (4/4) and
/// fail intermittently when run with sibling suites.
///
/// The tests below reproduce both the deterministic interleaving (one
/// isolate, two concurrent windows) and the production topology (two
/// isolates hammering `-C` like two dart-test suites).
void main() {
  // The process CWD the runner started in. Every test restores it in
  // teardown — pre-fix, the race can leave the process in a temp root and
  // contaminate sibling tests.
  final processCwd = Directory.current.path;

  /// Removes the artifacts a PRE-FIX red run may litter into the repo
  /// (writes landing in the wrong root — the bug itself). Scoped to the
  /// exact race-probe file names so real repo files can never be touched.
  void cleanupRepoLitter() {
    final candidates = <String>[
      'race_probe_a_service.dart',
      'race_probe_b_service.dart',
      for (final tag in ['X', 'Y'])
        for (var i = 0; i < 4; i++)
          'race_iso_${tag.toLowerCase()}_round_${i}_service.dart',
    ];
    for (final name in candidates) {
      final f = File(
        p.join(processCwd, 'lib', 'src', 'domain', 'services', name),
      );
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<Directory> makeWorkspace(String prefix) async {
    final ws = await Directory.systemTemp.createTemp(prefix);
    // macOS: systemTemp hands out `/var/folders/...` while
    // `Directory.current` resolves symlinks to `/private/var/folders/...`
    // — normalize so path comparisons below are apples to apples.
    final resolved = ws.resolveSymbolicLinksSync();
    await Directory(p.join(resolved, 'lib', 'src')).create(recursive: true);
    await File(p.join(resolved, 'pubspec.yaml')).writeAsString('''
name: ${prefix.replaceAll('_', '')}
environment:
  sdk: ^3.11.0
''');
    return Directory(resolved);
  }

  /// Runs `zfa service create --json` against [ws] via [runner] and returns
  /// the parsed verdict envelope (the last `{...}` line of the output).
  Future<Map<String, dynamic>?> createServiceVerdict(
    CliRunner runner,
    String ws,
    String serviceName,
  ) async {
    final output = await runner.runCapturing([
      '-C',
      ws,
      'service',
      'create',
      '--json',
      '{"name":"$serviceName","params":"NoParams","returns":"void",'
          '"type":"usecase"}',
    ]);
    Map<String, dynamic>? verdict;
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('{')) continue;
      try {
        final value = jsonDecode(trimmed);
        if (value is Map<String, dynamic>) verdict = value;
      } catch (_) {
        // Not JSON — skip.
      }
    }
    return verdict;
  }

  tearDown(() {
    // Defensive: never let a red-state run leave the process CWD poisoned
    // for sibling suites. Assigning an absolute existing path repairs even
    // a deleted-CWD state (the read of Directory.current itself may throw
    // pre-fix, so everything here is guarded).
    try {
      Directory.current = CliRunner.nearestExistingDirectory(processCwd);
    } catch (_) {
      // Last resort — the repo root always exists.
      try {
        Directory.current = processCwd;
      } catch (_) {}
    }
    cleanupRepoLitter();
  });

  group('issue #1096 — concurrent -C chdir windows', () {
    test(
      'two concurrent invocations never hold overlapping chdir windows',
      () async {
        final wsA = await makeWorkspace('zfa_race_a_');
        final wsB = await makeWorkspace('zfa_race_b_');
        try {
          final runnerA = CliRunner(exitOnCompletion: false);
          final runnerB = CliRunner(exitOnCompletion: false);

          // Start window A, then yield once so its sync prefix settles:
          // pre-fix the chdir runs inside the invocation's sync prefix;
          // post-fix A first parks on the cross-isolate lock and chdirs one
          // microtask later. Either way, after this yield A is parked at
          // real file IO with its chdir window OPEN.
          final futureA = createServiceVerdict(runnerA, wsA.path, 'RaceProbeA');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(
            Directory.current.path,
            equals(wsA.path),
            reason: 'precondition: suite A holds the chdir window',
          );

          // Start window B without awaiting A — exactly what two dart-test
          // suites do. Because we have not yielded to the event loop, A's
          // window is still open when B's sync prefix runs.
          final futureB = createServiceVerdict(runnerB, wsB.path, 'RaceProbeB');

          // Synchronously probe whether B entered its own chdir window
          // while A is still inside its own:
          //   pre-fix:  B chdir'd over A  →  probe == wsB  (overlap — bug)
          //   post-fix: B is parked on the cross-isolate lock → probe == wsA
          final probeAfterBStart = Directory.current.path;

          final verdicts = await Future.wait([futureA, futureB]);

          expect(
            probeAfterBStart,
            isNot(equals(wsB.path)),
            reason:
                'suite B opened its chdir window while suite A was still '
                'inside its own — the process-wide Directory.current race '
                'of issue #1096 (writes land in the wrong root)',
          );
          expect(
            Directory.current.path,
            equals(processCwd),
            reason: 'both windows closed — the process CWD must be restored',
          );

          // Each suite's artifact must land in ITS OWN workspace root.
          final fileA = File(
            p.join(
              wsA.path,
              'lib',
              'src',
              'domain',
              'services',
              'race_probe_a_service.dart',
            ),
          );
          final fileB = File(
            p.join(
              wsB.path,
              'lib',
              'src',
              'domain',
              'services',
              'race_probe_b_service.dart',
            ),
          );
          expect(
            fileA.existsSync(),
            isTrue,
            reason:
                'suite A artifact must be written under suite A\'s root '
                '(pre-fix it lands under the hijacked CWD)',
          );
          expect(
            fileB.existsSync(),
            isTrue,
            reason: 'suite B artifact must be written under suite B\'s root',
          );
          expect(verdicts[0]?['ok'], isTrue);
          expect(verdicts[1]?['ok'], isTrue);
        } finally {
          if (wsA.existsSync()) wsA.deleteSync(recursive: true);
          if (wsB.existsSync()) wsB.deleteSync(recursive: true);
        }
      },
    );

    test('two isolates driving -C concurrently keep their writes isolated '
        '(dart-test suite topology)', () async {
      const rounds = 4;
      // Two "suites" — isolates of this process, like `dart test` suites.
      final results = await Future.wait([
        Isolate.run(() => isolateSuiteWorker(tag: 'X', rounds: rounds)),
        Isolate.run(() => isolateSuiteWorker(tag: 'Y', rounds: rounds)),
      ]);

      expect(
        results[0],
        isEmpty,
        reason: 'suite-isolate X must never lose a write to the CWD race',
      );
      expect(
        results[1],
        isEmpty,
        reason: 'suite-isolate Y must never lose a write to the CWD race',
      );
    });
  });
}

/// Body of one simulated test-suite isolate (issue #1096 repro topology):
/// drives its own [CliRunner] with `-C` against its own temp workspace for
/// [rounds] rounds and reports every round whose artifact did not land in
/// its own root. Mirrors `dart test` running suites as concurrent isolates
/// in one process.
Future<List<String>> isolateSuiteWorker({
  required String tag,
  required int rounds,
}) async {
  final failures = <String>[];
  // Normalize symlinks (macOS `/var` → `/private/var`) so any path
  // comparison against `Directory.current` is apples to apples.
  final ws = Directory(
    await Directory.systemTemp
        .createTemp('zfa_race_iso_${tag}_')
        .then((d) => d.resolveSymbolicLinksSync()),
  );
  try {
    await Directory(p.join(ws.path, 'lib', 'src')).create(recursive: true);
    await File(p.join(ws.path, 'pubspec.yaml')).writeAsString('''
name: zfa_race_iso_$tag
environment:
  sdk: ^3.11.0
''');
    final fallbackRoot = Directory.systemTemp.path; // always exists
    for (var i = 0; i < rounds; i++) {
      // The PathNotFoundException hazard: a sibling suite that deleted its
      // own temp workspace while the process CWD sat inside it leaves the
      // CWD unresolvable for this isolate. Detect and repair before the
      // round instead of dying with a bare PathNotFoundException.
      String? cwdNow;
      try {
        cwdNow = Directory.current.path;
      } on FileSystemException {
        cwdNow = null;
      }
      if (cwdNow == null || !Directory(cwdNow).existsSync()) {
        try {
          Directory.current = fallbackRoot;
        } catch (_) {}
        failures.add(
          'round $i: process CWD was unresolvable or pointed into a '
          'deleted directory (issue #1096 PathNotFoundException hazard)',
        );
      }
      final name = 'RaceIso${tag}Round$i';
      final snake = _camelToSnake(name);
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        '-C',
        ws.path,
        'service',
        'create',
        '--json',
        '{"name":"$name","params":"NoParams","returns":"void",'
            '"type":"usecase"}',
      ]);
      final artifact = File(
        p.join(
          ws.path,
          'lib',
          'src',
          'domain',
          'services',
          '${snake}_service.dart',
        ),
      );
      if (!artifact.existsSync()) {
        failures.add(
          'round $i: artifact for $name missing from own workspace '
          '(CWD race — write landed in another root). output head: '
          '${output.split('\n').take(4).join(' | ')}',
        );
      }
    }
  } finally {
    if (ws.existsSync()) {
      try {
        ws.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort.
      }
    }
  }
  return failures;
}

/// Same snake_case conversion as `GeneratorConfig._camelToSnake`
/// (`RaceIsoXRound0` -> `race_iso_x_round0`).
String _camelToSnake(String input) {
  final result = <String>[];
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (i > 0 && char.toUpperCase() == char && char != '_') {
      result.add('_');
    }
    result.add(char.toLowerCase());
  }
  return result.join();
}
