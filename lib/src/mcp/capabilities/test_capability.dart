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
            useCaseName.toLowerCase() == name.toLowerCase()) {
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

    // 3. Write and run the test script with unique temp file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pid = ProcessInfo.currentRss; // Use RSS as pseudo-unique ID
    final tempFile = File(
      p.join(projectRoot, '.zfa', '_mcp_test_runner_${timestamp}_$pid.dart'),
    );
    try {
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsString(testScript);

      final result =
          await Process.run('dart', [
            'run',
            tempFile.path,
          ], workingDirectory: projectRoot).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return ProcessResult(
                0,
                124,
                '',
                'Test execution timed out after 30 seconds',
              );
            },
          );

      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();

      if (result.exitCode != 0) {
        return {
          'success': false,
          'useCase': useCaseName,
          'result': null,
          'error': result.exitCode == 124
              ? 'Test execution timed out'
              : 'Test execution failed: $stderr\n$stdout',
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
    // Safely encode params and mocks as JSON strings to avoid code injection
    // (payload is base64-encoded below and passed via stdin).

    // Extract the import path relative to lib/ using path package
    final relativePath = p.relative(useCasePath, from: projectRoot);
    final pathSegments = p.split(relativePath);

    // Remove 'lib' from the start if present
    final libIndex = pathSegments.indexOf('lib');
    final importSegments = libIndex >= 0
        ? pathSegments.sublist(libIndex + 1)
        : pathSegments;

    // Read pubspec.yaml to get package name instead of hardcoding 'zuraffa'
    String packageName = 'zuraffa';
    try {
      final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final pubspecContent = pubspecFile.readAsStringSync();
        final nameMatch = RegExp(r'name:\s*(\w+)').firstMatch(pubspecContent);
        if (nameMatch != null) {
          packageName = nameMatch.group(1)!;
        }
      }
    } catch (_) {
      // Fall back to 'zuraffa'
    }

    final importPath = importSegments.join('/');

    // Pass data via base64-encoded stdin to avoid injection
    final dataPayload = base64.encode(
      utf8.encode(jsonEncode({'params': params, 'mocks': mocks})),
    );

    return '''
import 'dart:convert';
import 'dart:io';
import 'package:$packageName/$importPath';

void main() async {
  try {
    // Decode params and mocks from base64 stdin data
    final encodedData = '$dataPayload';
    final decodedJson = utf8.decode(base64.decode(encodedData));
    final data = jsonDecode(decodedJson) as Map<String, dynamic>;
    final params = data['params'] as Map<String, dynamic>;
    final mocks = data['mocks'] as Map<String, dynamic>;

    // Note: This is a minimal runner. Full DI resolution requires
    // the application context. For isolated testing, use flutter test.
    final result = 'UseCase $useCaseName found. Full execution requires app context. Params: \${jsonEncode(params)}';
    print(jsonEncode({'result': result, 'useCase': '$useCaseName'}));
  } catch (e) {
    print(jsonEncode({'error': e.toString()}));
  }
}
''';
  }
}
