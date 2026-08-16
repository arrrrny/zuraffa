import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_scaffolder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_scaffolder_edge_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('XRayMockScaffolder.escapeDartString', () {
    test('escapes single quotes and dollar signs', () {
      expect(XRayMockScaffolder.escapeDartString('plain'), 'plain');
      expect(XRayMockScaffolder.escapeDartString("'"), r"\'");
      expect(XRayMockScaffolder.escapeDartString(r'$'), r'\$');
      expect(XRayMockScaffolder.escapeDartString("it's \$5"), r"it\'s \$5");
    });

    test('escapes a lone backslash to a double backslash', () {
      expect(XRayMockScaffolder.escapeDartString(r'\'), r'\\');
      expect(XRayMockScaffolder.escapeDartString(r'a\b'), r'a\\b');
    });

    // ★ Gap fix: CodeRabbit's original version escaped `'` before `\`,
    // which doubled the backslash of the quote escape (producing `\\'`).
    // Backslash must be escaped FIRST.
    test('escapes backslashes before quotes so escapes are not doubled', () {
      expect(XRayMockScaffolder.escapeDartString(r"a\b'c$d"), r"a\\b\'c\$d");
    });
  });

  group('XRayMockScaffolder nested-paren annotations', () {
    test('injects @XRayMock above a class preceded by an annotation with '
        'one level of nested parens', () {
      final usecasesDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'user',
      );
      final file = File(p.join(usecasesDir, 'get_user_usecase.dart'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

@Config(foo: bar(baz: true))
class GetUserUseCase extends UseCase<User, String> {
  final UserRepository _repository;
  GetUserUseCase(this._repository);

  @override
  Future<User> execute(String params) => _repository.get(params);
}
''');

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'User');

      expect(results, hasLength(1));
      expect(results.first.injected, isTrue);
      expect(results.first.message, isNot(contains('no `class')));

      final content = file.readAsStringSync();
      expect(content, contains('@XRayMock('));
      expect(content, contains('class GetUserUseCase'));

      // The existing nested-paren annotation is preserved.
      expect(content, contains('@Config(foo: bar(baz: true))'));

      // @XRayMock lands above the existing annotation, which stays above
      // the class declaration.
      final xrayIdx = content.indexOf('@XRayMock(');
      final configIdx = content.indexOf('@Config(');
      final classIdx = content.indexOf('class GetUserUseCase');
      expect(xrayIdx, greaterThanOrEqualTo(0));
      expect(configIdx, greaterThan(xrayIdx));
      expect(classIdx, greaterThan(configIdx));
    });
  });
}
