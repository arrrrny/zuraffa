import 'dart:io';
import 'package:path/path.dart' as p;

import 'ast_scanner.dart';
import 'decorator_dispatcher.dart';
import 'plugin_discovery.dart';
import 'zorphy_decorator_plugin.dart';
import '../plugins/route/route_plugin.dart';
import '../plugins/cache/cache_plugin.dart';
import '../plugins/middleware/auth_plugin.dart';
import '../plugins/middleware/retry_plugin.dart';
import '../plugins/middleware/track_event_plugin.dart';

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
      try {
        plugin.onBuildStart(config);
      } catch (e) {
        _errors.add('Plugin ${plugin.targetDecorator} onBuildStart failed: $e');
      }
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
        _log(msg, force: true);
      },
      onParseError: (e) {
        _errors.add(e.toString());
        _log(e.toString(), force: true);
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

    // ── Stage 5.5: Route Generation ──
    _log('🗺️  Generating router config...');
    if (!dryRun) {
      await _generateRouteConfig();
    } else {
      final routePlugin = ZorphyPluginRegistry.get('Route');
      if (routePlugin is RouteDDAPlugin && routePlugin.hasRoutes) {
        _log(
          '   (dry-run — would generate: lib/src/routing/zfa_router.g.dart)',
        );
      }
    }

    // ── Stage 5.6: Cache Generation ──
    _log('💾 Generating cache layer...');
    if (!dryRun) {
      await _generateCacheConfig();
    } else {
      final cachePlugin = ZorphyPluginRegistry.get('Cacheable');
      if (cachePlugin is CacheDDAPlugin && cachePlugin.hasCacheEntries) {
        _log('   (dry-run — would generate: lib/src/cache/zfa_cache.g.dart)');
      }
    }

    // ── Stage 5.7: Auth Middleware Generation ──
    _log('🛡️  Generating auth middleware...');
    if (!dryRun) {
      await _generateAuthConfig();
    } else {
      final authPlugin = ZorphyPluginRegistry.get('RequiresAuth');
      if (authPlugin is AuthDDAPlugin && authPlugin.hasAuthEntries) {
        _log(
          '   (dry-run — would generate: lib/src/middleware/zfa_auth.g.dart)',
        );
      }
    }

    // ── Stage 5.8: Retry Middleware Generation ──
    _log('🔄  Generating retry middleware...');
    if (!dryRun) {
      await _generateRetryConfig();
    } else {
      final retryPlugin = ZorphyPluginRegistry.get('Retry');
      if (retryPlugin is RetryDDAPlugin && retryPlugin.hasRetryEntries) {
        _log(
          '   (dry-run — would generate: lib/src/middleware/zfa_retry.g.dart)',
        );
      }
    }

    // ── Stage 5.9: TrackEvent Middleware Generation ──
    _log('📊  Generating event tracking middleware...');
    if (!dryRun) {
      await _generateTrackEventConfig();
    } else {
      final trackPlugin = ZorphyPluginRegistry.get('TrackEvent');
      if (trackPlugin is TrackEventDDAPlugin &&
          trackPlugin.hasTrackEventEntries) {
        _log(
          '   (dry-run — would generate: lib/src/middleware/zfa_events.g.dart)',
        );
      }
    }

    // ── Stage 6: Build End ──
    _log('🏁 Build end...');
    for (final plugin in plugins) {
      try {
        plugin.onBuildEnd(config);
      } catch (e) {
        _errors.add('Plugin ${plugin.targetDecorator} onBuildEnd failed: $e');
      }
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

  Map<String, dynamic> _loadConfig() => {'projectRoot': projectRoot};

  String _outputPath(String sourcePath) {
    // Preserve the relative path structure from projectRoot/lib
    final libDir = p.join(projectRoot, 'lib');
    final relative = p.relative(sourcePath, from: libDir);
    final dir = p.dirname(relative);
    final basename = p.basenameWithoutExtension(relative);
    return p.join(outputDir, dir, '$basename.g.dart');
  }

  Future<void> _generateRouteConfig() async {
    final routePlugin = ZorphyPluginRegistry.get('Route');
    if (routePlugin is! RouteDDAPlugin) return;
    if (!routePlugin.hasRoutes) return;

    try {
      final code = routePlugin.generateRouterFile();
      final outputPath = p.join(
        projectRoot,
        'lib',
        'src',
        'routing',
        'zfa_router.g.dart',
      );

      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(code);

      _generatedFiles.add(outputPath);
      _log('   ✅ $outputPath');
    } catch (e) {
      _errors.add('Route generation failed: $e');
    }
  }

  Future<void> _generateCacheConfig() async {
    final cachePlugin = ZorphyPluginRegistry.get('Cacheable');
    if (cachePlugin is! CacheDDAPlugin) return;
    if (!cachePlugin.hasCacheEntries) return;

    try {
      final code = cachePlugin.generateCacheFile();
      final outputPath = p.join(
        projectRoot,
        'lib',
        'src',
        'cache',
        'zfa_cache.g.dart',
      );

      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(code);

      _generatedFiles.add(outputPath);
      _log('   ✅ $outputPath');
    } catch (e) {
      _errors.add('Cache generation failed: $e');
    }
  }

  Future<void> _generateAuthConfig() async {
    final authPlugin = ZorphyPluginRegistry.get('RequiresAuth');
    if (authPlugin is! AuthDDAPlugin) return;
    if (!authPlugin.hasAuthEntries) return;
    try {
      final code = authPlugin.generateAuthFile();
      final outputPath = p.join(
        projectRoot,
        'lib',
        'src',
        'middleware',
        'zfa_auth.g.dart',
      );
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(code);
      _generatedFiles.add(outputPath);
      _log('   \u2705 $outputPath');
    } catch (e) {
      _errors.add('Auth generation failed: $e');
    }
  }

  Future<void> _generateRetryConfig() async {
    final retryPlugin = ZorphyPluginRegistry.get('Retry');
    if (retryPlugin is! RetryDDAPlugin) return;
    if (!retryPlugin.hasRetryEntries) return;
    try {
      final code = retryPlugin.generateRetryFile();
      final outputPath = p.join(
        projectRoot,
        'lib',
        'src',
        'middleware',
        'zfa_retry.g.dart',
      );
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(code);
      _generatedFiles.add(outputPath);
      _log('   \u2705 $outputPath');
    } catch (e) {
      _errors.add('Retry generation failed: $e');
    }
  }

  Future<void> _generateTrackEventConfig() async {
    final trackPlugin = ZorphyPluginRegistry.get('TrackEvent');
    if (trackPlugin is! TrackEventDDAPlugin) return;
    if (!trackPlugin.hasTrackEventEntries) return;
    try {
      final code = trackPlugin.generateTrackEventFile();
      final outputPath = p.join(
        projectRoot,
        'lib',
        'src',
        'middleware',
        'zfa_events.g.dart',
      );
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(code);
      _generatedFiles.add(outputPath);
      _log('   \u2705 $outputPath');
    } catch (e) {
      _errors.add('TrackEvent generation failed: $e');
    }
  }

  void _log(String message, {bool force = false}) {
    if (verbose || force) {
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
