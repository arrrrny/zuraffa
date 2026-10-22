// Fast-tier unit tests for `packageRelativePath` (issue #1983) — the
// portable form of a subject artifact's path, the shape the composed
// subject's header carries.
//
// The header is a committed source file: the machine-absolute path the
// discovery resolved would leak the developer's home directory into the
// repository and mean nothing on another machine.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/package_relative_path.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('pkg_rel_path_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Create `<root>/<relative>` with the given content, creating parents.
  String write(String relative, [String content = '']) {
    final file = File(p.join(root.path, relative))
      ..parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file.path;
  }

  test('a file under the project root package is relative to it', () async {
    write('pubspec.yaml', 'name: pkg\n');
    final subject = write('lib/tdd/900-feature/u1_subject.dart');

    expect(
      await packageRelativePath(subject, projectRoot: root.path),
      'lib/tdd/900-feature/u1_subject.dart',
    );
  });

  test(
    'a file under a NESTED package is qualified with that package',
    () async {
      write('packages/app/pubspec.yaml', 'name: app\n');
      final subject = write('packages/app/lib/tdd/900-feature/u1_subject.dart');

      expect(
        await packageRelativePath(subject, projectRoot: root.path),
        'packages/app:lib/tdd/900-feature/u1_subject.dart',
        reason:
            'the package qualifier names the package the path is relative to, '
            'so the path resolves from the project root',
      );
    },
  );

  test('a file outside every package falls back to the project root', () async {
    final subject = write('elsewhere/u1_subject.dart');

    expect(
      await packageRelativePath(subject, projectRoot: root.path),
      'elsewhere/u1_subject.dart',
    );
  });

  test('a file outside the project root keeps only its file name', () async {
    final outside = Directory.systemTemp.createTempSync('pkg_rel_outside_');
    addTearDown(() {
      if (outside.existsSync()) outside.deleteSync(recursive: true);
    });
    final subject = File(p.join(outside.path, 'u1_subject.dart'))
      ..writeAsStringSync('');

    expect(
      await packageRelativePath(subject.path, projectRoot: root.path),
      '<outside-project>/u1_subject.dart',
      reason:
          'a path that cannot be made portable never leaks a machine-absolute '
          'path into a committed header',
    );
  });

  test('the package walk never leaves the project root', () async {
    // An ancestor pubspec.yaml belongs to another workspace: relativizing
    // to it would put a machine-specific prefix back into the header.
    final outer = Directory(p.join(root.path, 'outer'))
      ..createSync(recursive: true);
    File(p.join(outer.path, 'pubspec.yaml')).writeAsStringSync('name: outer\n');
    final projectRoot = Directory(p.join(outer.path, 'inner'))
      ..createSync(recursive: true);
    final subject = File(p.join(projectRoot.path, 'lib', 'u1_subject.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('');

    expect(
      await packageRelativePath(subject.path, projectRoot: projectRoot.path),
      'lib/u1_subject.dart',
      reason: 'the ancestor package must not become the base',
    );
  });

  test('a file that does not exist yet is still portable', () async {
    write('pubspec.yaml', 'name: pkg\n');
    final subject = p.join(root.path, 'lib', 'tdd', '900', 'u1_subject.dart');

    expect(
      await packageRelativePath(subject, projectRoot: root.path),
      'lib/tdd/900/u1_subject.dart',
      reason:
          'a missing file resolves through its nearest existing ancestor, '
          'never through the absolute fallback',
    );
  });
}
