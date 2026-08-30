// Tests for the shared TreeSnapshot service (spec 048-tdd-refactor, T004 +
// T011; behaviors U6, U7).
//
// TreeSnapshot generalizes verify_red_command.dart's private
// _ReadOnlyTreeSnapshot so the refactor command can use the same
// path -> file:<sha256> / directory / link:<target> fingerprinting and
// symmetric changedPaths diff for both the `test/` immutability check
// (FR-004) and the `lib/` attribution check (FR-005).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/tree_snapshot.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tree_snapshot_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('TreeSnapshot (T004)', () {
    test('U6: files hash as file:<sha256>; directories and links are recorded '
        'distinctly', () async {
      await Directory(p.join(tmp.path, 'lib')).create(recursive: true);
      await File(
        p.join(tmp.path, 'lib', 'a.dart'),
      ).writeAsString('int x = 1;\n');
      await Directory(p.join(tmp.path, 'lib', 'sub')).create();
      await File(
        p.join(tmp.path, 'lib', 'sub', 'b.dart'),
      ).writeAsString('int y = 2;\n');
      final link = Link(p.join(tmp.path, 'lib', 'link.dart'));
      await link.create(p.join(tmp.path, 'lib', 'a.dart'));

      final snap = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);

      // Files hash with the file: prefix.
      expect(snap.entries['lib/a.dart'], startsWith('file:'));
      expect(snap.entries['lib/a.dart'], isNot('file:'));
      // Directories are recorded distinctly (trailing slash + 'directory').
      expect(snap.entries['lib/'], 'directory');
      expect(snap.entries['lib/sub/'], 'directory');
      // Links are recorded as link:<target>, NOT hashed as files.
      expect(snap.entries['lib/link.dart'], startsWith('link:'));
      expect(snap.entries['lib/link.dart'], isNot(startsWith('file:')));
    });

    test('U6: identical content produces identical hashes', () async {
      await Directory(p.join(tmp.path, 'lib')).create();
      await File(
        p.join(tmp.path, 'lib', 'a.dart'),
      ).writeAsString('int x = 1;\n');

      final s1 = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);
      // Re-capture without changes — should be identical.
      final s2 = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);
      expect(s1.entries, equals(s2.entries));
    });

    test('U7: changedPaths reports added, removed, and content-changed paths '
        'symmetrically', () async {
      // Initial state: lib/a.dart with content "v1".
      await Directory(p.join(tmp.path, 'lib')).create();
      await File(p.join(tmp.path, 'lib', 'a.dart')).writeAsString('v1\n');
      final before = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);

      // Mutate: modify a.dart, add b.dart, remove nothing yet.
      await File(p.join(tmp.path, 'lib', 'a.dart')).writeAsString('v2\n');
      await File(p.join(tmp.path, 'lib', 'b.dart')).writeAsString('new\n');
      final after = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);

      final changed = before.changedPaths(after);
      expect(changed, contains('lib/a.dart'));
      expect(changed, contains('lib/b.dart'));

      // Symmetric: diffing the other way produces the same set.
      final reverse = after.changedPaths(before);
      expect(reverse.toSet(), equals(changed.toSet()));
    });

    test('U7: removed paths are reported', () async {
      await Directory(p.join(tmp.path, 'lib')).create();
      await File(p.join(tmp.path, 'lib', 'a.dart')).writeAsString('v1\n');
      await File(p.join(tmp.path, 'lib', 'b.dart')).writeAsString('v2\n');
      final before = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);

      await File(p.join(tmp.path, 'lib', 'b.dart')).delete();
      final after = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);

      expect(before.changedPaths(after), contains('lib/b.dart'));
    });

    test('U7: identical snapshots have an empty diff', () async {
      await Directory(p.join(tmp.path, 'lib')).create();
      await File(p.join(tmp.path, 'lib', 'a.dart')).writeAsString('v1\n');
      final s1 = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);
      final s2 = await TreeSnapshot.capture(tmp.path, trees: const ['lib']);
      expect(s1.changedPaths(s2), isEmpty);
    });

    test('can capture multiple trees at once (test/ and lib/)', () async {
      await Directory(p.join(tmp.path, 'test')).create();
      await Directory(p.join(tmp.path, 'lib')).create();
      await File(
        p.join(tmp.path, 'test', 'a_test.dart'),
      ).writeAsString('void main() {}\n');
      await File(p.join(tmp.path, 'lib', 'a.dart')).writeAsString('int x;\n');

      final snap = await TreeSnapshot.capture(
        tmp.path,
        trees: const ['test', 'lib'],
      );
      expect(snap.entries.keys, contains('test/a_test.dart'));
      expect(snap.entries.keys, contains('lib/a.dart'));
      expect(snap.entries['test/'], 'directory');
      expect(snap.entries['lib/'], 'directory');
    });

    test('a missing tree contributes no entries (no crash)', () async {
      // Project has lib/ but no test/.
      await Directory(p.join(tmp.path, 'lib')).create();
      await File(p.join(tmp.path, 'lib', 'a.dart')).writeAsString('int x;\n');
      final snap = await TreeSnapshot.capture(
        tmp.path,
        trees: const ['test', 'lib'],
      );
      expect(snap.entries.keys, isNot(contains('test/')));
      expect(snap.entries.keys, contains('lib/a.dart'));
    });
  });
}
