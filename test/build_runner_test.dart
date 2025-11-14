import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/src/build_runner.dart';

void main() {
  group('BuildRunnerManager', () {
    late String testProjectPath;
    late BuildRunnerManager manager;

    setUp(() {
      testProjectPath = Directory.systemTemp
          .createTempSync('zuraffa_test_')
          .path;
      manager = BuildRunnerManager(testProjectPath);
    });

    tearDown(() {
      // Cleanup
      try {
        Directory(testProjectPath).deleteSync(recursive: true);
      } catch (_) {}
    });

    group('needsGeneration', () {
      test('should return false when lib directory does not exist', () async {
        final result = await manager.needsGeneration();
        expect(result, false);
      });

      test('should return false when no @morphy files exist', () async {
        // Create lib directory with regular dart file
        Directory('$testProjectPath/lib').createSync();
        File('$testProjectPath/lib/test.dart').writeAsStringSync('''
class MyClass {
  final String name;
}
''');

        final result = await manager.needsGeneration();
        expect(result, false);
      });

      test('should return true when @morphy file exists without .g.dart', () async {
        Directory('$testProjectPath/lib').createSync();
        File('$testProjectPath/lib/product.dart').writeAsStringSync('''
@morphy
@Morphy(generateJson: true)
abstract class \$Product {
  String get id;
}
''');

        final result = await manager.needsGeneration();
        expect(result, true);
      });

      test('should return false when @morphy file has corresponding .g.dart', () async {
        Directory('$testProjectPath/lib').createSync();
        File('$testProjectPath/lib/product.dart').writeAsStringSync('''
@morphy
abstract class \$Product {
  String get id;
}
''');
        File('$testProjectPath/lib/product.g.dart').writeAsStringSync('''
// Generated file
class Product {
  final String id;
}
''');

        final result = await manager.needsGeneration();
        expect(result, false);
      });

      test('should detect @Morphy annotation (capital M)', () async {
        Directory('$testProjectPath/lib').createSync();
        File('$testProjectPath/lib/user.dart').writeAsStringSync('''
@Morphy(generateJson: true)
abstract class \$User {
  String get name;
}
''');

        final result = await manager.needsGeneration();
        expect(result, true);
      });
    });

    // Note: _findGeneratedFiles() is private and tested indirectly through integration tests

    group('BuildRunnerResult', () {
      test('should format result with generated files', () {
        final result = BuildRunnerResult(
          success: true,
          exitCode: 0,
          stdout: 'Build completed',
          stderr: '',
          generatedFiles: [
            'lib/domain/entities/product.g.dart',
            'lib/domain/entities/user.g.dart',
          ],
        );

        final string = result.toString();

        expect(string, contains('Success: true'));
        expect(string, contains('Exit Code: 0'));
        expect(string, contains('Generated Files: 2'));
        expect(string, contains('product.g.dart'));
        expect(string, contains('user.g.dart'));
      });

      test('should include errors in output', () {
        final result = BuildRunnerResult(
          success: false,
          exitCode: 1,
          stdout: '',
          stderr: 'Build failed: missing annotation',
          generatedFiles: [],
        );

        final string = result.toString();

        expect(string, contains('Success: false'));
        expect(string, contains('Exit Code: 1'));
        expect(string, contains('Errors:'));
        expect(string, contains('missing annotation'));
      });
    });
  });
}
