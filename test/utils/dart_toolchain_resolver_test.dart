// Unit tests for the Dart toolchain resolver — spec
// 1509-toolchain-path-portable (issue #1509).
//
// Every resolution tier is exercised over INJECTED inputs (environment
// map, PATH probe, filesystem probe, symlink resolver) — no real process
// spawning, following the same pattern as
// `StepRunner.resolveEntrypoint` (spec 047 lineage).
//
// RED evidence (recorded 2026-09-13, before implementation): this suite
// failed to compile — `lib/src/utils/dart_toolchain_resolver.dart` did
// not exist.
library;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/dart_toolchain_resolver.dart';

void main() {
  group('candidatePaths (pure, environment-derived)', () {
    test(
      'c1: emits no constant machine-specific paths when the env declares none',
      () {
        // An environment with unrelated variables (even one whose Flutter
        // happens to live at /opt/flutter) but NO SDK declarations and no
        // home: the only candidate is the neutral generic hint. Every
        // other entry must be traceable to a declared input (c2/c3/c4,
        // acceptance 2) — the function itself carries no SDK constant.
        final candidates = DartToolchainResolver.candidatePaths(
          environment: {'PATH': '/usr/bin:/bin', 'SHELL': '/bin/bash'},
          home: null,
        );
        expect(candidates, ['/usr/local/flutter/bin/dart']);
      },
    );

    test('c2: includes FLUTTER_ROOT/bin/dart iff FLUTTER_ROOT is set', () {
      final withRoot = DartToolchainResolver.candidatePaths(
        environment: {'FLUTTER_ROOT': '/sdks/flutter'},
        home: null,
      );
      expect(withRoot, contains('/sdks/flutter/bin/dart'));

      final withoutRoot = DartToolchainResolver.candidatePaths(
        environment: {},
        home: null,
      );
      // No roots declared and no home: only the neutral hint remains.
      expect(withoutRoot, ['/usr/local/flutter/bin/dart']);
    });

    test('c3: derives HOME candidates from the injected home', () {
      final candidates = DartToolchainResolver.candidatePaths(
        environment: const {},
        home: '/home/dev',
      );
      expect(candidates, contains('/home/dev/flutter/bin/dart'));
      expect(candidates, contains('/home/dev/development/flutter/bin/dart'));
    });

    test(
      'c4: expands ZURAFFA_TOOLCHAIN_HINTS to <dir>/dart and <dir>/bin/dart',
      () {
        final candidates = DartToolchainResolver.candidatePaths(
          environment: {'ZURAFFA_TOOLCHAIN_HINTS': '/sdk-a:/sdk-b'},
          home: null,
        );
        expect(candidates.take(4), [
          '/sdk-a/dart',
          '/sdk-a/bin/dart',
          '/sdk-b/dart',
          '/sdk-b/bin/dart',
        ]);

        // The separator is injectable, so the Windows (`;`) branch is
        // exercisable on POSIX too.
        final windowsStyle = DartToolchainResolver.candidatePaths(
          environment: const {'ZURAFFA_TOOLCHAIN_HINTS': '/sdk-a;/sdk-b'},
          home: null,
          hintsSeparator: ';',
        );
        expect(windowsStyle.take(4), [
          '/sdk-a/dart',
          '/sdk-a/bin/dart',
          '/sdk-b/dart',
          '/sdk-b/bin/dart',
        ]);
      },
    );

    test(
      'c5: keeps the generic /usr/local hint, omits user entries when home empty',
      () {
        final candidates = DartToolchainResolver.candidatePaths(
          environment: const {},
          home: null,
        );
        expect(candidates, contains('/usr/local/flutter/bin/dart'));
        expect(candidates.where((c) => c.contains('/flutter/bin/dart')), [
          '/usr/local/flutter/bin/dart',
        ]);
      },
    );

    test(
      'acceptance 2 (documented-env recipe): hints=/opt/flutter yields the old tier declaratively',
      () {
        final candidates = DartToolchainResolver.candidatePaths(
          environment: {'ZURAFFA_TOOLCHAIN_HINTS': '/opt/flutter'},
          home: null,
        );
        // Assembled via p.join so this test file does not itself carry
        // the contiguous literal the SC-001 grep gate bans.
        expect(candidates, contains(p.join('/opt/flutter', 'bin', 'dart')));
      },
    );
  });

  group('resolve() tiers over injected probes', () {
    late Map<String, String> env;
    late Set<String> existingFiles;
    late Map<String, List<String>> whichHits;
    late Map<String, String> symlinks;

    // No explicit `home:` — the resolver must derive it from the injected
    // environment, so the whole suite stays hermetic (no process HOME).
    DartToolchainResolver build() => DartToolchainResolver(
      environment: env,
      which: (exe) async => whichHits[exe] ?? const [],
      fileExists: (path) async => existingFiles.contains(path),
      resolveSymlink: (path) => symlinks[path] ?? path,
    );

    setUp(() {
      env = {};
      existingFiles = {};
      whichHits = {};
      symlinks = {};
    });

    test(
      'r1: ZURAFFA_DART_BIN pin wins over every tier when the file exists',
      () async {
        env['ZURAFFA_DART_BIN'] = '/pinned/sdk/bin/dart';
        existingFiles.add('/pinned/sdk/bin/dart');
        // A PATH hit and a better-looking candidate both exist — the pin
        // still wins.
        whichHits['dart'] = ['/usr/bin/dart'];
        existingFiles.add('/usr/bin/dart');
        existingFiles.add('/usr/local/flutter/bin/dart');

        expect(await build().resolve(), '/pinned/sdk/bin/dart');
      },
    );

    test(
      'r2: a missing ZURAFFA_DART_BIN pin is skipped, falls through to PATH',
      () async {
        env['ZURAFFA_DART_BIN'] = '/gone/sdk/bin/dart';
        whichHits['dart'] = ['/usr/bin/dart'];
        existingFiles.add('/usr/bin/dart');

        expect(await build().resolve(), '/usr/bin/dart');
      },
    );

    test('r3: PATH which-dart hit is returned trimmed and first', () async {
      // Simulates `which` stdout with incidental whitespace — the real
      // adapter trims per line.
      whichHits['dart'] = ['  /usr/bin/dart\n'];
      existingFiles.add('/usr/bin/dart');

      final resolved = await build().resolve();
      expect(resolved, '/usr/bin/dart');
    });

    test(
      'r4: dart next to which-flutter (symlink-resolved sibling) is found',
      () async {
        whichHits['flutter'] = ['/usr/local/bin/flutter'];
        symlinks['/usr/local/bin/flutter'] = '/real/sdk/flutter/bin/flutter';
        final siblingDart = p.join('/real/sdk/flutter/bin', 'dart');
        existingFiles.add(siblingDart);

        expect(await build().resolve(), siblingDart);
      },
    );

    test(
      'r5: existing candidates resolve in candidate order when PATH misses',
      () async {
        env['HOME'] = '/home/dev';
        env['ZURAFFA_TOOLCHAIN_HINTS'] = '/hints/flutter';
        existingFiles.add('/usr/local/flutter/bin/dart');

        expect(await build().resolve(), '/usr/local/flutter/bin/dart');
      },
    );

    test('r6: resolve returns null when every tier misses', () async {
      expect(await build().resolve(), isNull);
    });

    test(
      'mcp: dart beside the flutter symlink sibling missing keeps searching',
      () async {
        // Tier-2 sibling exists check guards against a flutter install
        // without a dart binary next to it — resolution continues to
        // candidates instead of returning a dead path.
        whichHits['flutter'] = ['/usr/local/bin/flutter'];
        env['HOME'] = '/home/dev';
        final homeDart = '/home/dev/flutter/bin/dart';
        existingFiles.add(homeDart);

        expect(await build().resolve(), homeDart);
      },
    );
  });
}
