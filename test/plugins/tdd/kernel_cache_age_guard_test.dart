@TestOn('linux || mac-os')
@Tags(['regression'])
// Spec 1520 — the age-guarded, dir-aware janitor (issue #1520).
//
// The #1515 sweep deletes `$TMPDIR/dart_test.kernel.*` entries whose mtime
// is older than the command start. That guard protects THIS command's
// window, but an entry five minutes old — left by an agent that has since
// crashed — is still deleted, and it may still be referenced. The janitor
// must therefore refuse ANYTHING younger than ~1 hour (the age floor):
//
//   B10 — a kernel DIRECTORY older than the command start but younger than
//         the age floor SURVIVES the sweep (pre-spec: deleted).
//   B11 — a kernel DIRECTORY and FILE older than the age floor are swept
//         exactly as before (directories recursively) — the floor does not
//         disable the janitor (#1507 preserved).
//   B12 — an entry modified after the command start survives regardless of
//         age — the #1507 commandStartedAt guard still wins.
//   B13 — the sweep covers the configured scratch root (ZFA_TMPDIR)
//         alongside the ambient TMPDIR root, under the same guard stack.
//
// The sweep contract is exercised through the injected knobs (environment /
// now / ageGuard) so no shared-user-TMPDIR state is ever touched and no
// fixture backdating is needed: entries are created NOW, and the injected
// `now` makes them old or young relative to the guard.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/kernel_cache.dart';

