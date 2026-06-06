import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Stores and retrieves project context for AI agents.
///
/// The context file (`.zfa/context.json`) contains:
/// - Fixed domain root and entity output paths
/// - Zorphy-only entity assumptions
/// - Required workflow (entity create → make → build)
/// - Manual vs generated zones
class ProjectContextStore {
  final String projectRoot;

  ProjectContextStore({required this.projectRoot});

  File get _contextFile => File(p.join(projectRoot, '.zfa', 'context.json'));

  /// Saves the project context to `.zfa/context.json`.
  ///
  /// Also ensures the canonical `.zfa/` directory structure exists.
  Future<void> save(Map<String, dynamic> context) async {
    final zfaDir = Directory(p.join(projectRoot, '.zfa'));
    if (!zfaDir.existsSync()) {
      await zfaDir.create(recursive: true);
    }

    // Ensure canonical sub-directories exist.
    for (final subdir in const [
      'plans',
      'runs',
      'blueprints',
      'decisions',
      'manifests',
    ]) {
      final dir = Directory(p.join(zfaDir.path, subdir));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    await _contextFile.writeAsString(encoder.convert(context));
  }

  /// Loads the project context from `.zfa/context.json`.
  ///
  /// Returns `null` if the file does not exist.
  Future<Map<String, dynamic>?> load() async {
    final file = _contextFile;
    if (!file.existsSync()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Generates the default v5 agent contract context.
  static Map<String, dynamic> defaultContext() {
    return {
      'version': '5.1',
      'domain_root': 'lib/src/domain',
      'entity_output': 'lib/src/domain/entities',
      'zorphy_only': true,
      'workflow': ['zfa entity create', 'zfa make', 'zfa build'],
      'generated_zones': [
        'lib/src/domain/entities',
        'lib/src/domain/usecases',
        'lib/src/data/repositories',
        'lib/src/data/datasources',
        'lib/src/data/providers',
        'lib/src/data/services',
        'lib/src/presentation/controllers',
        'lib/src/presentation/presenters',
        'lib/src/presentation/state',
        'lib/src/di',
      ],
      'manual_zones': [
        'lib/src/presentation/pages/**/layouts',
        'lib/src/presentation/pages/**/widgets',
        'lib/src/presentation/shells',
        'lib/src/app',
      ],
      'notes': [
        'All entities must be created with `zfa entity create` and use Zorphy annotations.',
        'Architecture generation uses `zfa make` with presets/plugins.',
        'Code generation is finalized with `zfa build`.',
        'Manual UI composition belongs in pages/layouts and widgets.',
      ],
    };
  }
}
