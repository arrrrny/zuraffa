/// FeatureSliceComposer (spec 1114): composes the feature's slice tree
/// at `.zfa/slices/<feature-id>/` from a typed [FeatureContract].
///
/// The slice is the minimal base an agent receives for ONE feature:
///
/// ```
/// .zfa/slices/<id>/
///   engine/        entities, usecases, services, repositories,
///                  datasources, mocks, DI  — the contract's entities
///   skin/          views, widgets, states, routes — the contract's
///                  routes
///   contract/      contract.json (the contract JSON)
///   receipts/      the feature's specs/<id>/** receipts
///   specs/<id>/    the receipts MOUNT — `zfa tdd run <id>` resolves
///                  its feature dir here, so the cycles run inside the
///                  slice (the #1113 journal glues back through merge)
///   slice.yaml     the feature-centric manifest (slice.manifest.v2)
/// ```
///
/// Discovery rules (declared facts, deterministic; the same contract +
/// project ⇒ byte-identical engine/skin/contract content, FR-007):
///   engine/entities/<E>/    ← lib/src/domain/entities/<snake(E)>/**
///   engine/usecases/        ← lib/src/domain/usecases/** files whose
///                             name mentions the entity
///   engine/repositories/    ← lib/src/domain/repositories/** entity
///                             files + the contract boundary interface
///   engine/services/        ← lib/src/domain/services/** entity files
///   engine/datasources/     ← lib/src/data/datasources/** entity files
///   engine/mocks/           ← lib/src/data/mocks/** entity files +
///                             the generated boundary mock
///   engine/di/              ← lib/src/di/** files referencing the
///                             entity/boundary + the generated harness
///   skin/views/             ← lib/src/presentation/views/** files
///                             whose name carries a route's segments
///   skin/widgets/           ← lib/src/presentation/widgets/** route
///                             files
///   skin/states/            ← lib/src/presentation/states/** route
///                             files
///   skin/routes/router.dart ← generated: exposes EXACTLY the routes
///
/// Everything else in the project stays OUT — that is the point of the
/// slice plugin (#1114: "an agent gets only the required base for that
/// feature, not the whole app").
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../../../domain/entities/feature_contract/feature_contract_decorators.dart';
import '../models/feature_slice_manifest.dart';
import '_pascal_case.dart';

/// The result of composing a slice.
class FeatureSliceComposition {
  /// Absolute path to `.zfa/slices/<feature-id>`.
  final String sliceRoot;

  /// The feature-centric manifest.
  final FeatureSliceManifest manifest;

  /// Files written, relative to the slice root.
  final List<String> writtenFiles;

  const FeatureSliceComposition({
    required this.sliceRoot,
    required this.manifest,
    required this.writtenFiles,
  });
}

/// Composes feature slices from typed contracts.
class FeatureSliceComposer {
  /// Creates the composer (stateless; deterministic).
  const FeatureSliceComposer();

  /// The default slice storage root: `<projectRoot>/.zfa/slices`.
  static String slicesRootOf(String projectRoot) =>
      p.join(projectRoot, '.zfa', 'slices');

  /// The slice root for [featureId]:
  /// `<projectRoot>/.zfa/slices/<featureId>`.
  static String sliceRootOf(String projectRoot, String featureId) =>
      p.join(slicesRootOf(projectRoot), featureId);

