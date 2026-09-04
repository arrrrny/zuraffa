/// CutSliceCapability (spec 043): slice extraction (US1, FR-001..FR-007).
///
/// Plan: dry-run file list. Execute: walk the graph, classify ownership,
/// copy the mirrored tree into `.zuraffa/slices/<name>/`, generate the mock
/// DI wiring, the runnable entry point, and the agent instructions, then
/// persist the manifest.
///
/// 073 composition: with declared facts (`feature`, `routes`,
/// `dependencies`) the cut also emits the runnable sandbox scaffolding
/// (shell bootstrap, router harness exposing exactly the declared
/// routes, mock-DI bindings for every declared dependency) and carries
/// the feature's spec + tdd receipts into the sandbox.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/ast/file_parser.dart';
import '../../../core/context/progress_reporter.dart';
import '../../../core/plugin_system/capability.dart';
import '../engine/import_graph_walker.dart';
import '../engine/ownership_classifier.dart';
import '../engine/package_resolver.dart';
import '../exporter/pubspec_filter.dart';
import '../generators/agent_readme_generator.dart';
import '../generators/manifest_writer.dart';
import '../generators/mock_stub_generator.dart';
import '../generators/sandbox_bootstrapper.dart';
import '../generators/sandbox_composition.dart';
import '../models/file_graph.dart';
import '../models/slice_depth.dart';
import '../models/slice_file.dart';
import '../models/slice_manifest.dart';

/// Cut a slice from the project into `.zuraffa/slices/<name>/`.
class CutSliceCapability implements ZuraffaCapability {
  /// Creates the capability with injectable collaborators.
  CutSliceCapability({
    ImportGraphWalker? walker,
    OwnershipClassifier? ownershipClassifier,
    MockStubGenerator? mockGenerator,
    SandboxBootstrapper? bootstrapper,
    AgentReadmeGenerator? readmeGenerator,
    ManifestWriter? manifestWriter,
    FileParser? parser,
  }) : _walker = walker ?? ImportGraphWalker(),
       _ownershipClassifier = ownershipClassifier ?? OwnershipClassifier(),
       _mockGenerator = mockGenerator ?? MockStubGenerator(),
       _bootstrapper = bootstrapper ?? SandboxBootstrapper(),
       _readmeGenerator = readmeGenerator ?? AgentReadmeGenerator(),
       _manifestWriter = manifestWriter ?? ManifestWriter(),
       _parser = parser ?? const FileParser();

  final ImportGraphWalker _walker;
  final OwnershipClassifier _ownershipClassifier;
  final MockStubGenerator _mockGenerator;
  final SandboxBootstrapper _bootstrapper;
  final AgentReadmeGenerator _readmeGenerator;
  final ManifestWriter _manifestWriter;
  final FileParser _parser;

  @override
  String get name => 'cut_slice';

