// Tests for the SmokeTestWriter (spec 041-tdd-setup-plugin, U14-U15).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/app_module_writer.dart';
import 'package:zuraffa/src/cli/writers/tdd/smoke_test_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('smoke_test_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test(
    'writes test/bootstrap_smoke_test.dart referencing the package',
    () async {
      final writer = const SmokeTestWriter();
      final path = await writer.write(tmpDir.path, 'myapp');
      expect(path, isNotNull);
      final file = File(p.join(tmpDir.path, 'test/bootstrap_smoke_test.dart'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('package:myapp/app.dart'));
      // Issue #626 naming contract: the asserted container symbol derives
      // from the app name (PascalCase + Container).
      expect(content, contains('MyappContainer'));
      expect(content, contains('final container = MyappContainer();'));
      expect(content, contains('isNotNull'));
    },
  );

  test('derives the container symbol from the app name (issue #626)', () {
    // The maintainer decision on #626: `zfa setup zik_zak_tdd` emits
    // `ZikZakTddContainer` in lib/app.dart, and the smoke test asserts
    // that exact symbol.
    expect(
      AppModuleWriter.containerSymbolFor('zik_zak_tdd'),
      'ZikZakTddContainer',
    );
    expect(AppModuleWriter.containerSymbolFor('myapp'), 'MyappContainer');
    expect(
      AppModuleWriter.containerSymbolFor('probe_app'),
      'ProbeAppContainer',
    );
  });

  test('rendered smoke test asserts the app-name-derived symbol', () {
    const writer = SmokeTestWriter();
    final rendered = writer.render('zik_zak_tdd');
    expect(rendered, contains("import 'package:zik_zak_tdd/app.dart';"));
    expect(rendered, contains('final container = ZikZakTddContainer();'));
    // The old generic symbol must not come back — the assertion stays
    // strong and app-name-derived (provenance audit, issue #626).
    expect(rendered, isNot(contains('AppContainer()')));
  });

  test('is idempotent — does not overwrite an existing smoke test', () async {
    final writer = const SmokeTestWriter();
    await writer.write(tmpDir.path, 'myapp');
    final file = File(p.join(tmpDir.path, 'test/bootstrap_smoke_test.dart'));
    await file.writeAsString('// Custom user test\n');
    final result = await writer.write(tmpDir.path, 'myapp');
    expect(
      result,
      isNull,
      reason: 'should not overwrite existing user content',
    );
    expect(file.readAsStringSync(), '// Custom user test\n');
  });
}
