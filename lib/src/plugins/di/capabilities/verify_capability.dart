import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../core/plugin_system/capability.dart';
import '../../../utils/string_utils.dart';
import '../di_plugin.dart';

/// SPEC 0974 (issue #974, order 2): the `zfa di verify` gate.
///
/// Resolves every `getIt<T>()` / `getIt.registerXxx<T>()` call in the
/// generated registrations under `<outputDir>/di/` against classes on
/// disk. A dangling binding — a registration whose type resolves to no
/// class in the project (the exact failure #284/#410 fixed by hand) —
/// fails the verdict with a `--> fix:` hint naming the class and its
/// expected conventional file, so automation stops before `dart analyze`
/// has to explain ~100 undefined-name errors.
///
/// Read-only by design: [plan] and [execute] run the same check and never
/// touch the tree; the CLI turns `success: false` into exit 1.
class DiVerifyCapability implements ZuraffaCapability {
  final DiPlugin plugin;

  /// Project root the class index and `.dart_tool/package_config.json`
  /// resolve from. Defaults to the current working directory (the CLI
  /// contract: `zfa` runs from the project it operates on). Injectable so
  /// tests can point at a temp fixture.
  final String? projectRoot;

  /// DI-framework types that legally appear in `getIt<T>` positions but
  /// live in package imports rather than the project tree.
  static const Set<String> _frameworkTypes = {'GetIt'};

  /// Dart core types that can legally appear in `getIt<T>` positions
  /// without any on-disk declaration.
  static const Set<String> _coreTypes = {
    'dynamic',
    'void',
    'Null',
    'Never',
    'int',
    'double',
    'num',
    'String',
    'bool',
    'Object',
    'List',
    'Map',
    'Set',
    'Iterable',
    'Future',
    'Stream',
    'Function',
    'Record',
    'Duration',
    'DateTime',
    'Uri',
    'BigInt',
  };

  DiVerifyCapability(this.plugin, {this.projectRoot});

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify DI registrations resolve against classes on disk '
      '(dangling bindings fail with a fix hint)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'findings': {
        'type': 'array',
        'items': {'type': 'object'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final outcome = await _verify();

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: const [],
      isValid: outcome.ok,
      message: outcome.summary,
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final outcome = await _verify();

    if (outcome.ok) {
      return ExecutionResult(
        success: true,
        files: outcome.scannedFiles,
        message: outcome.summary,
        data: outcome.toData(),
      );
    }
    return ExecutionResult(
      success: false,
      files: outcome.scannedFiles,
      message: outcome.summary,
      data: outcome.toData(),
    );
  }

  Future<_VerifyOutcome> _verify() async {
    final root = path.canonicalize(projectRoot ?? Directory.current.path);
    final diDir = _resolveDir(root, path.join(plugin.outputDir, 'di'));

    if (!diDir.existsSync()) {
      return _VerifyOutcome(
        ok: true,
        summary:
            'di verify: no DI registrations under '
            '${_relative(root, diDir.path)} — nothing to verify',
        scannedFiles: const [],
        findings: const [],
        bindingsChecked: 0,
      );
    }

    final diFiles =
        diDir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // Classes on disk: every declaration under the project's lib/ tree.
    final declared = <String>{};
    final libDir = Directory(path.join(root, 'lib'));
    if (libDir.existsSync()) {
      for (final entity in libDir.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        declared.addAll(_declaredTypeNames(entity.readAsStringSync()));
      }
    }

    // Package imports resolve through .dart_tool/package_config.json so
    // registrations of externally-provided types verify fairly.
    final packageResolver = _PackageResolver(root);

    final findings = <_Finding>[];
    var bindingsChecked = 0;

    for (final file in diFiles) {
      final relative = _relative(root, file.path);
      final content = file.readAsStringSync();

      // 1. Every relative import of a DI file must point at a file that
      //    exists (#410's uri_does_not_exist mode).
      for (final importUri in _relativeImports(content)) {
        final target = path.normalize(
          path.join(path.dirname(file.path), importUri),
        );
        if (!File(target).existsSync()) {
          findings.add(
            _Finding(
              file: relative,
              kind: 'dangling import',
              type: null,
              member: importUri,
              detail: "import '$importUri' points at a missing file",
              fix:
                  '--> fix: create ${_relative(root, target)} or fix the '
                  'import in $relative',
            ),
          );
        }
      }

      // 2. Every getIt<T>() / getIt.registerXxx<T>() type must resolve to
      //    a class on disk (#284's never-generated-class mode).
      final referenced = <String>{};
      for (final match in _registrationTypePattern.allMatches(content)) {
        referenced.add(match.group(1)!);
      }
      for (final match in _lookupTypePattern.allMatches(content)) {
        referenced.add(match.group(1)!);
      }

      for (final type in referenced) {
        bindingsChecked++;
        if (declared.contains(type) ||
            _frameworkTypes.contains(type) ||
            _coreTypes.contains(type)) {
          continue;
        }
        if (packageResolver.provides(content, type)) {
          continue;
        }
        final expected = _expectedFileFor(type);
        findings.add(
          _Finding(
            file: relative,
            kind: 'dangling binding',
            type: type,
            member: type,
            detail:
                'getIt<$type> in $relative binds a class that does not '
                'exist on disk',
            fix:
                '--> fix: define $type in $expected and import it, or '
                'remove the registration',
          ),
        );
      }
    }

    final summary = findings.isEmpty
        ? 'di verify: ${diFiles.length} registration file(s), '
              '$bindingsChecked binding(s) verified — OK'
        : 'di verify: ${findings.length} finding(s) across '
              '${diFiles.length} registration file(s)\n'
              '${findings.map((f) => '${f.file}: ${f.detail}\n  ${f.fix}').join('\n')}';

    return _VerifyOutcome(
      ok: findings.isEmpty,
      summary: summary,
      scannedFiles: diFiles.map((f) => _relative(root, f.path)).toList(),
      findings: findings,
      bindingsChecked: bindingsChecked,
    );
  }

