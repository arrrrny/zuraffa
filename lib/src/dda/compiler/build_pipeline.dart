import 'dart:io';
import 'package:path/path.dart' as p;

import 'ast_scanner.dart';
import 'decorator_dispatcher.dart';
import 'plugin_discovery.dart';
import 'zorphy_decorator_plugin.dart';

/// Orchestrates the complete `zfa build` DDA pipeline.
class BuildPipeline {
  BuildPipeline({
    required this.projectRoot,
    String? outputDir,
    this.dryRun = false,
    this.verbose = false,
  }) : outputDir = outputDir ?? p.join(projectRoot, 'lib', 'src', 'generated');

  final String projectRoot;
  final String outputDir;
  final bool dryRun;
  final bool verbose;

  final _warnings = <String>[];
  final _errors = <String>[];
  final _generatedFiles = <String>[];

  List<String> get warnings => List.unmodifiable(_warnings);
  List<String> get errors => List.unmodifiable(_errors);
  List<String> get generatedFiles => List.unmodifiable(_generatedFiles);

  /// Run the full build pipeline.
  Future<BuildResult> run() async {
    _log('🚀 zfa build — DDA Pipeline');
    _log('📁 Project: $projectRoot');

    // ── Stage 1: Plugin Discovery ──
    _log('🔍 Discovering decorator plugins...');
    final plugins = _discoverPlugins();
    _log('   Found ${plugins.length} plugin(s)');

    // ── Stage 2: Build Start ──
    _log('🔧 Build start...');
    final config = _loadConfig();
    for (final plugin in plugins) {
      plugin.onBuildStart(config);
    }

    // ── Stage 3: AST Scan ──
    _log('🔎 Scanning AST for decorators...');
    final scanner = ASTScanner(projectRoot: p.join(projectRoot, 'lib'));
    final scanResults = await scanner.scan();
    _log('   Found ${scanResults.length} decorator annotation(s)');

    // ── Stage 4: Dispatch ──
    _log('⚡ Dispatching to plugins...');
    final dispatcher = DecoratorDispatcher(
      onUnknownDecorator: (name, loc) {
        final msg = 'Unknown decorator @$name${loc != null ? ' at $loc' : ''}';
        _warnings.add(msg);
        _log('   ⚠️  $msg');
      },
      onParseError: (e) {
        _errors.add(e.toString());
        _log('   ❌ $e');
      },
    );
    final generationResults = dispatcher.dispatch(scanResults);

    // ── Stage 5: Code Generation ──
    _log('📝 Generating code...');
    if (!dryRun) {
      await _emitGeneratedFiles(generationResults);
    } else {
      _log('   (dry-run — no files written)');
      for (final result in generationResults.values) {
        _log('   Would generate: ${_outputPath(result.filePath)}');
      }
    }

    // ── Stage 6: Build End ──
    _log('🏁 Build end...');
    for (final plugin in plugins) {
      plugin.onBuildEnd(config);
    }

    return BuildResult(
      success: _errors.isEmpty,
      warnings: warnings,
      errors: errors,
      generatedFiles: generatedFiles,
    );
  }

  Future<void> _emitGeneratedFiles(
    Map<String, GenerationResult> results,
  ) async {
    for (final entry in results.entries) {
      final outputPath = _outputPath(entry.key);
      final code = entry.value.generatePartFile();

      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(code);

      _generatedFiles.add(outputPath);
      _log('   ✅ $outputPath');
    }
  }

  List<ZorphyDecoratorPlugin> _discoverPlugins() {
    final discovery = PluginDiscovery(projectRoot: projectRoot);
    return discovery.discover();
  }

  Map<String, dynamic> _loadConfig() => {};

  String _outputPath(String sourcePath) {
    final basename = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$basename.g.dart');
  }

  void _log(String message) {
    if (verbose || message.startsWith('   ⚠️') || message.startsWith('   ❌')) {
      // ignore: avoid_print
      print(message);
    }
  }
}

class BuildResult {
  BuildResult({
    required this.success,
    this.warnings = const [],
    this.errors = const [],
    this.generatedFiles = const [],
  });

  final bool success;
  final List<String> warnings;
  final List<String> errors;
  final List<String> generatedFiles;
}
