/// ImportGraphWalker (spec 043): dependency traversal (FR-001, FR-002).
///
/// Dual-path traversal (research R-001/R-002): import resolution walks the
/// syntactic import graph, and service-locator analysis adds the types a
/// file resolves through `getIt<T>()` that imports alone never reveal.
/// Barrels expand selectively (FR-005), companions ride along (FR-006), and
/// depth gates stop traversal at architecture boundaries (FR-002) while
/// recording the interfaces at the edge as slice boundaries.
library;

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'package:analyzer/dart/ast/visitor.dart';

import '../../../core/ast/file_parser.dart';
import '../models/file_graph.dart';
import '../models/slice_boundary.dart';
import '../models/slice_depth.dart';
import 'barrel_resolver.dart';
import 'companion_detector.dart';
import 'package_resolver.dart';
import 'service_locator_analyzer.dart';

/// Error raised when an entry point cannot be resolved (U22).
class EntryResolutionError implements Exception {
  /// Creates the error with a user-facing [message].
  const EntryResolutionError(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'EntryResolutionError: $message';
}

/// The result of one walk.
class WalkResult {
  /// Creates the result.
  const WalkResult({
    required this.graph,
    required this.boundaries,
    required this.warnings,
    this.barrels = const {},
  });

  /// The included-file graph.
  final FileGraph graph;

  /// Interfaces at the traversal edge.
  final List<SliceBoundary> boundaries;

  /// Non-fatal warnings (missing companions, unresolved imports, etc.).
  final List<String> warnings;

  /// Barrel files encountered during the walk, mapped to the targets the
  /// slice actually kept (FR-005). The cut writes a FILTERED barrel at the
  /// original path so the importer's barrel import still resolves without
  /// pulling in the whole barrel's contents.
  final Map<String, List<String>> barrels;
}

/// One import directive: its URI and any `show` symbols.
class _ImportInfo {
  const _ImportInfo(this.uri, this.shownSymbols);

  final String uri;
  final List<String> shownSymbols;
}

/// Walks the import graph from entry points at a depth.
class ImportGraphWalker {
  /// Creates the walker with injectable collaborators (tests pass fakes).
  ImportGraphWalker({
    FileParser? parser,
    BarrelResolver? barrelResolver,
    ServiceLocatorAnalyzer? serviceLocatorAnalyzer,
    CompanionDetector? companionDetector,
  }) : _parser = parser ?? const FileParser(),
       _barrelResolver = barrelResolver ?? BarrelResolver(),
       _serviceLocatorAnalyzer =
           serviceLocatorAnalyzer ?? ServiceLocatorAnalyzer(),
       _companionDetector = companionDetector ?? CompanionDetector();

  final FileParser _parser;
  final BarrelResolver _barrelResolver;
  final ServiceLocatorAnalyzer _serviceLocatorAnalyzer;
  final CompanionDetector _companionDetector;

  /// Resolves entry specs (page names like `product`, or file paths) to
  /// absolute entry file paths (U22).
  List<String> resolveEntrySpecs(List<String> entrySpecs, String projectRoot) {
    final resolved = <String>[];
    for (final spec in entrySpecs) {
      resolved.add(_resolveOneEntry(spec, projectRoot));
    }
    return resolved;
  }

  String _resolveOneEntry(String spec, String projectRoot) {
    final isPath = spec.endsWith('.dart') || spec.contains('/') || spec.contains(p.separator);
    if (isPath) {
      final candidate = p.canonicalize(
        p.isAbsolute(spec) ? spec : p.join(projectRoot, spec),
      );
      if (File(candidate).existsSync()) return candidate;
      throw EntryResolutionError(
        'Entry point not found: tried "$candidate" (from "$spec"). Pass a '
        'page name (e.g. `--entry product`) or a path to an existing Dart '
        'file.${_availablePages(projectRoot)}',
      );
    }

    // Page name: Zuraffa convention lib/src/presentation/pages/<n>/<n>_view.dart
    final candidate = p.canonicalize(
      p.join(
        projectRoot,
        'lib',
        'src',
        'presentation',
        'pages',
        spec,
        '${spec}_view.dart',
      ),
    );
    if (File(candidate).existsSync()) return candidate;
    throw EntryResolutionError(
      'Entry point not found: tried "$candidate" (from page name "$spec").'
      '${_availablePages(projectRoot)}',
    );
  }

