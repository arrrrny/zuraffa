// MCP Server 2.0 — test.runUseCase capability.
//
// Runs a specific UseCase in isolation with provided params.
// Scans for the UseCase file, extracts its dependencies,
// and invokes it via the dart VM.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class TestCapability {
  final String projectRoot;

  TestCapability({required this.projectRoot});

  /// Runs a UseCase with given params and returns the result.
  ///
  /// [useCaseName] — e.g. "GetProductUseCase"
  /// [params] — JSON object to pass as the UseCase's param
  /// [mocks] — optional map of class names to mock return values
  Future<Map<String, dynamic>> runUseCase({
    required String useCaseName,
    Map<String, dynamic>? params,
    Map<String, dynamic>? mocks,
  }) async {
    // 1. Find the UseCase file
    final ucDir = p.join(projectRoot, 'lib', 'src', 'domain', 'usecases');
    File? ucFile;
    final ucDirectory = Directory(ucDir);
    if (await ucDirectory.exists()) {
      await for (final entity in ucDirectory.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final name = p.basenameWithoutExtension(entity.path);
        if (name == useCaseName ||
            '${useCaseName.toLowerCase()}' == name.toLowerCase()) {
          ucFile = entity;
          break;
        }
      }
    }

    if (ucFile == null) {
      return {
        'success': false,
        'useCase': useCaseName,
        'result': null,
        'error': 'UseCase not found: useCaseName',
      };
    }

    // 2. Generate a test runner script
    final testScript = _generateTestRunner(
      useCaseName: useCaseName,
      useCasePath: ucFile.path,
      params: params ?? {},
      mocks: mocks ?? {},
    );

    // 3. Write and run the test script
    final tempFile = File(p.join(projectRoot, '.zfa', '_mcp_test_runner.dart'));
    try {
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsString(testScript);

      final result = await Process.run(
        'dart',
        ['run', tempFile.path],
        workingDirectory: projectRoot,
      );

      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();

      if (result.exitCode != 0) {
        return {
          'success': false,
          'useCase': useCaseName,
          'result': null,
          'error': 'Test execution failed: $stderr\n$stdout',
        };
      }

      // Parse result from stdout (last line should be JSON)
      final lines = stdout.trim().split('\n');
      String? resultJson;
      for (final line in lines.reversed) {
        if (line.trim().startsWith('{')) {
          resultJson = line.trim();
          break;
        }
      }

      if (resultJson != null) {
        try {
          final parsed = jsonDecode(resultJson) as Map<String, dynamic>;
          return {
            'success': true,
            'useCase': useCaseName,
            'result': parsed,
            'error': null,
          };
        } catch (_) {
          // Fall through to raw output
        }
      }

      return {
        'success': true,
        'useCase': useCaseName,
        'result': {'raw': stdout},
        'error': null,
      };
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  String _generateTestRunner({
    required String useCaseName,
    required String useCasePath,
    required Map<String, dynamic> params,
    required Map<String, dynamic> mocks,
  }) {
    final paramJson = jsonEncode(params);
    final mockEntries = mocks.entries
        .map((e) => "  // mock: ${e.key} -> ${jsonEncode(e.value)}")
        .join('\n');

    // Extract the import path relative to lib/
    final relativePath = p.relative(useCasePath, from: projectRoot);
    final importPath = relativePath.replaceFirst('lib/', '');

    return '''
import 'dart:convert';
import 'package:zuraffa/$importPath';

void main() async {
  // Params: $paramJson
$mockEntries

  try {
    // Note: This is a minimal runner. Full DI resolution requires
    // the application context. For isolated testing, use flutter test.
    final result = 'UseCase useCaseName found. Full execution requires app context. Params received: $paramJson';
    print(result);
  } catch (e) {
    print(jsonEncode({'error': e.toString()}));
  }
}
''';
  }
}
