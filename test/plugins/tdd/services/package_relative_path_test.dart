// Fast-tier unit tests for `packageRelativePath` (issue #1983) — the
// package-root-relative form of a subject artifact's path, the shape the
// composed subject's header carries.
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

  test('a file under the package root is relative to it', () {
    write('pubspec.yaml', 'name: pkg\n');
    final subject = write('lib/tdd/900-feature/u1_subject.dart');

    expect(
      packageRelativePath(subject, projectRoot: root.path),
      'lib/tdd/900-feature/u1_subject.dart',
    );
  });

  test('a file under a NESTED package is relative to THAT package', () {
    write('packages/app/pubspec.yaml', 'name: app\n');
    final subject = write('packages/app/lib/tdd/900-feature/u1_subject.dart');

    expect(
      packageRelativePath(subject, projectRoot: root.path),
      'lib/tdd/900-feature/u1_subject.dart',
      reason:
          'the package root is the nearest pubspec.yaml ancestor, not the '
          'project root',
    );
  });

  test('a file outside every package falls back to the project root', () {
    final subject = write('elsewhere/u1_subject.dart');

    expect(
      packageRelativePath(subject, projectRoot: root.path),
      'elsewhere/u1_subject.dart',
    );
  });

  test('a file outside the project root keeps its own path', () {
    final subject = write('elsewhere/u1_subject.dart');
    final resolved = Link(subject).resolveSymbolicLinksSync();

    expect(
      packageRelativePath(subject, projectRoot: p.join(root.path, 'nope')),
      resolved.replaceAll(r'\', '/'),
      reason: 'a path that cannot be made portable is never mangled',
    );
  });
}