  String _availablePages(String projectRoot) {
    final pagesDir = Directory(
      p.join(projectRoot, 'lib', 'src', 'presentation', 'pages'),
    );
    if (!pagesDir.existsSync()) {
      return ' No page directories exist under lib/src/presentation/pages/.';
    }
    final pages = pagesDir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList()
          ..sort();
    if (pages.isEmpty) {
      return ' No page directories exist under lib/src/presentation/pages/.';
    }
    return ' Available pages: ${pages.join(', ')}.';
  }

  /// Walks from [entries] (absolute paths) building the included-file graph.
  Future<WalkResult> walk({
    required List<String> entries,
    required String projectRoot,
    required PackageResolver resolver,
    required SliceDepth depth,
  }) async {
    final sources = <String, String>{};
    final included = <String>{};
    final nodes = <String, FileGraphNode>{};
    final edges = <String>{};
    final warnings = <String>[];
    final queue = Queue<String>.from(entries);
    final typeIndex = await _buildTypeIndex(projectRoot);
    final barrels = <String, List<String>>{};

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      if (included.contains(path) || edges.contains(path)) continue;

      final rel = p.relative(path, from: projectRoot);
      final layer = classifyLayer(rel);
      if (!layerAllowedAtDepth(layer, depth)) {
        edges.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) {
        warnings.add('Imported file "$rel" does not exist; skipped.');
        continue;
      }
      final source = await file.readAsString();
      sources[path] = source;

      final importInfos = _extractImportInfos(source);
      final resolvedImports = <String>[];

      // DI cascade rule: a DI registration file belongs to the wiring of the
      // implementations it imports. When its imports cross a layer the depth
      // excludes, the registration is cut off with them — the sandbox gets a
      // generated mock registration instead (research R-008, A1's mock DI).
      if (layer == 'di' && depth != SliceDepth.full) {
        final importLayers = <String>{};
        for (final info in importInfos) {
          final target = await _resolveImport(
            info: info,
            importingFile: path,
            resolver: resolver,
            sources: sources,
          );
          if (target == null) continue;
          importLayers.add(classifyLayer(p.relative(target, from: projectRoot)));
        }
        final crossesBoundary = importLayers.any(
          (l) => !layerAllowedAtDepth(l, depth),
        );
        if (crossesBoundary) {
          edges.add(path);
          continue;
        }
      }

      included.add(path);

      for (final info in importInfos) {
        final targets = await _expandImport(
          info: info,
          importingFile: path,
          importerSource: source,
          projectRoot: projectRoot,
          resolver: resolver,
          barrels: barrels,
        );
        resolvedImports.addAll(targets);
        for (final target in targets) {
          if (included.contains(target) || edges.contains(target)) continue;
          final targetRel = p.relative(target, from: projectRoot);
          if (!layerAllowedAtDepth(classifyLayer(targetRel), depth)) {
            edges.add(target);
            continue;
          }
          queue.add(target);
        }
      }

      // Service-locator path: getIt<T>() types (FR-001).
      final diTypes = _serviceLocatorAnalyzer.extractServiceLocatorTypes(
        source,
      );
      for (final typeName in diTypes) {
        final declaringFile = typeIndex[typeName];
        if (declaringFile == null) continue;
        resolvedImports.add(declaringFile);
        if (!included.contains(declaringFile) &&
            !edges.contains(declaringFile)) {
          final declaringRel = p.relative(declaringFile, from: projectRoot);
          if (!layerAllowedAtDepth(
            classifyLayer(declaringRel),
            depth,
          )) {
            edges.add(declaringFile);
          } else {
            queue.add(declaringFile);
          }
        }

        // The DI registration file for the resolved type (U12).
        final diFile = _serviceLocatorAnalyzer.diRegistrationFileFor(
          typeName,
          projectRoot,
        );
        if (diFile != null &&
            !included.contains(diFile) &&
            !edges.contains(diFile)) {
          final diRel = p.relative(diFile, from: projectRoot);
          if (layerAllowedAtDepth(classifyLayer(diRel), depth)) {
            queue.add(diFile);
          } else {
            edges.add(diFile);
          }
        }
      }

      // Companions ride along with every included file (FR-006).
      final companionResult = _companionDetector.detectCompanions(path, source);
      warnings.addAll(companionResult.warnings);

      nodes[path] = FileGraphNode(
        filePath: path,
        imports: resolvedImports.toSet().toList(),
        diTypes: diTypes,
        companions: companionResult.companions,
      );
      for (final companion in companionResult.companions) {
        if (!included.contains(companion)) {
          final companionSource = await File(companion).readAsString();
          sources[companion] = companionSource;
          included.add(companion);
          nodes[companion] = FileGraphNode(
            filePath: companion,
            imports: const [],
            diTypes: const [],
            companions: const [],
          );
        }
      }
    }

