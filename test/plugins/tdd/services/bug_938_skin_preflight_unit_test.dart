// Bug #938 unit pins — the WidgetSkinPreflight probe + fix-line
// contract. Split from the CLI acceptance test (commands/) so the
// acceptance red is RUNTIME-verifiable against the unfixed lib: these
// pins import the new API surface and are COMPILE-red until the fix
// lands (the issue-#912 precedent for new-API pins).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug938_unit_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  void writePubspec(String content) {
    File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync(content);
  }

  test('declared in dependencies → true', () {
    writePubspec('''
name: probe
dependencies:
  flutter: {sdk: flutter}
  zuraffa_ui: ^1.0.0
''');
    expect(WidgetSkinPreflight.projectDeclaresZuraffaUi(tmpDir.path), isTrue);
  });

  test('absent from dependencies → false', () {
    writePubspec('''
name: probe
dependencies:
  flutter: {sdk: flutter}
''');
    expect(WidgetSkinPreflight.projectDeclaresZuraffaUi(tmpDir.path), isFalse);
  });

  test('no dependencies section at all → false', () {
    writePubspec('name: probe\nenvironment:\n  sdk: ^3.11.0\n');
    expect(WidgetSkinPreflight.projectDeclaresZuraffaUi(tmpDir.path), isFalse);
  });

  test('dev_dependencies alone does not satisfy the shell import', () {
    writePubspec('''
name: probe
dev_dependencies:
  zuraffa_ui: ^1.0.0
''');
    expect(WidgetSkinPreflight.projectDeclaresZuraffaUi(tmpDir.path), isFalse);
  });

  test('no pubspec.yaml → true (nothing to resolve)', () {
    expect(WidgetSkinPreflight.projectDeclaresZuraffaUi(tmpDir.path), isTrue);
  });

  test('fix line is machine-parseable and names the remedy', () {
    expect(
      WidgetSkinPreflight.fixLine,
      '--> fix: flutter pub add zuraffa_ui '
      '(widget-lane behaviors boot a ZuraffaApp shell)',
    );
  });

  test('the zuraffaapp shell requires the import; materialapp does not', () {
    expect(
      WidgetSkinPreflight.skinImportRequired(WidgetAppShell.zuraffaapp),
      isTrue,
    );
    expect(
      WidgetSkinPreflight.skinImportRequired(WidgetAppShell.materialapp),
      isFalse,
    );
  });
}
