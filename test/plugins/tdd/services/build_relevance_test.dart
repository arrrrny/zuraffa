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
      final fp = {
        'lib/a.dart': 'h1',
        'pubspec.yaml': 'cfg',
      };
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

    test('a non-dart write never skips', () {
      final skip = BuildRelevance.canSkipTerminalBuild(
        before: {},
        after: {'assets/data.txt': 'new'},
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

    test('walks lib/test/bin/tool plus config files with stable POSIX keys',
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
    });

    test('detects a plain-dart modification between two fingerprints',
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
        reason:
            'a plain subject rewrite is the reported #1587 skip case',
      );
    });
  });
}