void main() {
  late Directory sandbox;
  late Directory ambientRoot;

  /// Seed a `dart_test.kernel.<name>` DIRECTORY holding one dill-shaped
  /// file, mtime = now (the injected clock decides how old it is).
  Directory seedKernelDir(String name) {
    final dir = Directory(p.join(ambientRoot.path, 'dart_test.kernel.$name'))
      ..createSync(recursive: true);
    File(
      p.join(dir.path, 'output.dill'),
    ).writeAsBytesSync(List.filled(64 * 1024, 120));
    return dir;
  }

  /// Seed a bare `dart_test.kernel.<name>` FILE, mtime = now.
  File seedKernelFile(String name) {
    return File(p.join(ambientRoot.path, 'dart_test.kernel.$name'))
      ..writeAsBytesSync(List.filled(64 * 1024, 120));
  }

  /// Seed a `zfa-<name>-<rand>` scratch DIRECTORY (spec 1520 FR-1) — the
  /// debris a run that died before its `finally` leaves behind — with an
  /// optional nested `dart_test.kernel.*` child (mtime = now).
  Directory seedScratchDir(String name, {bool withKernel = false}) {
    final dir = Directory(p.join(ambientRoot.path, 'zfa-$name-rand'))
      ..createSync(recursive: true);
    if (withKernel) {
      final kernel = Directory(p.join(dir.path, 'dart_test.kernel.live'))
        ..createSync(recursive: true);
      File(
        p.join(kernel.path, 'output.dill'),
      ).writeAsBytesSync(List.filled(64 * 1024, 120));
    }
    return dir;
  }

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('zfa1520-janitor-');
    ambientRoot = Directory(p.join(sandbox.path, 'ambient-tmp'))
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  group('B10: the age floor keeps young pre-start entries', () {
    test('a kernel dir older than the command start but younger than the '
        'age floor survives the sweep', () async {
      final youngDir = seedKernelDir('young-1520');

      // The entry's real mtime is NOW. The command started 1s later (so the
      // pre-#1520 mtime guard calls it stale-eligible) but the injected
      // sweep instant is only 10s later — 10s of age is far under the 1h
      // floor, so the entry may still belong to someone.
      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().add(const Duration(seconds: 1)),
        environment: {'TMPDIR': ambientRoot.path},
        now: DateTime.now().add(const Duration(seconds: 10)),
      );

      expect(
        youngDir.existsSync(),
        isTrue,
        reason:
            'a dart_test.kernel.* entry younger than ~1h may belong '
            'to a concurrent runner — the janitor must not delete it '
            '(spec 1520 FR-5 / SC-3; pre-spec the entry is deleted)',
      );
    });
  });

  group('B11: the age floor does not disable the janitor', () {
    test('a kernel dir AND file past the age floor are swept — dirs '
        'recursively', () async {
      final oldDir = seedKernelDir('old-dir-1520');
      final oldFile = seedKernelFile('old-file-1520');

      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().add(const Duration(seconds: 1)),
        environment: {'TMPDIR': ambientRoot.path},
        now: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(
        oldDir.existsSync(),
        isFalse,
        reason:
            'a genuinely stale kernel DIRECTORY is reclaimed '
            '(#1507 preserved) — with its dill contents',
      );
      expect(
        oldFile.existsSync(),
        isFalse,
        reason: 'a genuinely stale kernel FILE is reclaimed',
      );
    });
  });

  group('B12: the commandStartedAt guard still wins over the age floor', () {
    test('an entry modified after the command start survives even though '
        'its age passes the floor', () async {
      final liveDir = seedKernelDir('live-1520');

      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().subtract(const Duration(hours: 1)),
        environment: {'TMPDIR': ambientRoot.path},
        now: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(
        liveDir.existsSync(),
        isTrue,
        reason:
            'the entry\'s mtime is after the command start — it may '
            'belong to a concurrent runner no matter how old it is '
            '(#1507 C4 preserved)',
      );
    });
  });

  group('B13: the sweep covers the configured scratch root too', () {
    test('stale kernel entries are reclaimed from BOTH the ambient TMPDIR '
        'root and the ZFA_TMPDIR root', () async {
      final cfgRoot = Directory(p.join(sandbox.path, 'cfg-root'))
        ..createSync(recursive: true);
      final ambientStaleDir = seedKernelDir('ambient-1520');
      final cfgStaleFile = File(
        p.join(cfgRoot.path, 'dart_test.kernel.cfg-1520'),
      )..writeAsStringSync('stale kernel bytes');

      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().add(const Duration(seconds: 1)),
        environment: {'TMPDIR': ambientRoot.path, 'ZFA_TMPDIR': cfgRoot.path},
        now: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(
        ambientStaleDir.existsSync(),
        isFalse,
        reason: 'the ambient TMPDIR root is swept as before',
      );
      expect(
        cfgStaleFile.existsSync(),
        isFalse,
        reason:
            'the configured scratch root is swept under the same '
            'guard stack (spec 1520 FR-7)',
      );
    });
  });

  group('B14: the sweep reclaims orphaned zfa-* scratch dirs', () {
    test('a scratch past the age floor is reclaimed recursively', () async {
      final oldScratch = seedScratchDir('old', withKernel: true);

      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().add(const Duration(seconds: 1)),
        environment: {'TMPDIR': ambientRoot.path},
        now: DateTime.now().add(const Duration(hours: 2)),
        liveKernelDirs: const <String>{},
      );

      expect(
        oldScratch.existsSync(),
        isFalse,
        reason:
            'a zfa-* scratch orphaned by a killed run (no finally) is '
            'reclaimed — pre-fix the sweep matched only '
            'dart_test.kernel.* entries, so the scratch leaked forever '
            '(spec 1520 FR-5)',
      );
    });

    test('a scratch younger than the age floor survives', () async {
      final youngScratch = seedScratchDir('young', withKernel: true);

      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().add(const Duration(seconds: 1)),
        environment: {'TMPDIR': ambientRoot.path},
        now: DateTime.now().add(const Duration(seconds: 10)),
        liveKernelDirs: const <String>{},
      );

      expect(
        youngScratch.existsSync(),
        isTrue,
        reason:
            'a fresh scratch may belong to a concurrent run — the age '
            'floor protects it exactly like a kernel entry (spec 1520 FR-5)',
      );
    });

    test('a scratch holding a live runner\'s kernel survives regardless of '
        'age', () async {
      final liveScratch = seedScratchDir('live', withKernel: true);
      final liveKernel = p.join(liveScratch.path, 'dart_test.kernel.live');

      await clearDartTestKernelCache(
        sandbox.path,
        commandStartedAt: DateTime.now().add(const Duration(seconds: 1)),
        environment: {'TMPDIR': ambientRoot.path},
        now: DateTime.now().add(const Duration(hours: 4)),
        // The frontend-server child's argv reference, as the probe would
        // report it: a kernel dir INSIDE the scratch.
        liveKernelDirs: {liveKernel},
      );

      expect(
        liveScratch.existsSync(),
        isTrue,
        reason:
            'a live runner\'s kernel lives inside the scratch — the '
            'liveness guard must skip it (and thus its scratch) or the '
            'runner\'s loader crashes at close (spec 1520 FR-5)',
      );
    });
  });
}