    final boundaries = await _computeBoundaries(
      edges: edges,
      included: included,
      sources: sources,
      projectRoot: projectRoot,
      typeIndex: typeIndex,
    );

    return WalkResult(
      graph: FileGraph(
        nodes: nodes,
        packageName: resolver.packageName,
        projectRoot: projectRoot,
        boundaries: boundaries,
        edgeFiles: edges,
      ),
      boundaries: boundaries,
      warnings: warnings,
      barrels: barrels,
    );
  }

  List<_ImportInfo> _extractImportInfos(String source) {
    final result = _parser.parseSource(source);
    final unit = result.unit;
    if (unit == null) return const [];
    return unit.directives
        .whereType<ImportDirective>()
        .map((directive) {
          final uri = directive.uri.stringValue;
          if (uri == null) return null;
          final shown = <String>[];
          for (final combinator in directive.combinators) {
            if (combinator is ShowCombinator) {
              shown.addAll(
                combinator.shownNames.map((n) => n.token.lexeme),
              );
            }
          }
          return _ImportInfo(uri, shown);
        })
        .whereType<_ImportInfo>()
        .toList();
  }

  Future<String?> _resolveImport({
    required _ImportInfo info,
    required String importingFile,
    required PackageResolver resolver,
    required Map<String, String> sources,
  }) async {
    if (resolver.classify(info.uri) == ImportKind.relative) {
      return resolver.resolveRelative(info.uri, importingFile);
    }
    return resolver.resolve(info.uri);
  }

  /// Resolves one import to the concrete local file paths it contributes:
  /// barrels expand (FR-005) — recording the kept targets so the cut can
  /// emit a filtered barrel — everything else is the file itself.
  Future<List<String>> _expandImport({
    required _ImportInfo info,
    required String importingFile,
    required String importerSource,
    required String projectRoot,
    required PackageResolver resolver,
    Map<String, List<String>>? barrels,
  }) async {
    final target = await _resolveImport(
      info: info,
      importingFile: importingFile,
      resolver: resolver,
      sources: const {},
    );
    if (target == null) return const [];
    if (!File(target).existsSync()) return const [];
    final content = await File(target).readAsString();
    if (!_barrelResolver.isBarrel(content)) {
      return [target];
    }
    final kept = await _barrelResolver.expandImport(
      importedPath: target,
      importerSource: importerSource,
      shownSymbols: info.shownSymbols,
    );
    final existing = barrels?[target] ?? const <String>[];
    barrels?[target] = [
      ...existing,
      ...kept.where((k) => !existing.contains(k)),
    ];
    return kept;
  }