  /// Composes the slice for [contract] under [projectRoot].
  ///
  /// Re-compose is idempotent: an existing slice dir is replaced (the
  /// composition is a pure function of the declared facts).
  FeatureSliceComposition compose({
    required String projectRoot,
    required FeatureContract contract,
    required String origin,
    String? slicesDir,
    DateTime? createdAt,
    bool force = false,
  }) {
    final root = slicesDir ?? slicesRootOf(projectRoot);
    final sliceRoot = p.join(root, contract.id);
    final written = <String>[];

    // Idempotent re-compose: wipe the previous composition.
    final existing = Directory(sliceRoot);
    if (existing.existsSync()) {
      final manifestFile = File(p.join(sliceRoot, 'slice.yaml'));
      if (!force && manifestFile.existsSync()) {
        final FeatureSliceManifest manifest;
        try {
          manifest = FeatureSliceManifest.fromYaml(
            manifestFile.readAsStringSync(),
          );
        } on FeatureSliceManifestYamlError {
          throw StateError(
            'Refusing to re-compose feature "${contract.id}": its existing '
            'slice manifest is corrupt, so worktree state cannot be verified. '
            'Use force only when discarding that slice is intentional.',
          );
        }
        if (manifest.worktreePath != null) {
          throw StateError(
            'Refusing to re-compose feature "${contract.id}": its slice '
            'is an active worktree at ${manifest.worktreePath}. Use force '
            'only when discarding that worktree is intentional.',
          );
        }
      }
      existing.deleteSync(recursive: true);
    }
    Directory(sliceRoot).createSync(recursive: true);

    final engineFiles = <FeatureSliceFile>[];
    final engineEntities = <String, List<String>>{
      for (final entity in contract.entities ?? const <String>[])
        entity: <String>[],
    };
    final skinFiles = <FeatureSliceFile>[];
    final skinRoutes = <FeatureSkinRoute>[];
    final generatedFiles = <String>[];
    final receiptsFiles = <String>[];

    // — engine: the contract's entities —
    for (final entity in contract.entities ?? const <String>[]) {
      engineFiles.addAll(
        _copyEntityEngine(
          projectRoot: projectRoot,
          sliceRoot: sliceRoot,
          entity: entity,
          engineEntities: engineEntities,
          written: written,
        ),
      );
    }

    // The contract's boundary interface ALWAYS travels with the engine
    // (it is the feature's declared seam) — entity-attributed when its
    // name mentions an entity, feature-owned otherwise.
    final boundary = contract.boundary;
    if (boundary != null) {
      final source = File(p.join(projectRoot, boundary.interfaceFile));
      if (source.existsSync()) {
        final rel = p
            .join('engine', 'repositories', p.basename(source.path))
            .replaceAll('\\', '/');
        final already = engineFiles.any((f) => f.relativePath == rel);
        if (!already) {
          _copyFile(source, p.join(sliceRoot, rel));
          written.add(rel);
          engineFiles.add(
            FeatureSliceFile(
              relativePath: rel,
              layer: 'domain',
              entity: _entityMentionedBy(
                p.basenameWithoutExtension(source.path),
                contract,
              ),
              hashAtCut: _hashOf(source),
            ),
          );
        }
      }
    }

    // — engine harness: the boundary mock + DI wiring (generated) —
    if (boundary != null) {
      final mockRel = 'engine/mocks/${_snake(boundary.typeName)}.dart';
      _writeGenerated(
        p.join(sliceRoot, mockRel),
        _boundaryMockSource(boundary.typeName),
      );
      generatedFiles.add(mockRel);
      written.add(mockRel);

      final diRel = 'engine/di/slice_di.dart';
      _writeGenerated(
        p.join(sliceRoot, diRel),
        _sliceDiSource(boundary.typeName),
      );
      generatedFiles.add(diRel);
      written.add(diRel);
    }

    // — skin: the contract's routes (most specific route first, so a
    // multi-segment route claims its views before a prefix route can) —
    final routes = (contract.routes ?? const <String>{}).toList()..sort();
    final routesBySpecificity = routes.toList()
      ..sort((a, b) => _routeSegments(b).length - _routeSegments(a).length);
    for (final route in routesBySpecificity) {
      skinRoutes.add(
        FeatureSkinRoute(path: route, view: viewNameForRoute(route)),
      );
      _copyRouteSkin(
        projectRoot: projectRoot,
        sliceRoot: sliceRoot,
        route: route,
        skinFiles: skinFiles,
        written: written,
      );
    }
    // Manifest records routes path-sorted (deterministic).
    skinRoutes.sort((a, b) => a.path.compareTo(b.path));
    if (routes.isNotEmpty) {
      const routerRel = 'skin/routes/router.dart';
      _writeGenerated(p.join(sliceRoot, routerRel), _routerSource(skinRoutes));
      generatedFiles.add(routerRel);
      written.add(routerRel);
    }

    // — contract: the contract JSON —
    const contractRel = 'contract/contract.json';
    final contractJson = contractJsonOf(contract, origin);
    _writeGenerated(p.join(sliceRoot, contractRel), contractJson);
    written.add(contractRel);
    final contractDigest = sha256.convert(utf8.encode(contractJson)).toString();

    // — receipts: the feature's spec tree (+ the tdd mount) —
    final specDir = Directory(p.join(projectRoot, 'specs', contract.id));
    if (specDir.existsSync()) {
      for (final entity in specDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final specRel = p
            .relative(entity.path, from: specDir.path)
            .replaceAll('\\', '/');
        if (specRel == 'compose.plan.json') continue;
        final receiptsRel = 'receipts/$specRel';
        _copyFile(entity, p.join(sliceRoot, receiptsRel));
        receiptsFiles.add(receiptsRel);
        written.add(receiptsRel);

        // The tdd mount: the SAME receipts under specs/<id>/ so the
        // tdd driver resolves its feature dir inside the slice.
        final mountRel = 'specs/${contract.id}/$specRel';
        _copyFile(entity, p.join(sliceRoot, mountRel));
        written.add(mountRel);
      }
    }

    // — manifest: the feature-centric record —
    final (parentBranch, parentHead) = _gitFacts(projectRoot);
    final manifest = FeatureSliceManifest(
      createdAt: createdAt ?? DateTime.now(),
      feature: contract,
      origin: origin,
      projectRoot: projectRoot,
      parentBranch: parentBranch,
      parentHead: parentHead,
      sliceRoot: p.relative(sliceRoot, from: projectRoot).replaceAll('\\', '/'),
      engineFiles: engineFiles,
      engineEntities: engineEntities,
      skinFiles: skinFiles,
      skinRoutes: skinRoutes,
      contractFile: contractRel,
      contractDigest: contractDigest,
      receiptsFiles: receiptsFiles,
      generatedFiles: generatedFiles,
    );
    const manifestRel = 'slice.yaml';
    _writeGenerated(p.join(sliceRoot, manifestRel), manifest.toYaml());
    written.add(manifestRel);

    return FeatureSliceComposition(
      sliceRoot: sliceRoot,
      manifest: manifest,
      writtenFiles: written,
    );
  }

