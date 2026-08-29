import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// U6: the scanner must capture the named constructor of an annotation
// (@Route.redirect) so the route plugin can distinguish redirect rules.
void main() {
  test('named constructor annotation reports constructorName', () async {
    final dir = Directory.systemTemp.createTempSync('zfa_scan_ctor_');
    try {
      final pubspec = File('${dir.path}/pubspec.yaml');
      pubspec.writeAsStringSync(
        'name: scan_app\nenvironment:\n  sdk: ^3.11.0\n',
      );
      Directory('${dir.path}/lib').createSync();
      File('${dir.path}/lib/legacy_view.dart').writeAsStringSync('''
@Route.redirect(from: '/old', to: '/new')
class LegacyView {}
''');
      final results = await ASTScanner(projectRoot: '${dir.path}/lib').scan();
      final d = results.first.decorator;
      expect(d.name, equals('Route'));
      expect(d.constructorName, equals('redirect'));
      expect(d.get<String>('from'), equals('/old'));
      expect(d.get<String>('to'), equals('/new'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
