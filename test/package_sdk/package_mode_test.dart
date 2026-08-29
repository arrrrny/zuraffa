import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/package/package_mode.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_pkg_mode_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Directory writeProject(String zfaYaml, {String? pubspec}) {
    File('${tempDir.path}/zfa.yaml').writeAsStringSync(zfaYaml);
    File(
      '${tempDir.path}/pubspec.yaml',
    ).writeAsStringSync(pubspec ?? 'name: my_pkg\n');
    return tempDir;
  }

  group('PackageMode.isEnabled (FR-010/FR-011 — package-shape marker)', () {
    test('U1: marker true → package mode enabled', () {
      writeProject('''
# zfa-owned package-mode marker
package_mode: true
''');
      expect(PackageMode.isEnabled(tempDir.path), isTrue);
    });

    test('U1: marker false → disabled', () {
      writeProject('''
package_mode: false
''');
      expect(PackageMode.isEnabled(tempDir.path), isFalse);
    });

    test('U1: marker absent → disabled', () {
      writeProject('some_other_key: value\n');
      expect(PackageMode.isEnabled(tempDir.path), isFalse);
    });

    test('U1: missing zfa.yaml → disabled', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: x\n');
      expect(PackageMode.isEnabled(tempDir.path), isFalse);
    });

    test('U1: malformed yaml → disabled (never throws)', () {
      writeProject('package_mode: [unclosed');
      expect(PackageMode.isEnabled(tempDir.path), isFalse);
    });

    test('U1b: marker read is scoped to the given project root', () {
      final appDir = Directory('${tempDir.path}/app')..createSync();
      final pkgDir = Directory('${tempDir.path}/pkg')..createSync();
      File('${pkgDir.path}/zfa.yaml').writeAsStringSync('''
package_mode: true
''');
      File('${pkgDir.path}/pubspec.yaml').writeAsStringSync('name: pkg\n');
      File('${appDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');

      // The package has the marker; the sibling app (no zfa.yaml) does not.
      expect(PackageMode.isEnabled(pkgDir.path), isTrue);
      expect(PackageMode.isEnabled(appDir.path), isFalse);
    });
  });
}
