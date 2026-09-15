@TestOn('linux || mac-os')
@Tags(['regression', 'slow'])
// Issue #1642 — the kernel sweep's family and the full-suite disk preflight.
//
// The #1507/#1520 janitor sweeps `dart_test.kernel.*` (and `zfa-*` scratch)
// with a four-guard stack, but two of the issue's three requested fixes are
// still open:
//
//   C1 — the sweep covers the `flutter_tools.*` orphan family too (incident
//        1: six 264 MB dirs with 138 MB `listener.dart.dill` files from hung
//        `flutter test` runs sat next to the kernel orphans, unreclaimed);
//   C2 — a stale `flutter_tools.*` dir is reclaimed recursively, exactly
//        like a kernel dir (same guard stack: fresh survives, live-referenced
//        survives);
//   C3 — the disk preflight refuses a full-suite sweep whose estimated temp
//        footprint (suites × measured per-suite snapshot bytes + margin)
//        exceeds the free space, with a `--> fix:` remedy instead of an
//        ENOSPC death mid-sweep (incident 2: 47 GB written, disk exhausted,
//        run killed, everything leaked);
//   C4 — the preflight's `df -k` parsing reads the POSIX free-bytes column
//        hermetically (no real volume touched);
//   C5 — the margin is honored at the boundary (free == estimate without
//        margin fails; free == estimate + margin passes).
//
// Fixture discipline (bug #1507 pattern): hermetic temp roots injected via
// the environment; mtimes backdated; the liveness probe overridden with an
// explicit set so no real process scan runs.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/kernel_cache.dart';

/// The sweep instant — always the REAL clock: the fixtures backdate
/// mtimes relative to DateTime.now(), so a fixed past `now` would put the
/// age floor after every real mtime and the guards would misfire.
DateTime get now => DateTime.now();