  /// Index of top-level declared type names -> absolute file path.
  Future<Map<String, String>> _buildTypeIndex(String projectRoot) async {
    final index = <String, String>{};
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) return index;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final name in _barrelResolver.declaredTopLevelNames(source)) {
        index.putIfAbsent(name, () => p.canonicalize(entity.path));
      }
    }
    return index;
  }

  /// Boundary computation over the traversal edge (data-model Boundary).
  Future<List<SliceBoundary>> _computeBoundaries({
    required Set<String> edges,
    required Set<String> included,
    required Map<String, String> sources,
    required String projectRoot,
    required Map<String, String> typeIndex,
  }) async {
    if (edges.isEmpty) return const [];
    final byTypeName = <String, SliceBoundary>{};

    Future<void> addBoundary(SliceBoundary boundary) async {
      final existing = byTypeName[boundary.typeName];
      if (existing == null) {
        byTypeName[boundary.typeName] = boundary;
        return;
      }
      // Merge: keep the non-null DI registration file and the more
      // conservative mock strategy.
      byTypeName[boundary.typeName] = SliceBoundary(
        typeName: existing.typeName,
        interfaceFile: existing.interfaceFile,
        diRegistrationFile:
            existing.diRegistrationFile ?? boundary.diRegistrationFile,
        mockStrategy: existing.mockStrategy == 'auto' && existing.diRegistrationFile == null
            ? boundary.mockStrategy
            : existing.mockStrategy,
      );
    }

    final includedSource = sources.entries
        .where((entry) => included.contains(entry.key))
        .map((entry) => entry.value)
        .join('\n');

    for (final edgePath in edges) {
      final source = await File(edgePath).exists()
          ? await File(edgePath).readAsString()
          : sources[edgePath] ?? '';
      if (source.isEmpty) continue;
      final rel = p.relative(edgePath, from: projectRoot);

      // Rule A: types declared by the edge file that included files use.
      final declared = _barrelResolver.declaredTopLevelNames(source);
      for (final typeName in declared) {
        if (RegExp('\\b${RegExp.escape(typeName)}\\b').hasMatch(includedSource)) {
          final diFile = _serviceLocatorAnalyzer.diRegistrationFileFor(
            typeName,
            projectRoot,
          );
          await addBoundary(
            SliceBoundary(
              typeName: typeName,
              interfaceFile: rel,
              diRegistrationFile: diFile,
              mockStrategy: await _mockStrategyFor(typeName, projectRoot),
            ),
          );
        }
      }

      // Rule B: the edge file implements/extends an included interface —
      // the included type is the boundary (e.g. a data implementation cut
      // off at feature depth).
      final unit = _parser.parseSource(source).unit;
      if (unit != null) {
        for (final decl in unit.declarations) {
          if (decl is! ClassDeclaration) continue;
          final superclassNames = <String>[
            if (decl.extendsClause != null)
              decl.extendsClause!.superclass.toString(),
            ...?decl.implementsClause?.interfaces.map((i) => i.toString()),
          ];
          for (final superName in superclassNames) {
            final declaringFile = typeIndex[superName];
            if (declaringFile == null || !included.contains(declaringFile)) {
              continue;
            }
            final diFile = _serviceLocatorAnalyzer.diRegistrationFileFor(
              superName,
              projectRoot,
            );
            await addBoundary(
              SliceBoundary(
                typeName: superName,
                interfaceFile: p.relative(declaringFile, from: projectRoot),
                diRegistrationFile: diFile,
                mockStrategy: await _mockStrategyFor(superName, projectRoot),
              ),
            );
          }
        }
      }

      // Rule C: the edge file REGISTERS an included type (the DI wiring of a
      // cut-off implementation, e.g. the repository registration at feature
      // depth).
      final registeredTypes = _serviceLocatorAnalyzer
          .extractServiceLocatorTypes(source);
      registeredTypes.addAll(_extractRegistrationTypes(source));
      for (final typeName in registeredTypes) {
        final declaringFile = typeIndex[typeName];
        if (declaringFile == null || !included.contains(declaringFile)) {
          continue;
        }
        await addBoundary(
          SliceBoundary(
            typeName: typeName,
            interfaceFile: p.relative(declaringFile, from: projectRoot),
            diRegistrationFile: rel,
            mockStrategy: await _mockStrategyFor(typeName, projectRoot),
          ),
        );
      }
    }

    final result = byTypeName.values.toList()
      ..sort((a, b) => a.typeName.compareTo(b.typeName));
    return result;
  }

  /// `registerLazySingleton<T>(...)`, `registerSingleton<T>(...)`,
  /// `registerFactory<T>(...)` type arguments in a DI file's source.
  List<String> _extractRegistrationTypes(String source) {
    final result = _parser.parseSource(source);
    final unit = result.unit;
    if (unit == null) return const [];
    final visitor = _RegistrationTypeVisitor();
    unit.accept(visitor);
    return visitor.types;
  }

  Future<String> _mockStrategyFor(String typeName, String projectRoot) async {
    // U30: reuse the project's own mock when one exists.
    final pattern = RegExp(
      'class\\s+Mock${RegExp.escape(typeName)}\\b',
    );
    final candidateDirs = [
      Directory(p.join(projectRoot, 'lib')),
      Directory(p.join(projectRoot, 'test', 'mocks')),
      Directory(p.join(projectRoot, 'mocks')),
    ];
    for (final dir in candidateDirs) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (pattern.hasMatch(entity.readAsStringSync())) {
          return 'existing';
        }
      }
    }
    return 'auto';
  }
}

/// Visitor collecting type arguments of `register*` calls in DI files
/// (`registerLazySingleton<T>`, `registerSingleton<T>`, `registerFactory<T>`).
class _RegistrationTypeVisitor extends RecursiveAstVisitor<void> {
  final List<String> types = <String>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.token.lexeme;
    final isRegistration = method.startsWith('register');
    if (isRegistration && node.typeArguments != null) {
      final args = node.typeArguments!.arguments;
      if (args.length == 1) {
        final name = args.first.toString();
        if (!types.contains(name)) {
          types.add(name);
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}