  Directory _resolveDir(String root, String dir) => Directory(
    path.canonicalize(path.isAbsolute(dir) ? dir : path.join(root, dir)),
  );

  String _relative(String root, String target) {
    final relative = path.relative(target, from: root);
    return relative.startsWith('..')
        ? path.canonicalize(target)
        : relative.replaceAll(path.separator, '/');
  }

  /// Extracts declared top-level type names (class / mixin / enum /
  /// typedef) from Dart source — the textual contract the gate needs; a
  /// full analyzer resolution is unnecessary for "does this class exist
  /// anywhere in the project".
  static Iterable<String> _declaredTypeNames(String content) sync* {
    for (final match in _declarationPattern.allMatches(content)) {
      yield match.group(1)!;
    }
  }

  static final RegExp _declarationPattern = RegExp(
    r'\b(?:class|mixin|enum|typedef)\s+([A-Z]\w*)',
  );

  static final RegExp _registrationTypePattern = RegExp(
    r'\bgetIt\s*\.\s*register\w*\s*<\s*([A-Za-z_]\w*)\s*>',
  );

  static final RegExp _lookupTypePattern = RegExp(
    r'\bgetIt\s*<\s*([A-Za-z_]\w*)\s*>\s*\(',
  );

  static Iterable<String> _relativeImports(String content) sync* {
    for (final match in _importPattern.allMatches(content)) {
      final uri = match.group(1)!;
      if (uri.startsWith('.') || uri.startsWith('/')) {
        yield uri;
      }
    }
  }

  static final RegExp _importPattern = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Conventional expected location for a class name, used by the fix
  /// hint. Mirrors the naming the generators emit: class `GetProductUseCase`
  /// lives in `get_product_usecase.dart` (suffix stripped, base snaked,
  /// suffix re-appended), `DataProductRepository` in
  /// `product_repository.dart`. When the domain segment is dynamic the
  /// hint shows a `<domain>` placeholder rather than guessing.
  static String _expectedFileFor(String typeName) {
    String baseSnake(String classSuffix, String fileSuffix) =>
        '${StringUtils.camelToSnake(typeName.substring(0, typeName.length - classSuffix.length))}$fileSuffix';
    if (typeName.endsWith('UseCase')) {
      return 'lib/src/domain/usecases/<domain>/${baseSnake('UseCase', '_usecase')}.dart';
    }
    if (typeName.endsWith('Repository')) {
      return 'lib/src/data/repositories/${baseSnake('Repository', '_repository')}.dart';
    }
    if (typeName.endsWith('Service')) {
      return 'lib/src/domain/services/<domain>/${baseSnake('Service', '_service')}.dart';
    }
    if (typeName.endsWith('DataSource') || typeName.endsWith('Datasource')) {
      // Class names carry the full chain (ProductRemoteDataSource), so the
      // whole name snakes; the entity folder is the first segment.
      final snake = StringUtils.camelToSnake(typeName);
      final entity = snake.split('_').first;
      return 'lib/src/data/datasources/$entity/$snake.dart';
    }
    if (typeName.endsWith('Provider')) {
      final snake = StringUtils.camelToSnake(typeName);
      final domain = snake.split('_').first;
      return 'lib/src/data/providers/$domain/$snake.dart';
    }
    return 'lib/src/${StringUtils.camelToSnake(typeName)}.dart';
  }
}

