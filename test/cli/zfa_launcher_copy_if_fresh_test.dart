// Shell-level coverage for the `scripts/zfa` copy-if-fresh tier (issue
// #1687; PR #1688 review findings 1-5).
//
// Every test drives the REAL launcher against a throwaway fixture tree
// carrying fake "system binaries" (small bash scripts), so the tier's
// contract is pinned directly: copy-on-fresh and exec, the #1664 commit
// proof, the candidate scan (stale local install vs PATH, non-executable
// sources), copy-failure reporting, and atomic staging under concurrency.
// No test ever pays a real `dart compile exe`: the fall-through cases stop
// at the `ZFA_NO_REBUILD=1` / `package_config.json` guards.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart' show findProjectRoot;

/// A fake system binary: executable, prints a per-candidate marker so a
/// test can tell which file the launcher adopted. [padBytes] of trailing
/// comment lines (after `exit 0`, so bash never parses them) widen the copy
/// window for the concurrency test without slowing exec.
String fakeBinarySource(String id, {int padBytes = 0}) {
  const line = '# pad line\n';
  final buffer = StringBuffer(
    '#!/usr/bin/env bash\necho "FAKE-$id \$*"\nexit 0\n',
  );
  if (padBytes > 0) buffer.write(line * (padBytes ~/ line.length));
  return buffer.toString();
}

/// Executable bits (0o111) — Dart has no octal literals.
const int execBits = 73;

class LauncherRun {
  LauncherRun(this.exitCode, this.out, this.err);

  final int exitCode;
  final String out;
  final String err;
}

Future<LauncherRun> waitFor(Process process) async {
  final out = process.stdout.transform(utf8.decoder).join();
  final err = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode;
  return LauncherRun(code, await out, await err);
}