  @override
  String get description =>
      'Extract a runnable, self-contained slice of the project from one or '
      'more entry points.';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'required': ['name', 'entries'],
    'properties': {
      'name': {'type': 'string'},
      'entries': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'depth': {
        'type': 'string',
        'enum': ['view', 'presentation', 'feature', 'full'],
      },
      'projectRoot': {'type': 'string'},
      'verify': {'type': 'boolean'},
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'success': {'type': 'boolean'},
      'sandbox': {'type': 'string'},
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  /// Sandbox root for [sliceName] under [projectRoot].
  static String sandboxDirFor(String projectRoot, String sliceName) {
    final safeName = validateSliceName(sliceName);
    final root = p.canonicalize(projectRoot);
    final sandbox = p.canonicalize(
      p.join(root, '.zuraffa', 'slices', safeName),
    );
    if (!p.isWithin(root, sandbox)) {
      throw ArgumentError.value(
        sliceName,
        'sliceName',
        'must be a path-safe slug that stays under the project root',
      );
    }
    return sandbox;
  }

  /// Validates a slice name is a separator-free slug that stays within the
  /// project root rather than escaping into sibling paths.
  static String validateSliceName(String sliceName) {
    final trimmed = sliceName.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') {
      throw ArgumentError.value(
        sliceName,
        'sliceName',
        'must be a non-empty, path-safe slice name --> fix: pass a slug like '
            '"login_feature" (issue #961)',
      );
    }
    if (trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.contains('..')) {
      throw ArgumentError.value(
        sliceName,
        'sliceName',
        'must not contain path separators or parent-directory traversal --> fix: '
            'pass a slug like "login_feature" (issue #961)',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(trimmed)) {
      throw ArgumentError.value(
        sliceName,
        'sliceName',
        'must contain only letters, numbers, underscores, or dashes --> fix: '
            'pass a slug like "login_feature" (issue #961)',
      );
    }
    return trimmed;
  }

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final entries = (args['entries'] as List).cast<String>();
    final depth = SliceDepth.parse(args['depth'] as String? ?? 'feature');

    try {
      final resolver = await PackageResolver.load(projectRoot);
      final entryPaths = _walker.resolveEntrySpecs(entries, projectRoot);
      final result = await _walker.walk(
        entries: entryPaths,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: depth,
      );
      final changes = [
        for (final path in result.graph.nodes.keys)
          Effect(
            file: p.relative(path, from: projectRoot),
            action: 'copy',
          ),
      ];
      return EffectReport(
        planId: 'cut-$sliceName',
        pluginId: 'slice',
        capabilityName: name,
        args: args,
        changes: changes,
      );
    } catch (e) {
      return EffectReport(
        planId: 'cut-$sliceName',
        pluginId: 'slice',
        capabilityName: name,
        args: args,
        isValid: false,
        message: e.toString(),
        changes: const [],
      );
    }
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final entries = (args['entries'] as List).cast<String>();
    final depth = SliceDepth.parse(args['depth'] as String? ?? 'feature');
    final feature = args['feature'] as String?;
    final List<ManifestRoute> declaredRoutes;
    final List<ManifestDependency> declaredDependencies;
    try {
      declaredRoutes = _parseRoutes(args['routes'] as List?);
      declaredDependencies = _parseDependencies(args['dependencies'] as List?);
    } on ArgumentError catch (e) {
      return ExecutionResult(
        success: false,
        message: e.toString(),
      );
    }
    if ((declaredRoutes.isNotEmpty || declaredDependencies.isNotEmpty) &&
        (feature == null || feature.isEmpty)) {
      return ExecutionResult(
        success: false,
        message:
            'Declared routes/dependencies need --feature <f> --> fix: pass '
            'the feature whose sandbox is being composed (issue #961).',
      );
    }
    final progress =
        args['progressReporter'] as ProgressReporter? ?? NullProgressReporter();

    late final String sandboxDir;
    try {
      sandboxDir = sandboxDirFor(projectRoot, sliceName);
    } on ArgumentError catch (e) {
      return ExecutionResult(success: false, message: e.toString());
    }
    if (Directory(sandboxDir).existsSync()) {
      return ExecutionResult(
        success: false,
        message:
            'A slice named "$sliceName" already exists at '
            '${p.relative(sandboxDir, from: projectRoot)} --> fix: choose '
            'another name or merge/delete the existing slice first '
            '(issue #961).',
      );
    }

    final PackageResolver resolver;
    try {
      resolver = await PackageResolver.load(projectRoot);
    } on PackageResolverError catch (e) {
      return ExecutionResult(success: false, message: e.message);
    }

    final List<String> entryPaths;
    try {
      entryPaths = _walker.resolveEntrySpecs(entries, projectRoot);
    } on EntryResolutionError catch (e) {
      return ExecutionResult(success: false, message: e.message);
    }

    progress.update(
      'walking the import graph from ${entryPaths.length} entry point(s)',
    );
    final walkResult = await _walker.walk(
      entries: entryPaths,
      projectRoot: projectRoot,
      resolver: resolver,
      depth: depth,
    );

    // Ownership: files under any entry's page directory are owned.
    final entryPageDirs = _entryPageDirs(entries, projectRoot);
    final manifestFiles = <SliceFile>[];
    for (final path in walkResult.graph.nodes.keys) {
      final rel = p.relative(path, from: projectRoot);
      manifestFiles.add(
        SliceFile(
          relativePath: rel,
          ownership: _ownershipClassifier.classify(
            relativePath: rel,
            entryPageDirs: entryPageDirs,
          ),
          hashAtCut: _hashOf(path),
          layer: classifyLayer(rel),
        ),
      );
    }
    manifestFiles.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    progress.update('generating boundary mocks');

    // Boundary mocks (FR-003) — depth-aware via the generator (U31).
    final generatedFiles = <String>[];
    final mockRegistrations = <MockRegistration>[];
    for (final boundary in walkResult.boundaries) {
      final interfaceIncluded = layerAllowedAtDepth(
        classifyLayer(boundary.interfaceFile),
        depth,
      );
      // Only copy the real interface file when it lives in an included layer.
      // At shallower depths a boundary may resolve to an excluded concrete file
      // (e.g. the concrete ProductPresenter at `--depth view`); copying it would
      // drag the excluded layer into the sandbox (A13 violation). The mock
      // generator emits an inline abstract interface for those instead.
      if (interfaceIncluded) {
        final interfaceTarget = p.join(sandboxDir, boundary.interfaceFile);
        final interfaceFile = File(p.join(projectRoot, boundary.interfaceFile));
        if (await interfaceFile.exists()) {
          await _copyFile(interfaceFile, interfaceTarget);
        }
      }
      final mock = await _mockGenerator.generate(
        boundary: boundary,
        projectRoot: projectRoot,
        sandboxRoot: sandboxDir,
        depth: depth,
      );
      if (mock == null) continue;
      final mockAbs = p.join(sandboxDir, mock.relativePath);
      await _writeFile(mockAbs, mock.content);
      generatedFiles.add(mock.relativePath);
      mockRegistrations.add(
        MockRegistration(
          typeName: boundary.typeName,
          mockClassName: 'Mock${boundary.typeName}',
          mockImportPath: _relativeImport(
            fromDir: p.join(sandboxDir, 'lib', 'src', 'di'),
            target: mockAbs,
          ),
          interfaceImportPath: interfaceIncluded
              ? _relativeImport(
                  fromDir: p.join(sandboxDir, 'lib', 'src', 'di'),
                  target: p.join(sandboxDir, boundary.interfaceFile),
                )
              : _relativeImport(
                  fromDir: p.join(sandboxDir, 'lib', 'src', 'di'),
                  target: mockAbs,
                ),
        ),
      );
    }

    // slice_di.dart: delegate real wiring to the project's included DI
    // registration files (U33) and register the boundary mocks.
    final realRegistrations = <RealDiCall>[];
    for (final nodePath in walkResult.graph.nodes.keys) {
      final rel = p.relative(nodePath, from: projectRoot);
      if (!rel.startsWith('lib/src/di/') || rel == 'lib/src/di/slice_di.dart') {
        continue;
      }
      final source = await File(nodePath).readAsString();
      for (final functionName in _topLevelFunctions(source)) {
        realRegistrations.add(
          RealDiCall(
            importPath: _relativeImport(
              fromDir: p.join(sandboxDir, 'lib', 'src', 'di'),
              target: p.join(sandboxDir, rel),
            ),
            functionName: functionName,
          ),
        );
      }
    }
    final sliceDiContent = _bootstrapper.generateSliceDi(
      sliceName: sliceName,
      realRegistrations: realRegistrations,
      mockRegistrations: mockRegistrations,
    );
    await _writeFile(
      p.join(sandboxDir, 'lib', 'src', 'di', 'slice_di.dart'),
      sliceDiContent,
    );
    generatedFiles.add('lib/src/di/slice_di.dart');

    // main_slice.dart exposing every entry root (U32, U34).
    final entryViews = <EntryView>[];
    for (var i = 0; i < entries.length; i++) {
      final entryPath = entryPaths[i];
      final entrySpec = entries[i];
      entryViews.add(
        EntryView(
          importPath: _packageImport(
            resolver.packageName,
            p.relative(entryPath, from: projectRoot),
          ),
          className: _classNameOf(entryPath),
          title: _titleOf(entrySpec, entryPath),
        ),
      );
    }
    final mainSliceContent = _bootstrapper.generateMainSlice(
      sliceName: sliceName,
      entryViews: entryViews,
    );
    await _writeFile(p.join(sandboxDir, 'main_slice.dart'), mainSliceContent);
    generatedFiles.add('main_slice.dart');

    // Manifest (FR-004).
    var manifest = SliceManifest(
      name: sliceName,
      createdAt: DateTime.now(),
      depth: depth,
      entries: [
        for (final entryPath in entryPaths)
          p.relative(entryPath, from: projectRoot),
      ],
      projectRoot: p.canonicalize(projectRoot),
      packageName: resolver.packageName,
      branch: _currentBranch(projectRoot),
      exportedTo: null,
      files: manifestFiles,
      boundaries: walkResult.boundaries,
      generatedFiles: generatedFiles,
      routes: declaredRoutes,
      dependencies: declaredDependencies,
    );

    // Copy the mirrored tree.
    progress.update('mirroring files into the sandbox');

    for (final file in manifestFiles) {
      final source = File(p.join(projectRoot, file.relativePath));
      final target = p.join(sandboxDir, file.relativePath);
      await _copyFile(source, target);
    }

    final filteredPubspec = await PubspecFilter().filter(
      projectRoot: projectRoot,
      sandboxDir: sandboxDir,
      sliceDartFiles: [for (final file in manifestFiles) file.relativePath],
    );
    await _writeFile(p.join(sandboxDir, 'pubspec.yaml'), filteredPubspec);
    generatedFiles.add('pubspec.yaml');

    // Filtered barrels (FR-005): mirror each encountered barrel at its
    // original path, exporting only the targets the slice kept, so barrel
    // imports resolve without pulling in the barrel's full contents.
    for (final entry in walkResult.barrels.entries) {
      final barrelRel = p.relative(entry.key, from: projectRoot);
      final barrelSandboxPath = p.join(sandboxDir, barrelRel);
      final buffer = StringBuffer()
        ..writeln(
          '// Filtered by `zfa slice cut` — exports only the symbols this '
          'slice uses (FR-005).',
        )
        ..writeln('library;');
      for (final keptTarget in entry.value) {
        // Re-emit the original export directive verbatim, with its
        // `show`/`hide` combinator preserved (FR-005), so the filtered
        // barrel stays faithful to the source instead of re-exporting the
        // whole kept target.
        buffer.writeln(keptTarget.directiveText);
      }
      await _writeFile(barrelSandboxPath, buffer.toString());
      generatedFiles.add(barrelRel);
    }

    // SLICE.md agent instructions (FR-007).
    final readme = _readmeGenerator.generate(manifest: manifest);
    await _writeFile(p.join(sandboxDir, 'SLICE.md'), readme);
    generatedFiles.add('SLICE.md');
    generatedFiles.add('slice.yaml');
    manifest = manifest.copyWith(generatedFiles: generatedFiles);

    progress.update('writing slice.yaml, SLICE.md, and the entry point');
    await _manifestWriter.write(manifest, sandboxDir);

    // 073 composition: with declared facts, emit the runnable-sandbox
    // scaffolding (shell, router harness, mock DI) and carry the
    // feature's spec + tdd receipts into the sandbox. All pure
    // generators of declared facts — identical inputs ⇒ byte-identical
    // wiring (FR-007).
    if (feature != null && feature.isNotEmpty) {
      progress.update('composing the runnable sandbox (shell/router/DI)');
      const SandboxComposition().compose(
        projectRoot: projectRoot,
        sandboxDir: sandboxDir,
        feature: feature,
        routes: declaredRoutes,
        dependencies: declaredDependencies,
        generatedFiles: generatedFiles,
      );
      manifest = manifest.copyWith(generatedFiles: generatedFiles);
      await _manifestWriter.write(manifest, sandboxDir);
    }

    return ExecutionResult(
      success: true,
      files: [
        p.relative(sandboxDir, from: projectRoot),
        ...manifestFiles.map((f) => f.relativePath),
      ],
      message:
          'Cut slice "$sliceName": ${manifestFiles.length} project files, '
          '${walkResult.boundaries.length} boundary '
          '${walkResult.boundaries.length == 1 ? 'interface' : 'interfaces'}.',
      data: {
        'sandbox': p.relative(sandboxDir, from: projectRoot),
        'fileCount': manifestFiles.length,
        'boundaries': [for (final b in walkResult.boundaries) b.typeName],
        'warnings': walkResult.warnings,
      },
    );
  }

