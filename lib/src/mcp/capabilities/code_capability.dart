// MCP Server 2.0 — code.generateView capability.
//
// Generates a new view/controller/state trio for an entity by invoking
// the existing CodeGenerator with the appropriate flags.

import 'dart:convert';
import 'dart:io';

class CodeCapability {
  final String projectRoot;

  CodeCapability({required this.projectRoot});

  /// Generates a view/controller/state trio for [entityName].
  ///
  /// Returns a map with 'success', 'files', and 'message'.
  Future<Map<String, dynamic>> generateView({
    required String entityName,
    List<String>? methods,
    bool state = true,
    bool di = false,
  }) async {
    final args = ['make', entityName, '--with=vpc'];

    if (methods != null && methods.isNotEmpty) {
      args.add('--methods=${methods.join(',')}');
    }
    if (state) args.add('--state');
    if (di) args.add('--di');
    args.add('--format=json');

    final result = await Process.run('dart', [
      'run',
      'zuraffa:zfa',
      ...args,
    ], workingDirectory: projectRoot);

    final stdout = result.stdout.toString();
    final stderr = result.stderr.toString();

    if (result.exitCode != 0) {
      return {
        'success': false,
        'files': <String>[],
        'message': 'Generation failed: $stderr\n$stdout',
      };
    }

    // Parse generated file paths from JSON output
    final files = <String>[];
    try {
      final json = jsonDecode(stdout) as Map<String, dynamic>;
      final generatedFiles = json['files'] as List<dynamic>?;
      if (generatedFiles != null) {
        for (final f in generatedFiles) {
          if (f is Map<String, dynamic>) {
            files.add(f['path'] as String? ?? '');
          } else if (f is String) {
            files.add(f);
          }
        }
      }
    } catch (_) {
      // Fallback: try to extract file paths from text output
      final pathRegex = RegExp(r'lib/src/[\w/]+\.dart');
      files.addAll(pathRegex.allMatches(stdout).map((m) => m.group(0)!));
    }

    return {
      'success': true,
      'files': files,
      'message': 'Generated ${files.length} files for $entityName',
    };
  }
}
