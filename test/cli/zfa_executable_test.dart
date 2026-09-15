@Tags(['e2e'])
/// Unit suite for `ZfaExecutable` — the no-JIT compiled-child contract.
///
/// Policy under test: NOTHING spawns the zfa CLI in JIT mode. A `.dart`
/// entrypoint is AOT compiled once into the shared
/// `<root>/.dart_tool/zfa_cli_bin/zfa_exe` cache (the same artifact the
/// test helper `run_zfa_source.dart` uses); a compile that cannot happen
/// throws instead of degrading to `dart <script>`; the only escape hatch
/// is `ZFA_ALLOW_JIT=1`.
///
/// Behaviors:
/// U1  non-.dart candidate passes through unchanged (fake bins / compiled
///     binaries keep their legacy behavior)
/// U2  a `.dart` candidate is compiled through the injected runner with
///     the agreed argv, cwd, tmp-then-rename staging and cache path
/// U3  a fresh cache is reused (no compiler call)
/// U4  a newer file under `lib/` invalidates the cache
/// U5  a newer `pubspec.yaml` / `pubspec.lock` invalidates the cache
/// U6  a failed compile throws `ZfaCompilationException` — never a JIT
///     fallback — carrying the command, exit code and stderr tail
/// U7  a "successful" compile that wrote no artifact throws too
/// U8  `ZFA_ALLOW_JIT=1` returns the `.dart` path after ONE warning line
/// U9  the source root is derived from `<root>/bin/zfa.dart`, or from the
///     nearest package root above any other `.dart` candidate; a candidate
///     with no package above it anchors on its own directory — an explicit
///     `--zfa-bin <path>.dart` is always COMPILED, never refused, and each
///     non-canonical entrypoint gets its own cache slot
/// U10 `commandFor` shapes the child argv and throws without the hatch
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/zfa_executable.dart';

/// A compiler fake: records every invocation and writes the `--output`
/// artifact so the tmp→rename staging path is exercised for real.
class _FakeCompiler {
  _FakeCompiler({this.exitCode = 0, this.stderr = '', this.writeOutput = true});

  final List<List<String>> calls = [];
  final List<String> workingDirectories = [];
  int exitCode;
  String stderr;
  bool writeOutput;

  Future<ProcessResult> call(List<String> argv, String workingDirectory) async {
    calls.add(argv);
    workingDirectories.add(workingDirectory);
    if (exitCode == 0 && writeOutput) {
      final outputIndex = argv.indexOf('--output');
      await File(argv[outputIndex + 1]).writeAsString('compiled:$outputIndex');
    }
    return ProcessResult(1, exitCode, '', stderr);
  }
}