  /// Parses declared `--route <path>:<Page>` values.
  List<ManifestRoute> _parseRoutes(List? raw) {
    if (raw == null) return const [];
    return [
      for (final entry in raw.cast<String>())
        if (entry.trim().isNotEmpty)
          () {
            final sep = entry.indexOf(':');
            if (sep <= 0 || sep == entry.length - 1) {
              throw ArgumentError.value(
                entry,
                'routes',
                "must be '<path>:<Page>' --> fix: declare routes as "
                "'/login:LoginPage' (issue #961)",
              );
            }
            return ManifestRoute(
              path: entry.substring(0, sep),
              page: entry.substring(sep + 1),
            );
          }(),
    ];
  }

  /// Parses declared `--dependency <Name>:<kind>:<contract>:<priority>:<artifact>`
  /// values (the 072 declared rows, plus the certified artifact path).
  List<ManifestDependency> _parseDependencies(List? raw) {
    if (raw == null) return const [];
    return [
      for (final entry in raw.cast<String>())
        if (entry.trim().isNotEmpty)
          () {
            final parts = entry.split(':');
            if (parts.length != 5) {
              throw ArgumentError.value(
                entry,
                'dependencies',
                "must be '<Name>:<kind>:<contract>:<priority>:<artifact>' -- "
                'fix: declare each dependency row with its contract and '
                'certified mock path (issue #961)',
              );
            }
            return ManifestDependency(
              dependency: parts[0],
              kind: parts[1],
              contract: parts[2],
              priority: parts[3],
              mockArtifact: parts[4],
            );
          }(),
    ];
  }