  // ------------------------------------------------------------------
  // engine walk
  // ------------------------------------------------------------------

  List<FeatureSliceFile> _copyEntityEngine({
    required String projectRoot,
    required String sliceRoot,
    required String entity,
    required Map<String, List<String>> engineEntities,
    required List<String> written,
  }) {
    final files = <FeatureSliceFile>[];
    final variants = nameVariants(entity);

    // entities/<entity>/** — the whole owned subtree.
    for (final variant in variants) {
      final dir = Directory(
        p.join(projectRoot, 'lib', 'src', 'domain', 'entities', variant),
      );
      if (!dir.existsSync()) continue;
      for (final entityFile in dir.listSync(recursive: true)) {
        if (entityFile is! File) continue;
        if (p.extension(entityFile.path) != '.dart') continue;
        final relInside = p
            .relative(entityFile.path, from: dir.path)
            .replaceAll('\\', '/');
        final rel = 'engine/entities/$entity/$relInside';
        _copyFile(entityFile, p.join(sliceRoot, rel));
        written.add(rel);
        files.add(
          FeatureSliceFile(
            relativePath: rel,
            layer: 'domain',
            entity: entity,
            hashAtCut: _hashOf(entityFile),
          ),
        );
      }
      break; // first matching variant wins — deterministic.
    }

    // Entity-mentioning files across the engine trees.
    void collectNamed(String sourceDirAbs, String engineSection, String layer) {
      final dir = Directory(sourceDirAbs);
      if (!dir.existsSync()) return;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File) continue;
        if (p.extension(file.path) != '.dart') continue;
        final base = p.basenameWithoutExtension(file.path).toLowerCase();
        if (!variants.any(base.contains)) continue;
        final sourceRel = p
            .relative(file.path, from: dir.path)
            .replaceAll('\\', '/');
        final rel = '$engineSection/$sourceRel';
        if (files.any((f) => f.relativePath == rel)) continue;
        _copyFile(file, p.join(sliceRoot, rel));
        written.add(rel);
        files.add(
          FeatureSliceFile(
            relativePath: rel,
            layer: layer,
            entity: entity,
            hashAtCut: _hashOf(file),
          ),
        );
      }
    }

    collectNamed(
      p.join(projectRoot, 'lib', 'src', 'domain', 'usecases'),
      'engine/usecases',
      'domain',
    );
    collectNamed(
      p.join(projectRoot, 'lib', 'src', 'domain', 'repositories'),
      'engine/repositories',
      'domain',
    );
    collectNamed(
      p.join(projectRoot, 'lib', 'src', 'domain', 'services'),
      'engine/services',
      'domain',
    );
    collectNamed(
      p.join(projectRoot, 'lib', 'src', 'data', 'datasources'),
      'engine/datasources',
      'data',
    );
    collectNamed(
      p.join(projectRoot, 'lib', 'src', 'data', 'mocks'),
      'engine/mocks',
      'data',
    );

    // Mock datasources for the entity (the mock_<entity>* convention).
    final datasources = Directory(
      p.join(projectRoot, 'lib', 'src', 'data', 'datasources'),
    );
    if (datasources.existsSync()) {
      for (final file in datasources.listSync()) {
        if (file is! File) continue;
        if (p.extension(file.path) != '.dart') continue;
        final base = p.basenameWithoutExtension(file.path).toLowerCase();
        if (!base.startsWith('mock_')) continue;
        if (!variants.any(base.contains)) continue;
        final rel = 'engine/mocks/${p.basename(file.path)}';
        if (files.any((f) => f.relativePath == rel)) continue;
        _copyFile(file, p.join(sliceRoot, rel));
        written.add(rel);
        files.add(
          FeatureSliceFile(
            relativePath: rel,
            layer: 'data',
            entity: entity,
            hashAtCut: _hashOf(file),
          ),
        );
      }
    }

    // DI wiring that references the entity or the boundary type.
    for (final diDirPath in [
      p.join(projectRoot, 'lib', 'src', 'di'),
      p.join(projectRoot, 'lib', 'src', 'core', 'di'),
    ]) {
      final diDir = Directory(diDirPath);
      if (!diDir.existsSync()) continue;
      for (final file in diDir.listSync(recursive: true)) {
        if (file is! File) continue;
        if (p.extension(file.path) != '.dart') continue;
        final content = file.readAsStringSync();
        final referencesEntity =
            variants.any(content.contains) || content.contains(entity);
        if (!referencesEntity) continue;
        final rel = 'engine/di/${p.basename(file.path)}';
        if (files.any((f) => f.relativePath == rel)) continue;
        _copyFile(file, p.join(sliceRoot, rel));
        written.add(rel);
        files.add(
          FeatureSliceFile(
            relativePath: rel,
            layer: 'data',
            entity: entity,
            hashAtCut: _hashOf(file),
          ),
        );
      }
    }

    engineEntities[entity] = [for (final file in files) file.relativePath];
    return files;
  }

  // ------------------------------------------------------------------
  // skin walk
  // ------------------------------------------------------------------

  void _copyRouteSkin({
    required String projectRoot,
    required String sliceRoot,
    required String route,
    required List<FeatureSliceFile> skinFiles,
    required List<String> written,
  }) {
    final segments = _routeSegments(route);

    void collectPresentation(
      String sourceDirAbs,
      String skinSection, {
      bool views = false,
    }) {
      final dir = Directory(sourceDirAbs);
      if (!dir.existsSync()) return;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File) continue;
        if (p.extension(file.path) != '.dart') continue;
        final base = p.basenameWithoutExtension(file.path).toLowerCase();
        final tokens = base
            .split(RegExp(r'[_\-.]'))
            .where((t) => t.isNotEmpty)
            .toSet();
        final sourceRel = p
            .relative(file.path, from: dir.path)
            .replaceAll('\\', '/');
        final rel = '$skinSection/$sourceRel';
        if (skinFiles.any((f) => f.relativePath == rel)) continue;
        if (views) {
          // A view serves the route whose segments its name carries
          // (multi-segment routes claim their specific views first —
          // the caller iterates most-specific-first).
          if (!segments.every(tokens.contains)) continue;
        } else {
          if (segments.toSet().intersection(tokens).isEmpty) continue;
        }
        _copyFile(file, p.join(sliceRoot, rel));
        written.add(rel);
        skinFiles.add(
          FeatureSliceFile(
            relativePath: rel,
            layer: 'presentation',
            route: route,
            hashAtCut: _hashOf(file),
          ),
        );
      }
    }

    collectPresentation(
      p.join(projectRoot, 'lib', 'src', 'presentation', 'views'),
      'skin/views',
      views: true,
    );
    collectPresentation(
      p.join(projectRoot, 'lib', 'src', 'presentation', 'widgets'),
      'skin/widgets',
    );
    final statesDir =
        Directory(
          p.join(projectRoot, 'lib', 'src', 'presentation', 'states'),
        ).existsSync()
        ? p.join(projectRoot, 'lib', 'src', 'presentation', 'states')
        : p.join(projectRoot, 'lib', 'src', 'presentation', 'state');
    collectPresentation(statesDir, 'skin/states');
  }

  // ------------------------------------------------------------------
  // generated sources (pure functions of the contract — FR-007)
  // ------------------------------------------------------------------

  /// The view class name serving [route]: `/login/forgot` →
  /// `LoginForgotView`.
  static String viewNameForRoute(String route) {
    final segments = _routeSegments(route);
    final raw = segments.map((s) => s[0].toUpperCase() + s.substring(1)).join();
    return '${raw}View';
  }

  /// The routes barrel: EXACTLY the contract's routes, nothing else
  /// routable (pure Dart — the skin slice stays Flutter-free until the
  /// agent writes skin).
  static String _routerSource(List<FeatureSkinRoute> routes) {
    final entries = routes.map((r) => "  '${r.path}': '${r.view}',").join('\n');
    return '''
// GENERATED — slice routes barrel (spec 1114).
//
// Exposes EXACTLY the feature contract's routes — nothing else is
// routable from the slice.
library;

/// The route table: contract path → the view class serving it.
const Map<String, String> sliceRoutes = <String, String>{
$entries
};

/// Resolves [path] to its view class name; an undeclared path refuses.
String viewFor(String path) {
  final view = sliceRoutes[path];
  if (view == null) {
    throw StateError(
      'unrouted slice path: \$path — declare it in the feature contract '
      '(spec 1114: the slice exposes only the contract routes)',
    );
  }
  return view;
}
''';
  }

  /// The boundary mock stub: the certified-fake shape (072 rail) for
  /// the contract's declared boundary type.
  static String _boundaryMockSource(String typeName) {
    return '''
// GENERATED — boundary mock for $typeName (spec 1114).
//
// The contract's declared seam. Bind a simulation here; until then
// every member refuses (the certified-fake rail, 072).
library;

/// The mock for the $typeName boundary.
class Fake${pascalCase(typeName)} {
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'boundary fake for $typeName: bind a simulation (spec 1114 slice '
    'composition)',
  );
}
''';
  }

  /// The slice DI harness: binds the boundary mock (pure Dart).
  static String _sliceDiSource(String typeName) {
    return '''
// GENERATED — slice DI harness (spec 1114).
library;

/// The slice locator: registration-order stable, host-free.
class SliceLocator {
  final Map<String, Object Function()> _factories =
      <String, Object Function()>{};
  final Map<String, Object> _singletons = <String, Object>{};

  void bind(String token, Object Function() factory) =>
      _factories[token] = factory;

  Object resolve(String token) {
    if (_singletons.containsKey(token)) return _singletons[token]!;
    final factory = _factories[token];
    if (factory == null) {
      throw StateError('unbound slice token: \$token (spec 1114)');
    }
    final instance = factory();
    _singletons[token] = instance;
    return instance;
  }
}

/// The boundary token this slice binds.
const String kBoundaryToken = '${_snake(typeName)}';

/// The slice's DI: the boundary mock is the only pre-wired binding.
final SliceLocator sliceDi = SliceLocator()
  ..bind(kBoundaryToken, throwUnsupported);

Object throwUnsupported() => throw UnsupportedError(
  'wire the $typeName boundary mock (spec 1114 slice composition)',
);
''';
  }

  /// The contract JSON written to `contract/contract.json`.
  static String contractJsonOf(FeatureContract contract, String origin) {
    final encoder = JsonEncoder.withIndent('  ');
    final routes = (contract.routes ?? const <String>{}).toList()..sort();
    final boundary = contract.boundary;
    return encoder.convert(<String, dynamic>{
      'schema': 'feature.contract.v1',
      'id': contract.id,
      'display_name': contract.displayName,
      'entities': contract.entities ?? const <String>[],
      'routes': routes,
      'xray_layer': contract.xrayLayer?.name,
      'boundary': boundary == null
          ? null
          : <String, dynamic>{
              'type_name': boundary.typeName,
              'interface_file': boundary.interfaceFile,
              'di_registration_file': boundary.diRegistrationFile,
              'mock_strategy': boundary.mockStrategy,
            },
      'origin': origin,
      'decorator': FeatureContractDecorators.ownedLine(contract.id),
    });
  }

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------

  static List<String> _routeSegments(String route) => route
      .split('/')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();

  /// The name variants an entity's files may carry: snake, kebab and
  /// concatenated lower (`UserProfile` → `user_profile`,
  /// `user-profile`, `userprofile`).
  static List<String> nameVariants(String entity) {
    final camelSplit = entity
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .toLowerCase();
    final snake = camelSplit;
    final kebab = camelSplit.replaceAll('_', '-');
    final concatenated = camelSplit.replaceAll('_', '');
    return <String>{
      snake,
      kebab,
      concatenated,
    }.where((v) => v.isNotEmpty).toList();
  }

  static String? _entityMentionedBy(String base, FeatureContract contract) {
    final lower = base.toLowerCase();
    for (final entity in contract.entities ?? const <String>[]) {
      if (lower.contains(entity.toLowerCase())) return entity;
    }
    return null;
  }

  static String _snake(String raw) {
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }

  static String _hashOf(File file) =>
      sha256.convert(file.readAsBytesSync()).toString();

  static void _copyFile(File source, String targetPath) {
    final target = File(targetPath);
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(source.readAsBytesSync());
  }

  static void _writeGenerated(String targetPath, String content) {
    final target = File(targetPath);
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(utf8.encode(content));
  }

  /// Best-effort parent git facts for the manifest record.
  static (String?, String?) _gitFacts(String projectRoot) {
    try {
      final branch = Process.runSync('git', [
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ], workingDirectory: projectRoot);
      final head = Process.runSync('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: projectRoot);
      if (branch.exitCode != 0 || head.exitCode != 0) return (null, null);
      final branchName = branch.stdout.toString().trim();
      return (
        branchName == 'HEAD' ? null : branchName,
        head.stdout.toString().trim(),
      );
    } catch (_) {
      return (null, null);
    }
  }
}
