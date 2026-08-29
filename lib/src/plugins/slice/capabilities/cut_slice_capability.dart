/// CutSliceCapability (spec 043): slice extraction (US1, FR-001..FR-007).
///
/// Plan: dry-run file list. Execute: walk the graph, classify ownership,
/// copy the mirrored tree into `.zuraffa/slices/<name>/`, generate the mock
/// DI wiring, the runnable entry point, and the agent instructions, then
/// persist the manifest.
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
import '../generators/agent_readme_generator.dart';
import '../generators/manifest_writer.dart';
import '../generators/mock_stub_generator.dart';
import '../generators/sandbox_bootstrapper.dart';
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
      'entries': {'type': 'array', 'items': {'type': 'string'}},
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
      'files': {'type': 'array', 'items': {'type': 'string'}},
    },
  };

  /// Sandbox root for [sliceName] under [projectRoot].
  static String sandboxDirFor(String projectRoot, String sliceName) =>
      p.join(projectRoot, '.zuraffa', 'slices', sliceName);

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final projectRoot = args['projectRoot'] as String? ?? Directory.current.path;
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
    final progress =
        args['progressReporter'] as ProgressReporter? ??
        NullProgressReporter();

    final sandboxDir = sandboxDirFor(projectRoot, sliceName);
    if (Directory(sandboxDir).existsSync()) {
      return ExecutionResult(
        success: false,
        message:
            'A slice named "$sliceName" already exists at '
            '${p.relative(sandboxDir, from: projectRoot)}. Choose another '
            'name or merge/delete the existing slice first.',
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
      final mock = await _mockGenerator.generate(
        boundary: boundary,
        projectRoot: projectRoot,
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
            target: p.join(sandboxDir, mock.relativePath),
          ),
          interfaceImportPath: _relativeImport(
            fromDir: p.join(sandboxDir, 'lib', 'src', 'di'),
            target: p.join(projectRoot, boundary.interfaceFile),
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
              target: nodePath,
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
    );

    // Copy the mirrored tree.
    progress.update('mirroring files into the sandbox');

    for (final file in manifestFiles) {
      final source = File(p.join(projectRoot, file.relativePath));
      final target = p.join(sandboxDir, file.relativePath);
      await _copyFile(source, target);
    }

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
        final keptRel = p.relative(keptTarget, from: projectRoot);
        var exportUri = p.relative(
          p.join(sandboxDir, keptRel),
          from: p.dirname(barrelSandboxPath),
        );
        exportUri = exportUri.replaceAll('\\', '/');
        buffer.writeln("export '$exportUri';");
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
        'boundaries': [
          for (final b in walkResult.boundaries) b.typeName,
        ],
        'warnings': walkResult.warnings,
      },
    );
  }

  /// Page directories owning files, one per entry spec.
  List<String> _entryPageDirs(List<String> entries, String projectRoot) {
    final dirs = <String>[];
    for (final spec in entries) {
      final isPath =
          spec.endsWith('.dart') || spec.contains('/') || spec.contains(p.separator);
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

  String _relativeImport({
    required String fromDir,
    required String target,
  }) {
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
    return words
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join();
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