  /// The certified fake + contract splitting live in
  /// [SandboxComposition] (the sync core cut and subjects share).

  /// Page directories owning files, one per entry spec.
  List<String> _entryPageDirs(List<String> entries, String projectRoot) {
    final dirs = <String>[];
    for (final spec in entries) {
      final isPath =
          spec.endsWith('.dart') ||
          spec.contains('/') ||
          spec.contains(p.separator);
      if (!isPath) {
        dirs.add('lib/src/presentation/pages/$spec');
        continue;
      }
      final abs = p.canonicalize(
        p.isAbsolute(spec) ? spec : p.join(projectRoot, spec),
      );
      final rel = p.relative(abs, from: projectRoot);
      if (rel.startsWith('lib/src/presentation/pages/')) {
        // The page directory is the first path segment under pages/.
        final rest = rel.substring('lib/src/presentation/pages/'.length);
        final feature = rest.split('/').first;
        dirs.add('lib/src/presentation/pages/$feature');
      }
    }
    return dirs;
  }

  List<String> _topLevelFunctions(String source) {
    final unit = _parser.parseSource(source).unit;
    if (unit == null) return const [];
    return unit.declarations
        .whereType<FunctionDeclaration>()
        .map((f) => f.name.toString())
        .toList();
  }

  String _hashOf(String path) {
    final bytes = File(path).readAsBytesSync();
    return sha256.convert(bytes).toString();
  }