void main() {
  late Directory root;
  late Map<String, String> env;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bug1642_');
    env = {'TMPDIR': root.path};
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// Seed a `flutter_tools.*` dir of [age], mtime backdated with the one
  /// stamp shape both GNU and BSD `touch` accept (the bug #1507 pattern —
  /// `touch -d @<epoch>` silently keeps "now" on macOS/BSD, which would
  /// leave the fixture non-stale).
  Directory seedToolDir(
    String name, {
    required Duration age,
    int dillFiles = 2,
  }) {
    final dir = Directory(p.join(root.path, name))..createSync(recursive: true);
    for (var i = 0; i < dillFiles; i++) {
      File(
        p.join(dir.path, 'listener$i.dart.dill'),
      ).writeAsStringSync('x' * 1024);
    }
    final old = DateTime.now().subtract(age);
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${old.year}${two(old.month)}${two(old.day)}'
        '${two(old.hour)}${two(old.minute)}.${two(old.second)}';
    final touch = Process.runSync('touch', ['-t', stamp, dir.path]);
    if (touch.exitCode != 0) {
      fail('could not backdate $name on ${dir.path}: ${touch.stderr}');
    }
    return dir;
  }

  test(
    'C1: a stale flutter_tools.* dir is reclaimed by the startup sweep',
    () async {
      final orphan = seedToolDir(
        'flutter_tools.abc123',
        age: const Duration(hours: 2),
      );
      await clearDartTestKernelCache(
        root.path,
        commandStartedAt: now,
        environment: env,
        now: now,
      );
      expect(orphan.existsSync(), isFalse, reason: 'the orphan is reclaimed');
    },
  );

  test('C2a: a fresh flutter_tools.* dir survives the sweep', () async {
    final fresh = seedToolDir(
      'flutter_tools.fresh',
      age: const Duration(minutes: 5),
    );
    await clearDartTestKernelCache(
      root.path,
      commandStartedAt: now,
      environment: env,
      now: now,
    );
    expect(fresh.existsSync(), isTrue, reason: 'a concurrent run may own it');
  });

  test(
    'C2b: a live-referenced flutter_tools.* dir survives the sweep',
    () async {
      final live = seedToolDir(
        'flutter_tools.live1',
        age: const Duration(hours: 2),
      );
      await clearDartTestKernelCache(
        root.path,
        commandStartedAt: now,
        environment: env,
        now: now,
        liveKernelDirs: {p.canonicalize(live.path)},
      );
      expect(
        live.existsSync(),
        isTrue,
        reason: 'a live process argv references this dir — never garbage',
      );
    },
  );

  test(
    'C3: the preflight refuses a footprint over free space with a remedy',
    () async {
      final message = diskPreflightMessage(freeBytes: 1 << 30, suiteCount: 765);
      expect(message, isNotNull);
      expect(message, contains('--> fix:'));
      expect(message, contains('765'));
    },
  );

  test(
    'C3b: a scoped-sufficed volume passes the preflight (null message)',
    () async {
      expect(
        diskPreflightMessage(freeBytes: 60 << 30, suiteCount: 765),
        isNull,
      );
    },
  );

  test('C5: the margin is honored at the boundary', () async {
    const perSuite = 69 << 20;
    const margin = 2 << 30;
    final estimate = 765 * perSuite;
    // Exactly the estimate without the margin: still refused.
    expect(
      diskPreflightMessage(
        freeBytes: estimate,
        suiteCount: 765,
        perSuiteBytes: perSuite,
        marginBytes: margin,
      ),
      isNotNull,
    );
    // Estimate + margin exactly: passes.
    expect(
      diskPreflightMessage(
        freeBytes: estimate + margin,
        suiteCount: 765,
        perSuiteBytes: perSuite,
        marginBytes: margin,
      ),
      isNull,
    );
  });

  test(
    'C4: the df -k free-bytes parser reads the POSIX column hermetically',
    () async {
      const output = '''
Filesystem     1K-blocks      Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk1s4s1 244121328 105678288 137295040    44% 1287967 1372167533    0%   /
''';
      expect(freeBytesFromDfOutput(output), 137295040 * 1024);
    },
  );

  // C6 — the preflight's fail-open branches (PR #1650 review finding 2):
  // FR-003's "the preflight is skipped when free space cannot be
  // determined" lives entirely on these paths — every one of them must
  // return null (go, unguarded) instead of throwing or refusing. The
  // `dfRunner` stub makes the branch hermetic: no real volume, no real
  // process; a stub that throws StateError proves `df` never even spawns.
  group('C6: fullSuiteBaselinePreflight fail-open branches', () {
    /// A `ProcessResult` shaped like a real `df -k <path>` run.
    ProcessResult dfRun(int exitCode, String stdout) =>
        ProcessResult(0, exitCode, stdout, '');

    const dfBlock = '''
Filesystem     1K-blocks      Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk1s4s1 244121328 105678288 137295040    44% 1287967 1372167533    0%   /
''';

    void seedSuites(int n) {
      final testDir = Directory(p.join(root.path, 'test'))
        ..createSync(recursive: true);
      for (var i = 0; i < n; i++) {
        File(
          p.join(testDir.path, 'suite${i}_test.dart'),
        ).writeAsStringSync('void main() {}');
      }
    }

    test(
      'C6a: a missing test/ dir skips the preflight (df never spawns)',
      () async {
        expect(
          await fullSuiteBaselinePreflight(
            root.path,
            environment: env,
            dfRunner: (args) => throw StateError('df must not spawn'),
          ),
          isNull,
        );
      },
    );

    test(
      'C6b: a suite-less tree skips the preflight (df never spawns)',
      () async {
        Directory(p.join(root.path, 'test')).createSync(recursive: true);
        File(
          p.join(root.path, 'test', 'helpers.dart'),
        ).writeAsStringSync('void f() {}');
        expect(
          await fullSuiteBaselinePreflight(
            root.path,
            environment: env,
            dfRunner: (args) => throw StateError('df must not spawn'),
          ),
          isNull,
        );
      },
    );

    test('C6c: a nonzero df exit skips the preflight (null)', () async {
      seedSuites(2);
      expect(
        await fullSuiteBaselinePreflight(
          root.path,
          environment: env,
          dfRunner: (args) async => dfRun(1, ''),
        ),
        isNull,
      );
    });

    test('C6d: unparseable df output skips the preflight (null)', () async {
      seedSuites(2);
      expect(
        await fullSuiteBaselinePreflight(
          root.path,
          environment: env,
          dfRunner: (args) async => dfRun(0, 'not a df block\n'),
        ),
        isNull,
      );
    });

    test('C6e: an unlaunchable df (ProcessException) skips the preflight '
        '(review finding 1 regression — never a crash)', () async {
      seedSuites(2);
      expect(
        await fullSuiteBaselinePreflight(
          root.path,
          environment: env,
          dfRunner: (args) =>
              throw const ProcessException('df', ['-k'], 'no such binary'),
        ),
        isNull,
      );
    });

    test(
      'C6f: a fixture tree with ample free space passes (null message)',
      () async {
        seedSuites(2);
        expect(
          await fullSuiteBaselinePreflight(
            root.path,
            environment: env,
            dfRunner: (args) async => dfRun(0, dfBlock),
          ),
          isNull,
        );
      },
    );

    test(
      'C6g: a fixture tree over the estimate is refused with a remedy',
      () async {
        seedSuites(2);
        final message = await fullSuiteBaselinePreflight(
          root.path,
          environment: env,
          dfRunner: (args) async => dfRun(
            0,
            'Filesystem 1K-blocks Used Available Capacity Mounted on\n'
            '/dev/disk1 244121328 105678288 1024 44% /\n',
          ),
        );
        expect(message, isNotNull);
        expect(message, contains('--> fix:'));
        expect(message, contains('2 suites'));
      },
    );
  });
}