class _Finding {
  final String file;
  final String kind;
  final String? type;

  /// The machine-verdict member the finding is about (SPEC 1106): the
  /// unresolvable type for a dangling binding, the dead import URI for a
  /// dangling import. `null` only for legacy constructors in tests.
  final String? member;
  final String detail;
  final String fix;

  const _Finding({
    required this.file,
    required this.kind,
    required this.type,
    this.member,
    required this.detail,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'file': file,
    'kind': kind,
    if (member != null) 'member': member,
    if (type != null) 'class': type,
    'detail': detail,
    'fix': fix,
  };
}

class _VerifyOutcome {
  final bool ok;
  final String summary;
  final List<String> scannedFiles;
  final List<_Finding> findings;
  final int bindingsChecked;

  const _VerifyOutcome({
    required this.ok,
    required this.summary,
    required this.scannedFiles,
    required this.findings,
    required this.bindingsChecked,
  });

  Map<String, dynamic> toData() => {
    'findings': findings.map((f) => f.toJson()).toList(),
    'files_scanned': scannedFiles.length,
    'bindings_checked': bindingsChecked,
  };
}

/// Resolves `package:` imports of a DI file through the project's
/// `.dart_tool/package_config.json` and reports whether the imported
/// library (plus one level of exports) declares [type]. Falls back to
/// "provides nothing" when the config is absent, which keeps the gate
/// conservative: project classes and the framework allowlist still
/// verify; only externally-declared types need the config.
class _PackageResolver {
  final String root;
  final Map<String, String> _packageRoots;

  _PackageResolver(this.root) : _packageRoots = _readPackageRoots(root);

  bool get _available => _packageRoots.isNotEmpty;

  static Map<String, String> _readPackageRoots(String root) {
    final config = File(path.join(root, '.dart_tool', 'package_config.json'));
    if (!config.existsSync()) return const {};
    try {
      final json =
          jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
      final packages = json['packages'];
      if (packages is! List) return const {};
      final roots = <String, String>{};
      for (final entry in packages) {
        if (entry is! Map) continue;
        final name = entry['name'];
        final rootUri = entry['rootUri'];
        final packageUri = entry['packageUri'] ?? 'lib/';
        if (name is! String || rootUri is! String) continue;
        final resolved = rootUri.startsWith('file:')
            ? Uri.parse(rootUri).toFilePath()
            : path.canonicalize(path.join(root, rootUri));
        roots[name] = path.join(resolved, packageUri);
      }
      return roots;
    } catch (_) {
      return const {};
    }
  }

  /// Whether any `package:` import of [content] resolves to a library
  /// that declares [type]. Unresolvable packages are treated as NOT
  /// providing the type — a type that exists nowhere provable is exactly
  /// what the gate exists to flag.
  bool provides(String content, String type) {
    if (!_available) return false;
    for (final match in _packageImportPattern.allMatches(content)) {
      final uri = match.group(1)!;
      if (!uri.startsWith('package:')) continue;
      final parts = uri.substring('package:'.length).split('/');
      if (parts.length < 2) continue;
      final packageRoot = _packageRoots[parts.first];
      if (packageRoot == null) continue;
      final library = path.canonicalize(
        path.joinAll([packageRoot, ...parts.skip(1)]),
      );
      if (_libraryDeclares(library, type, const {}, 0)) return true;
    }
    return false;
  }

  bool _libraryDeclares(
    String filePath,
    String type,
    Set<String> visited,
    int depth,
  ) {
    if (depth > 2) return false;
    if (!visited.add(filePath)) return false;
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    if (DiVerifyCapability._declaredTypeNames(content).contains(type)) {
      return true;
    }
    for (final match in _exportPattern.allMatches(content)) {
      final uri = match.group(1)!;
      if (!uri.startsWith('.') && !uri.startsWith('/')) continue;
      final target = path.normalize(path.join(path.dirname(filePath), uri));
      if (_libraryDeclares(target, type, visited, depth + 1)) return true;
    }
    return false;
  }

  static final RegExp _packageImportPattern = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  static final RegExp _exportPattern = RegExp(
    r'''^\s*export\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
}