void main() {
  late String launcherSource;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    launcherSource = p.join(repoRoot, 'scripts', 'zfa');
    expect(
      File(launcherSource).existsSync(),
      isTrue,
      reason: 'scripts/zfa must exist to exercise the copy tier',
    );
  });

  late Directory fixture;
  late String root;
  late Directory homeA;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('zfa_launcher_');
    root = fixture.path;
    homeA = Directory(p.join(root, 'home'))..createSync(recursive: true);
    final scriptsDir = Directory(p.join(root, 'scripts'))..createSync();
    File(launcherSource).copySync(p.join(scriptsDir.path, 'zfa'));
  });

  tearDown(() {
    if (fixture.existsSync()) fixture.deleteSync(recursive: true);
  });

  DateTime past() => DateTime.now().subtract(const Duration(hours: 2));

  /// The freshness inputs (bin/, lib/src/, pubspec pair), backdated so a
  /// "now"-stamped candidate reads fresh — the same contract the launcher's
  /// `needs_build` uses.
  void writeInputs() {
    for (final file in [
      File(p.join(root, 'bin', 'zfa.dart')),
      File(p.join(root, 'lib', 'src', 'cli.dart')),
      File(p.join(root, 'pubspec.yaml')),
      File(p.join(root, 'pubspec.lock')),
    ]) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('// freshness input\n');
      file.setLastModifiedSync(past());
    }
  }

  /// Writes a fake candidate binary and returns it. [home] defaults to the
  /// `~/.local/bin/zfa` slot of [homeA]; [path] overrides the location (the
  /// PATH candidate).
  File writeCandidate(
    String id, {
    required DateTime at,
    Directory? home,
    String? path,
    bool executable = true,
    int padBytes = 0,
  }) {
    final file = File(
      path ?? p.join((home ?? homeA).path, '.local', 'bin', 'zfa'),
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(fakeBinarySource(id, padBytes: padBytes));
    file.setLastModifiedSync(at);
    Process.runSync('chmod', [executable ? '+x' : '-x', file.path]);
    return file;
  }

  Map<String, String> launcherEnv({
    Directory? home,
    Map<String, String> extra = const {},
  }) => {
    'HOME': (home ?? homeA).path,
    // Fixture-first PATH: whatever the machine has installed must not leak
    // into `command -v zfa` (or into git/find resolution).
    'PATH': '${p.join(root, 'pathbin')}:/usr/bin:/bin',
    'ZFA_NO_REBUILD': '',
    ...extra,
  };

  String launcherPath() => p.join(root, 'scripts', 'zfa');

  LauncherRun runLauncher({
    Directory? home,
    Map<String, String> extra = const {},
    List<String> args = const ['--version'],
  }) {
    final result = Process.runSync('/bin/bash', [
      launcherPath(),
      ...args,
    ], environment: launcherEnv(home: home, extra: extra));
    return LauncherRun(
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }

  File cachedArtifact() =>
      File(p.join(root, '.dart_tool', 'zfa_cli_bin', 'zfa_exe'));

  void gitInitFixture() {
    for (final args in [
      ['init', '-q'],
      ['config', 'user.email', 'fixture@example.com'],
      ['config', 'user.name', 'Fixture'],
      ['add', '-A'],
      ['commit', '-qm', 'fixture'],
    ]) {
      final result = Process.runSync('git', args, workingDirectory: root);
      expect(
        result.exitCode,
        0,
        reason: 'git ${args.join(' ')}: ${result.stderr}',
      );
    }
  }

  String gitHead() {
    final result = Process.runSync('git', [
      'rev-parse',
      'HEAD',
    ], workingDirectory: root);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result.stdout.toString().trim();
  }

  test('copies a fresh system binary into the cache and execs it', () {
    writeInputs();
    writeCandidate('LOCAL', at: DateTime.now());

    final result = runLauncher();

    expect(result.exitCode, 0, reason: result.err);
    expect(result.out, contains('FAKE-LOCAL'));
    expect(result.err, contains('copied fresh system binary'));
    expect(result.err, isNot(contains('🔨 compiling zfa')));
    final cached = cachedArtifact();
    expect(cached.existsSync(), isTrue);
    expect(cached.readAsStringSync(), fakeBinarySource('LOCAL'));
    expect((cached.statSync().mode & execBits) != 0, isTrue);
  });

  test(
    'a stale system binary falls through, and ZFA_NO_REBUILD=1 fails loudly',
    () {
      writeInputs();
      writeCandidate('LOCAL', at: past().subtract(const Duration(hours: 1)));

      final result = runLauncher(extra: {'ZFA_NO_REBUILD': '1'});

      expect(result.exitCode, 1);
      expect(
        result.err,
        contains('ZFA_NO_REBUILD=1 but no fresh system binary available'),
      );
      expect(result.err, isNot(contains('copied fresh system binary')));
      expect(cachedArtifact().existsSync(), isFalse);
    },
  );

  test('a stale local install does not shadow a fresher PATH binary', () {
    writeInputs();
    writeCandidate('LOCAL', at: past().subtract(const Duration(hours: 1)));
    final pathCandidate = writeCandidate(
      'PATHBIN',
      at: DateTime.now(),
      path: p.join(root, 'pathbin', 'zfa'),
    );

    final result = runLauncher();

    expect(result.exitCode, 0, reason: result.err);
    expect(result.out, contains('FAKE-PATHBIN'));
    expect(
      result.err,
      contains('copied fresh system binary (${pathCandidate.path})'),
    );
  });

  test('a non-executable candidate is skipped, not copied into the cache', () {
    writeInputs();
    writeCandidate('LOCAL', at: DateTime.now(), executable: false);

    final result = runLauncher(extra: {'ZFA_NO_REBUILD': '1'});

    expect(result.exitCode, 1);
    expect(result.err, contains('ZFA_NO_REBUILD=1'));
    expect(cachedArtifact().existsSync(), isFalse);
  });

  test('a copy that cannot succeed is reported as failure, not success', () {
    if (Process.runSync('id', ['-u']).stdout.toString().trim() == '0') {
      markTestSkipped('root bypasses the permission bits this test needs');
      return;
    }
    writeInputs();
    // An executable-but-unreadable (mode 0111) candidate passes the old
    // `-f`/`-x` gates and starts a `cp` that fails with EACCES. The pre-fix
    // shape still printed "copied fresh system binary" and exec'd a missing
    // artifact (finding 1); the fix must fall through to the compile branch.
    final unreadable = writeCandidate('LOCAL', at: DateTime.now());
    Process.runSync('chmod', ['111', unreadable.path]);

    final result = runLauncher();

    expect(result.exitCode, 1);
    expect(result.err, isNot(contains('copied fresh system binary')));
    expect(result.err, contains('package_config.json is missing'));
    expect(cachedArtifact().existsSync(), isFalse);
  });

  test('a matching zfa.build_commit marker is adopted (the #1664 proof)', () {
    writeInputs();
    gitInitFixture();
    final candidate = writeCandidate('LOCAL', at: DateTime.now());
    File(
      p.join(candidate.parent.path, 'zfa.build_commit'),
    ).writeAsStringSync('${gitHead()}\n');

    final result = runLauncher();

    expect(result.exitCode, 0, reason: result.err);
    expect(result.out, contains('FAKE-LOCAL'));
    expect(result.err, contains('copied fresh system binary'));
  });

  test('a disagreeing zfa.build_commit marker rejects the candidate', () {
    writeInputs();
    gitInitFixture();
    final candidate = writeCandidate('LOCAL', at: DateTime.now());
    File(
      p.join(candidate.parent.path, 'zfa.build_commit'),
    ).writeAsStringSync('${'0' * 40}\n');

    final result = runLauncher(extra: {'ZFA_NO_REBUILD': '1'});

    expect(result.exitCode, 1);
    expect(result.err, contains('ZFA_NO_REBUILD=1'));
    expect(result.err, isNot(contains('copied fresh system binary')));
    expect(cachedArtifact().existsSync(), isFalse);
  });

  test('an unresolvable zfa.build_commit marker rejects the candidate', () {
    writeInputs();
    // No git checkout at the fixture root: HEAD cannot be proven, so a
    // marker present on disk must not authorize the copy.
    final candidate = writeCandidate('LOCAL', at: DateTime.now());
    File(
      p.join(candidate.parent.path, 'zfa.build_commit'),
    ).writeAsStringSync('${'a' * 40}\n');

    final result = runLauncher(extra: {'ZFA_NO_REBUILD': '1'});

    expect(result.exitCode, 1);
    expect(result.err, contains('ZFA_NO_REBUILD=1'));
    expect(result.err, isNot(contains('copied fresh system binary')));
  });

  test('concurrent cold launches never publish a partial artifact', () async {
    writeInputs();
    // Large, identical-size payloads widen the copy window so a shared
    // staging path would reliably collide (the pre-fix shape errored in
    // 7/8 rounds at this size; see the PR's #1688 review).
    const payload = 33 * 1024 * 1024;
    writeCandidate('A', at: DateTime.now(), padBytes: payload);
    final homeB = Directory(p.join(root, 'home-b'))
      ..createSync(recursive: true);
    writeCandidate('B', at: DateTime.now(), home: homeB, padBytes: payload);
    final candidates = {
      fakeBinarySource('A', padBytes: payload),
      fakeBinarySource('B', padBytes: payload),
    };

    for (var round = 0; round < 5; round++) {
      final cacheDir = cachedArtifact().parent;
      if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      final first = await Process.start('/bin/bash', [
        launcherPath(),
        '--version',
      ], environment: launcherEnv());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = await Process.start('/bin/bash', [
        launcherPath(),
        '--version',
      ], environment: launcherEnv(home: homeB));
      final results = await Future.wait([waitFor(first), waitFor(second)]);
      for (final result in results) {
        expect(result.exitCode, 0, reason: result.err);
        expect(result.err, isNot(contains('mv:')), reason: result.err);
        expect(result.err, isNot(contains('cp:')), reason: result.err);
      }
      final cached = cachedArtifact();
      expect(cached.existsSync(), isTrue);
      expect(
        candidates,
        contains(cached.readAsStringSync()),
        reason: 'the published artifact must be one complete candidate',
      );
    }
  });
}
