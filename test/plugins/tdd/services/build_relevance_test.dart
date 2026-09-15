// Tests for `BuildRelevance` (issue #1587) — the build-skip gate that
// decides whether the make plan's terminal `zfa build` step has anything
// builder-consumable to do.
//
// The gate is pure decision logic over a content fingerprint: it skips
// the build ONLY when nothing a builder consumes changed — no deletion,
// no build-config change, and every write is an un-annotated `.dart`
// file (the reported calculator case: plain subjects + tests). Anything
// else keeps the build running exactly as before.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/build_relevance.dart';

void main() {
  group('canSkipTerminalBuild (U1 — skip shapes)', () {
    test('empty changed set (before == after) skips', () {
      final fp = {'lib/a.dart': 'h1', 'pubspec.yaml': 'cfg'};
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: fp,
        after: Map.of(fp),
        readContent: (_) => '',
      );
      expect(skip, isTrue);
    });

    test('a new plain un-annotated .dart file skips', () {
      const content = 'int answer() => 42;\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/a.dart': 'h1'},
        after: {'lib/a.dart': 'h1', 'lib/tdd/feature/u1_subject.dart': 'h2'},
        readContent: (path) => path.contains('u1_subject') ? content : '',
      );
      expect(skip, isTrue);
    });

    test('a modified plain un-annotated .dart file skips (the subject '
        'implementation rewrite — the reported #1587 case)', () {
      const content = 'library;\n\nint u2_value() => 42;\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/u2_subject.dart': 'old'},
        after: {'lib/u2_subject.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isTrue);
    });

    test('a modified test file skips', () {
      const content = "import 'package:test/test.dart';\nvoid main() {}\n";
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'test/u3_test.dart': 'old'},
        after: {'test/u3_test.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isTrue);
    });
  });

  group('canSkipTerminalBuild (U2 — run shapes)', () {
    test('an @Zorphy-annotated write never skips', () {
      const content = '@Zorphy\nclass User {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/user.dart': 'old'},
        after: {'lib/user.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('an @JsonSerializable-annotated write never skips', () {
      const content = '@JsonSerializable\nclass UserDto {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'lib/dto.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('an @HiveType-annotated write never skips', () {
      const content = '@HiveType(typeId: 1)\nclass Box {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'lib/box.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('an @Route-annotated write never skips', () {
      const content = '@Route(path: "/home")\nclass HomeRoute {}\n';
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'lib/home_route.dart': 'new'},
        readContent: (_) => content,
      );
      expect(skip, isFalse);
    });

    test('a build config file change never skips', () {
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'pubspec.yaml': 'old', 'lib/a.dart': 'h'},
        after: {'pubspec.yaml': 'new', 'lib/a.dart': 'h'},
        readContent: (_) => '',
      );
      expect(skip, isFalse);
    });

    test('a deleted build-relevant file never skips', () {
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'lib/gone.dart': 'old'},
        after: {},
        readContent: (_) => '',
      );
      expect(skip, isFalse);
    });

    test('a non-dart write inside the fingerprinted roots never skips', () {
      // The fingerprint only ever yields paths under lib/test/bin/tool
      // plus the config files (see the class doc's coverage boundary),
      // so the non-Dart shape that can actually reach the gate is one
      // written inside those roots (issue #1587 review, finding 2).
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {'test/fixtures/data.txt': 'old'},
        after: {'test/fixtures/data.txt': 'new'},
        readContent: (_) => 'data',
      );
      expect(skip, isFalse);
    });
  });

  group('fingerprint (FR-001 changed-file set)', () {
    late Directory root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('build_relevance_');
    });
    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test(
      'walks lib/test/bin/tool plus config files with stable POSIX keys',
      () async {
        Directory(p.join(root.path, 'lib', 'tdd')).createSync(recursive: true);
        Directory(p.join(root.path, 'test')).createSync(recursive: true);
        File(
          p.join(root.path, 'lib', 'tdd', 'a.dart'),
        ).writeAsStringSync('int a() => 1;\n');
        File(
          p.join(root.path, 'test', 'a_test.dart'),
        ).writeAsStringSync('void main() {}\n');
        File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');

        final fp = await BuildRelevance.fingerprint(projectRoot: root.path);
        expect(fp.keys, contains('lib/tdd/a.dart'));
        expect(fp.keys, contains('test/a_test.dart'));
        expect(fp.keys, contains('pubspec.yaml'));
      },
    );

    test(
      'detects a plain-dart modification between two fingerprints',
      () async {
        Directory(p.join(root.path, 'lib')).createSync(recursive: true);
        final subject = File(p.join(root.path, 'lib', 's.dart'))
          ..writeAsStringSync('int s() => 0;\n');
        File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');

        final before = await BuildRelevance.fingerprint(projectRoot: root.path);
        subject.writeAsStringSync('int s() => 42;\n');
        final after = await BuildRelevance.fingerprint(projectRoot: root.path);

        expect(before['lib/s.dart'], isNot(equals(after['lib/s.dart'])));
        expect(
          BuildRelevance.canSkipTerminalBuild(
            before: before,
            after: after,
            readContent: (_) => 'int s() => 42;\n',
          ),
          isTrue,
          reason: 'a plain subject rewrite is the reported #1587 skip case',
        );
      },
    );

    test('a non-UTF8 .dart write fails the decision toward RUN, never throws '
        '(issue #1587 review, finding 1)', () async {
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      final broken = File(p.join(root.path, 'lib', 'broken.dart'))
        ..writeAsBytesSync([0xFF, 0xFE, 0x00, 0x01]);

      final before = await BuildRelevance.fingerprint(projectRoot: root.path);
      broken.writeAsBytesSync([0xFF, 0xFE, 0x00, 0x02]);
      final after = await BuildRelevance.fingerprint(projectRoot: root.path);

      // `readAsStringSync` on invalid UTF-8 raises FormatException — NOT
      // a FileSystemException — so the gate must fail open on ANY throw
      // instead of letting it escape the make.
      expect(
        await BuildRelevance.shouldSkipTerminalBuild(
          projectRoot: root.path,
          before: before,
        ),
        isFalse,
        reason: 'a decode error must fail the decision toward RUN',
      );
      expect(after['lib/broken.dart'], isNotNull);
    });

    test('a non-dart write inside the walked roots forces a run (issue #1587 '
        'review, finding 2)', () async {
      Directory(p.join(root.path, 'test')).createSync(recursive: true);
      final fixture = File(p.join(root.path, 'test', 'data.txt'))
        ..writeAsStringSync('old\n');
      File(
        p.join(root.path, 'test', 'a_test.dart'),
      ).writeAsStringSync('void main() {}\n');

      final before = await BuildRelevance.fingerprint(projectRoot: root.path);
      fixture.writeAsStringSync('new\n');
      final after = await BuildRelevance.fingerprint(projectRoot: root.path);

      expect(before['test/data.txt'], isNot(equals(after['test/data.txt'])));
      expect(
        BuildRelevance.canSkipTerminalBuild(
          before: before,
          after: after,
          readContent: (_) => 'new\n',
        ),
        isFalse,
        reason: 'a non-Dart write is never skipped',
      );
    });
  });

  // Issue #1624: the REFACTOR's build-pass gate. It has no "before"
  // fingerprint to diff (the refactor did not write the tree), so it
  // decides from build_runner's own state marker —
  // `.dart_tool/build/asset_graph.json`. Only files NOT older than that
  // marker can hold input build_runner has not consumed.
  group('refactorBuildSkipNote (issue #1624)', () {
    late Directory root;
    final marker = p.join('.dart_tool', 'build', 'asset_graph.json');

    setUp(() {
      root = Directory.systemTemp.createTempSync('refactor_build_gate_');
    });
    tearDown(() {
      root.deleteSync(recursive: true);
    });

    /// Write the build_runner marker backdated one hour: any file written
    /// "now" by the test is unambiguously newer than it.
    void writeMarker() {
      final file = File(p.join(root.path, marker))
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    }

    void writeLibFile(String name, String content) {
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      File(p.join(root.path, 'lib', name)).writeAsStringSync(content);
    }

    test('a missing marker runs the build — the project has never been '
        'built here', () async {
      writeLibFile('a.dart', 'int a() => 1;\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a newer annotated .dart file runs the build', () async {
      writeMarker();
      writeLibFile('user.dart', '@JsonSerializable\nclass User {}\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a newer plain .dart file skips the build', () async {
      writeMarker();
      writeLibFile('plain.dart', 'int answer() => 42;\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        BuildRelevance.refactorBuildSkippedNote,
      );
    });

    test('a newer non-Dart write runs the build', () async {
      writeMarker();
      Directory(p.join(root.path, 'lib')).createSync(recursive: true);
      File(p.join(root.path, 'lib', 'data.txt')).writeAsStringSync('x\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a newer build-config write runs the build', () async {
      writeMarker();
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        isNull,
      );
    });

    test('a tree unchanged since the marker skips the build', () async {
      writeMarker();
      writeLibFile('plain.dart', 'int answer() => 42;\n');
      // Backdate the write behind the marker: nothing is newer.
      File(
        p.join(root.path, 'lib', 'plain.dart'),
      ).setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      expect(
        await BuildRelevance.refactorBuildSkipNote(projectRoot: root.path),
        BuildRelevance.refactorBuildSkippedNote,
      );
    });
  });
}