/// Capture `print` output inside [body] (the escape hatch logs one line).
Future<(T, List<String>)> _capturePrint<T>(Future<T> Function() body) async {
  final lines = <String>[];
  late final T result;
  await runZoned(
    () async {
      result = await body();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return (result, lines);
}

Future<Directory> _sourceRoot(String tag) async {
  final dir = await Directory.systemTemp.createTemp('zfa_exec_${tag}_');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  await File(
    p.join(dir.path, 'bin', 'zfa.dart'),
  ).create(recursive: true).then((f) => f.writeAsString('void main() {}\n'));
  await File(
    p.join(dir.path, 'lib', 'x.dart'),
  ).create(recursive: true).then((f) => f.writeAsString('// x\n'));
  await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('name: fixture\n');
  return dir;
}

String _exePath(Directory root) =>
    p.join(root.path, p.joinAll(kZfaBinaryCacheDir), kZfaBinaryName);

/// Push [path]'s mtime ahead of everything written so far, so a staleness
/// check cannot be defeated by same-second filesystem timestamps.
void _touchNewer(String path) {
  final file = File(path);
  file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
}

void main() {
  group('ensureCompiled — pass-through', () {
    test(
      'U1: a non-.dart candidate is returned unchanged (no compile)',
      () async {
        final compiler = _FakeCompiler();
        final result = await ZfaExecutable.ensureCompiled(
          '/usr/local/bin/zfa',
          runner: compiler.call,
        );
        expect(result, '/usr/local/bin/zfa');
        expect(compiler.calls, isEmpty);

        // The `--zfa-bin <bash script>` fixture shape must survive verbatim.
        final script = await ZfaExecutable.ensureCompiled(
          '/tmp/fake_bin/zfa',
          runner: compiler.call,
        );
        expect(script, '/tmp/fake_bin/zfa');
        expect(compiler.calls, isEmpty);
      },
    );
  });

  group('ensureCompiled — compile + cache', () {
    test('U2: compiles the source into the shared cache path', () async {
      final root = await _sourceRoot('compile');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler();

      final result = await ZfaExecutable.ensureCompiled(
        candidate,
        runner: compiler.call,
      );

      expect(result, _exePath(root));
      final argv = compiler.calls.single;
      expect(argv.take(3), ['dart', 'compile', 'exe']);
      expect(argv[3], candidate);
      expect(argv[4], '--output');
      // Staged to the tmp sibling, then renamed into place (issue #644).
      expect(p.basename(argv[5]), kZfaBinaryTmpName);
      expect(p.dirname(argv[5]), p.dirname(_exePath(root)));
      expect(compiler.workingDirectories.single, root.path);
      expect(File(_exePath(root)).readAsStringSync(), isNotEmpty);
      expect(File(argv[5]).existsSync(), isFalse, reason: 'tmp was renamed');
    });

    test('U3: a fresh cache is reused without invoking the compiler', () async {
      final root = await _sourceRoot('reuse');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler();

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      final second = await ZfaExecutable.ensureCompiled(
        candidate,
        runner: compiler.call,
      );

      expect(second, _exePath(root));
      expect(compiler.calls, hasLength(1), reason: 'the cache was reused');
    });

    test('U4: a newer file under lib/ invalidates the cache', () async {
      final root = await _sourceRoot('stale_lib');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler();

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      _touchNewer(p.join(root.path, 'lib', 'x.dart'));

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      expect(compiler.calls, hasLength(2), reason: 'the lib change rebuilt');
    });

    test('U5: a newer pubspec.yaml invalidates the cache', () async {
      final root = await _sourceRoot('stale_pubspec');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler();

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      _touchNewer(p.join(root.path, 'pubspec.yaml'));

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      expect(compiler.calls, hasLength(2));
    });

    test('U5: a newer pubspec.lock invalidates the cache', () async {
      final root = await _sourceRoot('stale_lock');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler();

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      await File(p.join(root.path, 'pubspec.lock')).writeAsString('# lock\n');
      _touchNewer(p.join(root.path, 'pubspec.lock'));

      await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
      expect(compiler.calls, hasLength(2));
    });

    test('U6: a failed compile throws — never a JIT fallback', () async {
      final root = await _sourceRoot('fail');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler(exitCode: 254, stderr: 'boom\n');

      await expectLater(
        ZfaExecutable.ensureCompiled(candidate, runner: compiler.call),
        throwsA(
          isA<ZfaCompilationException>()
              .having((e) => e.exitCode, 'exitCode', 254)
              .having((e) => e.stderrTail, 'stderrTail', contains('boom'))
              .having(
                (e) => e.command,
                'command',
                contains('compile exe $candidate'),
              ),
        ),
      );
      expect(File(_exePath(root)).existsSync(), isFalse);
    });

    test('U6: the stderr tail is capped at ~20 lines', () async {
      final root = await _sourceRoot('tail');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler(
        exitCode: 1,
        stderr: List.generate(30, (i) => 'line$i').join('\n'),
      );

      try {
        await ZfaExecutable.ensureCompiled(candidate, runner: compiler.call);
        fail('expected a ZfaCompilationException');
      } on ZfaCompilationException catch (e) {
        expect(e.stderrTail.split('\n'), hasLength(20));
        expect(e.stderrTail, contains('line29'));
        expect(e.stderrTail, isNot(contains('line9\n')));
      }
    });

    test('U7: success with no artifact throws', () async {
      final root = await _sourceRoot('noout');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler(writeOutput: false);

      await expectLater(
        ZfaExecutable.ensureCompiled(candidate, runner: compiler.call),
        throwsA(
          isA<ZfaCompilationException>().having(
            (e) => e.reason,
            'reason',
            contains('wrote no artifact'),
          ),
        ),
      );
    });

    test('U11: a compile that misses its budget deadline raises a loud '
        'diagnostic naming the scale remedy', () async {
      // Issue #1623's exact scenario: `dart compile exe` outlives the
      // budget (2m38s measured on the slow host) and is killed at the
      // deadline. The diagnostic must name the budget AND the
      // ZFA_TEST_TIMEOUT_SCALE remedy — never degrade silently.
      final root = await _sourceRoot('deadline');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');

      Future<ProcessResult> neverInTime(
        List<String> argv,
        String workingDirectory,
      ) async {
        throw TimeoutException('simulated budget kill');
      }

      await expectLater(
        ZfaExecutable.ensureCompiled(candidate, runner: neverInTime),
        throwsA(
          isA<ZfaCompilationException>()
              .having((e) => e.exitCode, 'exitCode', -1)
              .having(
                (e) => e.reason,
                'reason',
                allOf(
                  contains('exceeded its'),
                  contains('budget'),
                  contains(kZfaTimeoutScaleEnv),
                ),
              ),
        ),
      );
      expect(File(_exePath(root)).existsSync(), isFalse);
    });
  });

  group('ensureCompiled — escape hatch + source root', () {
    test(
      'U8: ZFA_ALLOW_JIT=1 returns the .dart path with ONE warning',
      () async {
        final root = await _sourceRoot('jit');
        final candidate = p.join(root.path, 'bin', 'zfa.dart');
        final compiler = _FakeCompiler();

        final (result, lines) = await _capturePrint(
          () => ZfaExecutable.ensureCompiled(
            candidate,
            runner: compiler.call,
            environment: const {kZfaAllowJitEnv: '1'},
          ),
        );

        expect(result, candidate);
        expect(compiler.calls, isEmpty, reason: 'no compile under the hatch');
        expect(lines, hasLength(1));
        expect(lines.single, contains(kZfaAllowJitEnv));
      },
    );

    test('U8: any other ZFA_ALLOW_JIT value keeps the policy', () async {
      final root = await _sourceRoot('jit_off');
      final candidate = p.join(root.path, 'bin', 'zfa.dart');
      final compiler = _FakeCompiler();

      await ZfaExecutable.ensureCompiled(
        candidate,
        runner: compiler.call,
        environment: const {kZfaAllowJitEnv: 'true'},
      );
      expect(compiler.calls, hasLength(1));
    });

    test('U9: the source root is derived from <root>/bin/zfa.dart', () async {
      final root = await _sourceRoot('derive');
      expect(
        ZfaExecutable.sourceRootOf(p.join(root.path, 'bin', 'zfa.dart')),
        root.path,
      );
      expect(
        ZfaExecutable.sourceRootOf(p.join(root.path, 'bin', 'zuraffa.dart')),
        root.path,
      );
    });

    test('U9: any other .dart candidate anchors on its own package root — an '
        'explicit --zfa-bin <path>.dart is compiled, never refused', () async {
      final root = await _sourceRoot('derive_pkg');
      final candidate = p.join(root.path, 'tool', 'probe.dart');
      await File(candidate)
          .create(recursive: true)
          .then((f) => f.writeAsString('void main() {}\n'));
      expect(ZfaExecutable.sourceRootOf(candidate), root.path);

      final compiler = _FakeCompiler();
      final result = await ZfaExecutable.ensureCompiled(
        candidate,
        runner: compiler.call,
      );

      // Anchored on the candidate's package, in its OWN cache slot: the
      // canonical `<root>/.dart_tool/zfa_cli_bin/zfa_exe` artifact is left
      // untouched, so two overrides in one package never share a binary.
      expect(p.dirname(result), p.dirname(_exePath(root)));
      expect(result, isNot(_exePath(root)));
      expect(p.basename(result), startsWith('${kZfaBinaryName}_'));
      expect(compiler.workingDirectories.single, root.path);
      expect(File(result).readAsStringSync(), isNotEmpty);
    });

    test('U9: a candidate with no package above it still compiles against '
        'its own directory (no silent JIT)', () async {
      final loose = Directory.systemTemp.createTempSync('zfa_exec_loose_');
      addTearDown(() {
        if (loose.existsSync()) loose.deleteSync(recursive: true);
      });
      final candidate = p.join(loose.path, 'probe.dart');
      await File(candidate).writeAsString('void main() {}\n');
      expect(ZfaExecutable.sourceRootOf(candidate), isNull);

      final compiler = _FakeCompiler();
      final result = await ZfaExecutable.ensureCompiled(
        candidate,
        runner: compiler.call,
      );

      expect(
        p.dirname(result),
        p.join(loose.path, p.joinAll(kZfaBinaryCacheDir)),
      );
      expect(compiler.workingDirectories.single, loose.path);
      expect(
        ZfaExecutable.isDartScript(result),
        isFalse,
        reason: 'the returned entrypoint is always a compiled artifact',
      );
    });

    test('U9: an explicit sourceRoot overrides the derivation', () async {
      final root = await _sourceRoot('explicit');
      final candidate = p.join(root.path, 'elsewhere', 'zfa.dart');
      await File(candidate).create(recursive: true);
      final compiler = _FakeCompiler();

      final result = await ZfaExecutable.ensureCompiled(
        candidate,
        sourceRoot: root.path,
        runner: compiler.call,
      );
      // The explicit root anchors the cache; the SLOT name follows the
      // entrypoint (a non-canonical candidate gets a digest slot of its
      // own), so the directory is what the override pins.
      expect(p.dirname(result), p.dirname(_exePath(root)));
      expect(compiler.workingDirectories.single, root.path);
    });
  });

  group('commandFor — the spawn shape', () {
    test('U10: a compiled entry spawns directly', () {
      expect(ZfaExecutable.commandFor('/usr/local/bin/zfa', const ['build']), [
        '/usr/local/bin/zfa',
        'build',
      ]);
    });

    test('U10: the dart prefix is reachable ONLY under the hatch', () {
      expect(
        ZfaExecutable.commandFor(
          '/pkg/bin/zfa.dart',
          const ['build'],
          environment: const {kZfaAllowJitEnv: '1'},
        ),
        ['dart', '/pkg/bin/zfa.dart', 'build'],
      );
      expect(
        () => ZfaExecutable.commandFor('/pkg/bin/zfa.dart', const [
          'build',
        ], environment: const {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('refusing to spawn the zfa CLI in JIT mode'),
          ),
        ),
      );
    });
  });

  test('isDartScript only classifies Dart SOURCE entrypoints', () {
    expect(ZfaExecutable.isDartScript('/a/bin/zfa.dart'), isTrue);
    expect(ZfaExecutable.isDartScript('/a/bin/zfa'), isFalse);
    expect(ZfaExecutable.isDartScript('/a/bin/zfa.dart.snapshot'), isFalse);
  });
}
