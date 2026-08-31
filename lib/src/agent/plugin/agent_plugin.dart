/// AgentPlugin — generates [McpTool] wrappers for every generated UseCase
/// when invoked via `zfa make Foo --agent` (FR-001 through FR-010).
///
/// Registered with id `agent` in [PluginLoader]. The `--agent` flag is
/// auto-registered by `make_command._addPluginOptions`. The plugin
/// activates when:
///   - the `--agent` flag is parsed (any value — explicit flag wins,
///     per FR-003), OR
///   - the project config (`.zfa.json` → `plugins.defaults.agent: true`)
///     enables `agent` by default, AND the user has not passed `--no-agent`.
///
/// When active, the plugin:
///   1. Introspects the entity's usecase directory (FR-004).
///   2. Detects canonical-tool-name collisions BEFORE writing any files
///      (FR-009).
///   3. Emits one tool wrapper file per usecase under
///      `lib/src/agent/tools/{entity}_{verb}_tool.dart` (FR-005).
///   4. Emits a `manifest.dart` barrel with name/entity/risk tier (FR-007).
///   5. Uses [GeneratedMarkerMerger] to preserve manual edits outside
///      the `// GENERATED - DO NOT EDIT ... // END GENERATED` markers
///      (FR-008, FR-009).
///   6. Sweeps the tools directory for orphaned (no-longer-referenced)
///      tool files and deletes them (FR-008).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/context/file_system.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import 'generated_marker_merger.dart';
import 'manifest_emitter.dart';
import 'manifest_entry.dart';
import 'tool_namespace.dart';
import 'tool_wrapper_emitter.dart';
import 'usecase_introspector.dart';

/// [AgentPlugin] — generates McpTool wrappers for every UseCase (FR-001).
class AgentPlugin extends FileGeneratorPlugin {
  /// The default namespace prefix for generated tool names (FR-005).
  static const String kDefaultNamespace = 'app';

  final String outputDir;

  final GeneratorOptions options;
  final FileSystem fileSystem;

  /// Overrides the namespace (e.g. from project config). If null,
  /// defaults to [kDefaultNamespace].
  final String? namespaceOverride;

  /// Overrides the project root used to locate the entity's usecase
  /// directory. When null, [Directory.current] is used (the legacy behavior,
  /// retained for `zfa make Foo --agent` invoked from a real project where
  /// CWD is the project root). Tests pass the temp fixture root here instead
  /// of mutating the shared process-global working directory — which
  /// concurrently-running tests corrupt (the CWD race, issue #441).
  final String? projectRootOverride;

  AgentPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
    this.namespaceOverride,
    this.projectRootOverride,
  }) : fileSystem = fileSystem ?? const DefaultFileSystem();

  @override
  String get id => 'agent';

  @override
  String get name => 'Agent Plugin';

  @override
  String get version => '1.0.0';

  /// Runs after usecase generation so the usecase files exist on disk
  /// when we introspect them.
  @override
  List<String> get dependsOn => const ['usecase'];

  /// Returns the namespace to apply to generated tool names, defaulting
  /// to [kDefaultNamespace] unless an override is configured.
  String get effectiveNamespace => namespaceOverride ?? kDefaultNamespace;

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig.fromJson(context.data, context.core.name);
    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    final entityName = config.name;
    if (entityName.isEmpty) {
      return const <GeneratedFile>[];
    }

    final projectRoot = _resolveProjectRoot();
    final introspector = UseCaseIntrospector(projectRoot: projectRoot);
    final useCases = await introspector.introspect(entityName);
    if (useCases.isEmpty) {
      return const <GeneratedFile>[];
    }

    // FR-009: detect canonical-name collisions before writing.
    final detector = CollisionDetector();
    for (final uc in useCases) {
      final canonical = canonicalToolName(
        namespace: effectiveNamespace,
        entitySnake: _toSnake(entityName),
        verb: uc.verb,
      );
      detector.register(canonical: canonical, entity: entityName);
    }

    final files = <GeneratedFile>[];
    final toolsDir = p.join(outputDir, 'agent', 'tools');
    final emitter = ToolWrapperEmitter(
      namespace: effectiveNamespace,
      entitySnake: _toSnake(entityName),
      packageRoot: _resolvePackageRoot(projectRoot),
    );

    final manifestEntries = <ToolManifestEntry>[];

    for (final uc in useCases) {
      final emitted = emitter.emit(uc);
      final filePath = p.join(toolsDir, emitted.fileName);

      final newGeneratedBlock = emitted.source;

      // Read existing content (if any).
      String? existing;
      if (await fileSystem.exists(filePath)) {
        existing = await fileSystem.read(filePath);
      }

      // Merge (idempotent — FR-008) OR throw (FR-009) on conflict.
      final merged = mergeOrFresh(
        existing: existing,
        newGeneratedContent: newGeneratedBlock,
        filePath: filePath,
      );

      final generated = await FileUtils.writeFile(
        filePath,
        merged,
        'agent_tool',
        force:
            config.force ||
            true, // Always write — idempotency is via the merger
        dryRun: config.dryRun,
        verbose: config.verbose,
        revert: config.revert,
        fileSystem: fileSystem,
      );
      files.add(generated);

      final canonical = canonicalToolName(
        namespace: effectiveNamespace,
        entitySnake: _toSnake(entityName),
        verb: uc.verb,
      );
      manifestEntries.add(
        ToolManifestEntry(
          name: canonical,
          entity: _toSnake(entityName),
          riskTier: uc.isAgentInternal ? 'admin' : 'safe',
        ),
      );
    }

    // Emit manifest.
    final manifestPath = p.join(toolsDir, 'manifest.dart');
    final manifestSource = buildManifestSource(manifestEntries);
    String? existingManifest;
    if (await fileSystem.exists(manifestPath)) {
      existingManifest = await fileSystem.read(manifestPath);
    }
    final mergedManifest = mergeOrFresh(
      existing: existingManifest,
      newGeneratedContent: manifestSource,
      filePath: manifestPath,
    );
    files.add(
      await FileUtils.writeFile(
        manifestPath,
        mergedManifest,
        'agent_manifest',
        force: config.force || true,
        dryRun: config.dryRun,
        verbose: config.verbose,
        revert: config.revert,
        fileSystem: fileSystem,
      ),
    );

    // FR-008: sweep stale tool files for THIS entity (files that have
    // GENERATED markers but don't correspond to any newly emitted verb).
    if (!config.dryRun && !config.revert) {
      await _sweepStaleTools(
        toolsDir: toolsDir,
        entitySnake: _toSnake(entityName),
        activeVerbs: useCases.map((u) => u.verb).toSet(),
        fileSystem: fileSystem,
        files: files,
      );
    }

    return files;
  }

  /// Deletes orphaned generated tool files in [toolsDir] for [entitySnake]
  /// that no longer correspond to a usecase verb. Only deletes files
  /// that contain `// GENERATED - DO NOT EDIT` markers — manual tool
  /// files in this directory are NEVER deleted (FR-008).
  Future<void> _sweepStaleTools({
    required String toolsDir,
    required String entitySnake,
    required Set<String> activeVerbs,
    required FileSystem fileSystem,
    required List<GeneratedFile> files,
  }) async {
    if (!await fileSystem.exists(toolsDir)) return;
    final dir = Directory(toolsDir);
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('${entitySnake}_')) continue;
      if (!name.endsWith('_tool.dart')) continue;
      // Extract the verb from the filename.
      // Filename: `{entitySnake}_{verb}_tool.dart`.
      final stripped = name
          .substring(entitySnake.length + 1)
          .replaceAll('_tool.dart', '');
      final verb = stripped;
      if (activeVerbs.contains(verb)) continue;
      // Check the file has GENERATED markers — only delete if so.
      final content = entity.readAsStringSync();
      if (!content.contains(kGeneratedStartMarker)) continue;
      final deleted = await FileUtils.deleteFile(
        entity.path,
        'agent_tool',
        dryRun: false,
        verbose: false,
        fileSystem: fileSystem,
      );
      files.add(deleted);
    }
  }

  String _resolveProjectRoot() {
    // Prefer an explicit override (set by tests / callers that target a temp
    // fixture). Fall back to CWD for CLI invocation from a real project root.
    return projectRootOverride ?? Directory.current.path;
  }

  String _resolvePackageRoot(String projectRoot) {
    // Derive package name from pubspec.yaml `name:` field.
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return 'package:app/';
    final lines = pubspec.readAsLinesSync();
    for (final line in lines) {
      final m = RegExp(r'^name:\s*(\S+)').firstMatch(line);
      if (m != null) {
        return 'package:${m.group(1)!}/';
      }
    }
    return 'package:app/';
  }

  String _toSnake(String s) {
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c.toUpperCase() == c && c.toLowerCase() != c) {
        if (i > 0) buf.write('_');
        buf.write(c.toLowerCase());
      } else {
        buf.write(c);
      }
    }
    return buf.toString().toLowerCase();
  }
}
