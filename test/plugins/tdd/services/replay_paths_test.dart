/// Unit behaviors U1, U3, U4 for spec 0806-zfa-replay: the `ReplayPaths`
/// re-anchoring service — recorded-root detection from the canonical
/// `<root>/./<rel>` marker, entrypoint re-resolution for machine-absolute
/// gen steps, and command path stripping into sandbox-relative form.
///
/// Every input below mirrors the shapes a real recorded history carries when
/// it was written on a DIFFERENT machine (`examples/todo_tdd`'s cycle-log is
/// the reference: `/home/other-box/workspace/todo_tdd/./test/tdd/a1_test.dart`
/// test fields, `/gone/sdk/bin/dart /gone/zuraffa/bin/zfa.dart tdd wire …`
/// generation steps).
library;

import 'dart:io';

import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/replay_paths.dart';

void main() {
  group('U1: detectRecordedRoot', () {
    test('detects the single consistent <root>/. anchor prefix', () {
      final root = ReplayPaths.detectRecordedRoot([
        '/other-box/workspace/todo/./test/tdd/a1_test.dart',
        '/other-box/workspace/todo/./lib/tdd/a1_subject.dart',
        '/other-box/workspace/todo/./test/tdd/u2_test.dart',
      ]);
      expect(root, '/other-box/workspace/todo');
    });

    test(
      'zero anchors yield null (same-machine histories re-anchor nothing)',
      () {
        final root = ReplayPaths.detectRecordedRoot([
          '/tmp/fixture_a/test/tdd/a1_test.dart',
          'test/tdd/a1_test.dart',
          null,
        ]);
        expect(root, isNull);
      },
    );

    test('conflicting roots yield null — never guess', () {
      final root = ReplayPaths.detectRecordedRoot([
        '/box-a/workspace/todo/./test/tdd/a1_test.dart',
        '/box-b/workspace/todo/./test/tdd/u1_test.dart',
      ]);
      expect(root, isNull);
    });

    test('relative paths and bare command words are not anchors', () {
      final root = ReplayPaths.detectRecordedRoot([
        'test/tdd/a1_test.dart',
        'dart test test/tdd/a1_test.dart',
      ]);
      expect(root, isNull);
    });
  });

  group('U3: reAnchorEntrypoint', () {
    test('--zfa-bin replaces the whole recorded pair, args kept', () {
      final command = ReplayPaths.reAnchorEntrypoint(
        '/gone/sdk/bin/dart /gone/zuraffa/bin/zfa.dart tdd gen A1 --feature f',
        zfaBin: '/fake/bin/zfa',
      );
      expect(command, '/fake/bin/zfa tdd gen A1 --feature f');
    });

    test('--zfa-bin still replaces the bare zfa prefix (066 contract)', () {
      final command = ReplayPaths.reAnchorEntrypoint(
        'zfa tdd gen A1 --feature f',
        zfaBin: '/fake/bin/zfa',
      );
      expect(command, '/fake/bin/zfa tdd gen A1 --feature f');
    });

    test('a locally-missing recorded dart re-resolves to the running dart; '
        'the locally-present zfa script is kept', () {
      final command = ReplayPaths.reAnchorEntrypoint(
        '/gone/sdk/bin/dart /present/checkout/bin/zfa.dart tdd gen A1',
        resolvedDart: '/local/dart-sdk/bin/dart',
        exists: (path) => path == '/present/checkout/bin/zfa.dart',
      );
      expect(
        command,
        '/local/dart-sdk/bin/dart /present/checkout/bin/zfa.dart '
        'tdd gen A1',
      );
    });

    test(
      'a locally-missing zfa script re-resolves to the running entrypoint',
      () {
        final command = ReplayPaths.reAnchorEntrypoint(
          '/present/sdk/bin/dart /gone/checkout/bin/zfa.dart tdd gen A1',
          resolvedDart: '/local/dart-sdk/bin/dart',
          runningScript: '/local/zuraffa/bin/zfa.dart',
          exists: (path) => path == '/present/sdk/bin/dart',
        );
        expect(
          command,
          '/present/sdk/bin/dart /local/zuraffa/bin/zfa.dart tdd gen A1',
        );
      },
    );

    test('a fully resolvable recorded pair runs as recorded (determinism)', () {
      final command = ReplayPaths.reAnchorEntrypoint(
        '/present/sdk/bin/dart /present/checkout/bin/zfa.dart tdd gen A1',
        resolvedDart: '/local/dart-sdk/bin/dart',
        exists: (path) => path.startsWith('/present/'),
      );
      expect(
        command,
        '/present/sdk/bin/dart /present/checkout/bin/zfa.dart tdd gen A1',
      );
    });

    test('no zfa fallback keeps the recorded script — the spawn fails '
        'honestly as a runner-error (never a fabricated entrypoint)', () {
      final command = ReplayPaths.reAnchorEntrypoint(
        '/gone/sdk/bin/dart /gone/checkout/bin/zfa.dart tdd gen A1',
        resolvedDart: '/local/dart-sdk/bin/dart',
        runningScript: null,
        exists: (path) => false,
      );
      // The missing dart re-resolves to the running dart, but without a
      // zfa fallback the recorded script is kept as-is — the command is
      // never given an entrypoint that was not recorded and not running.
      expect(
        command,
        '/local/dart-sdk/bin/dart /gone/checkout/bin/zfa.dart '
        'tdd gen A1',
      );
    });

    test('non-entrypoint commands pass through unchanged', () {
      const recorded = 'sh .specify/check_a1.sh lib/a1_subject.dart OK';
      final command = ReplayPaths.reAnchorEntrypoint(
        recorded,
        zfaBin: '/fake/bin/zfa',
      );
      expect(command, recorded);
    });
  });

  group('U4: reAnchorCommand', () {
    test('strips every <root>/. occurrence to the relative tail', () {
      final command = ReplayPaths.reAnchorCommand(
        'dart test /other-box/todo/./test/tdd/a1_test.dart '
        '--name "create entity Todo."',
        recordedRoot: '/other-box/todo',
      );
      expect(
        command,
        'dart test test/tdd/a1_test.dart --name "create entity '
        'Todo."',
      );
    });

    test('multiple anchored paths in one command all strip', () {
      final command = ReplayPaths.reAnchorCommand(
        'sh .specify/check_a1.sh /other-box/todo/./lib/a1_subject.dart '
        '/other-box/todo/./test/a1_test.dart',
        recordedRoot: '/other-box/todo',
      );
      expect(
        command,
        'sh .specify/check_a1.sh lib/a1_subject.dart test/a1_test.dart',
      );
    });

    test('a null recorded root leaves the command unchanged', () {
      const recorded =
          'dart test /other-box/todo/./test/tdd/a1_test.dart --name "x"';
      final command = ReplayPaths.reAnchorCommand(recorded, recordedRoot: null);
      expect(command, recorded);
    });

    test('the recorded root without the /. marker is NOT stripped', () {
      // Only the canonical `<root>/./<rel>` marker is path evidence; a bare
      // recorded-root prefix (no marker) is left alone — never guess.
      final command = ReplayPaths.reAnchorCommand(
        'sh /other-box/todo/.specify/check_a1.sh lib/a1_subject.dart',
        recordedRoot: '/other-box/todo',
      );
      expect(
        command,
        'sh /other-box/todo/.specify/check_a1.sh '
        'lib/a1_subject.dart',
      );
    });
  });

  group('U2 (path half): resolveTestPath', () {
    test(
      'a locally-missing anchored path resolves against the project root',
      () {
        final resolved = ReplayPaths.resolveTestPath(
          '/other-box/todo/./test/tdd/a1_test.dart',
          recordedRoot: '/other-box/todo',
          projectRoot: '/local/todo',
        );
        expect(resolved, '/local/todo/test/tdd/a1_test.dart');
      },
    );

    test('a `..`-bearing anchored tail is NOT re-anchored (containment)', () {
      final resolved = ReplayPaths.resolveTestPath(
        '/other-box/todo/./../../etc/passwd_test.dart',
        recordedRoot: '/other-box/todo',
        projectRoot: '/local/todo',
      );
      // Left verbatim: integrity reports the artifact missing against
      // the recorded path — it never resolves outside the project.
      expect(resolved, '/other-box/todo/./../../etc/passwd_test.dart');
    });

    test(
      'a locally-existing absolute path wins (same-machine first)',
      () async {
        final dir = await Directory.systemTemp.createTemp('zfa_paths_u2_');
        addTearDown(() => dir.delete(recursive: true));
        final local = File('${dir.path}/other-box/todo/test/tdd/a1_test.dart')
          ..createSync(recursive: true);
        final resolved = ReplayPaths.resolveTestPath(
          local.path,
          recordedRoot: '/other-box/todo',
          projectRoot: dir.path,
        );
        expect(resolved, local.path);
      },
    );

    test('relative and anchor-less paths pass through', () {
      expect(
        ReplayPaths.resolveTestPath(
          'test/tdd/a1_test.dart',
          recordedRoot: '/other-box/todo',
          projectRoot: '/local/todo',
        ),
        'test/tdd/a1_test.dart',
      );
      expect(
        ReplayPaths.resolveTestPath(
          '/tmp/x/test/a_test.dart',
          recordedRoot: null,
          projectRoot: '/local/todo',
        ),
        '/tmp/x/test/a_test.dart',
      );
    });
  });
}