  String _relativeImport({required String fromDir, required String target}) {
    var rel = p.relative(target, from: fromDir);
    rel = rel.replaceAll('\\', '/');
    if (!rel.startsWith('.')) rel = './$rel';
    // The bootstrapper test asserts bare relative paths for same-dir files;
    // keep `./` off when the target sits next to the importer.
    return rel.startsWith('./') && !rel.contains('/') ? rel.substring(2) : rel;
  }

  String _packageImport(String packageName, String relPath) {
    // Package URIs address the package root, which is `lib/` — strip it.
    final packagePath = relPath.startsWith('lib/')
        ? relPath.substring('lib/'.length)
        : relPath;
    return 'package:$packageName/$packagePath';
  }

  String _classNameOf(String entryPath) {
    final base = p.basenameWithoutExtension(entryPath);
    final words = base.split(RegExp(r'[_\-]+')).where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join();
  }

  String _titleOf(String entrySpec, String entryPath) {
    if (!entrySpec.contains('/') && !entrySpec.endsWith('.dart')) {
      return entrySpec[0].toUpperCase() + entrySpec.substring(1);
    }
    return _classNameOf(entryPath);
  }

  String _currentBranch(String projectRoot) {
    final gitHead = File(p.join(projectRoot, '.git', 'HEAD'));
    if (gitHead.existsSync()) {
      final content = gitHead.readAsStringSync().trim();
      if (content.startsWith('ref: refs/heads/')) {
        return content.substring('ref: refs/heads/'.length);
      }
    }
    return 'unknown';
  }

  Future<void> _writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<void> _copyFile(File source, String targetPath) async {
    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }
}
