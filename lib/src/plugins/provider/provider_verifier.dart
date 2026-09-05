/// Spec 979, orders 2 + 4 — the provider verification gates.
///
/// Two independent, AST-based checks over the provider file as it exists
/// on disk:
///
///   * **Stub gate** (order 2): any method whose body constructs an
///     `UnimplementedError` is a stub. Stubs are allowed to EXIST (the
///     generated skeleton is stub-first by design — the TDD flow fills
///     them); they are not allowed to HIDE: every finding names the file,
///     the method, and the fix. `zfa provider verify <Entity>` fails
///     (exit 1) on any surviving stub.
///
///   * **Conformance gate** (order 4): the provider class must declare
///     every method its target Service interface declares (the provider
///     analog of the #921 source-interface guard). A missing method is a
///     generation defect, not stub-first semantics — it always fails.
///
/// Detection is AST-driven (an `UnimplementedError` construction anywhere
/// in a method body), not text-driven, so a real implementation that
/// merely mentions the word in a comment or a string never trips the
/// gate, and a renamed local (`final boom = UnimplementedError(...)`)
/// still does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../../core/ast/ast_helper.dart';
import '../../utils/file_utils.dart';
import '../../utils/method_extractor.dart';

/// One verification finding.
class ProviderVerifyFinding {
  static const kindStub = 'stub';
  static const kindMissingMethod = 'missing_method';
  static const kindMissingProvider = 'missing_provider';
  static const kindMissingService = 'missing_service';

  /// [kindStub] | [kindMissingMethod] | [kindMissingProvider] |
  /// [kindMissingService].
  final String kind;

  /// Path of the affected file (absolute when the project root is known).
  final String file;

  /// The method the finding is about ('' for file-level findings).
  final String method;

  /// One human line describing the finding.
  final String detail;

  /// The actionable `--> fix:` line.
  final String fix;

  const ProviderVerifyFinding({
    required this.kind,
    required this.file,
    required this.method,
    required this.detail,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'file': file,
    'method': method,
    'detail': detail,
    'fix': fix,
  };
}

/// The verdict of one `zfa provider verify <Entity>` run.
class ProviderVerifyReport {
  final bool ok;
  final String entity;

  /// The provider file that was verified (null when none was found).
  final String? providerFile;

  /// The target Service interface name.
  final String interface;

  /// The methods the Service interface declares.
  final List<String> methods;

  /// How many provider methods still carry `UnimplementedError` bodies.
  final int stubCount;

  final List<ProviderVerifyFinding> findings;

  const ProviderVerifyReport({
    required this.ok,
    required this.entity,
    required this.providerFile,
    required this.interface,
    required this.methods,
    required this.stubCount,
    required this.findings,
  });

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'ok': ok,
    'entity': entity,
    'providerFile': providerFile,
    'interface': interface,
    'methods': methods,
    'stubCount': stubCount,
    'findings': findings.map((f) => f.toJson()).toList(),
  };

  Iterable<ProviderVerifyFinding> get stubFindings =>
      findings.where((f) => f.kind == ProviderVerifyFinding.kindStub);

  Iterable<ProviderVerifyFinding> get conformanceFindings =>
      findings.where((f) => f.kind == ProviderVerifyFinding.kindMissingMethod);
}

/// What [ProviderVerifier.scanSource] found on one provider class.
class ProviderClassScan {
  final String className;

  /// Declared member names (methods and getters) of the class.
  final List<String> methods;

  /// Names of members whose bodies construct `UnimplementedError`.
  final List<String> stubs;

  const ProviderClassScan({
    required this.className,
    required this.methods,
    required this.stubs,
  });
}

/// AST-based provider stub/conformance analysis (spec 979).
class ProviderVerifier {
  const ProviderVerifier();

  /// Scans [source] for class [className]: declared members and which of
  /// them are stubs. Returns null when the class is absent.
  ProviderClassScan? scanSource(String source, String className) {
    final helper = const AstHelper();
    final result = helper.parseSource(source, path: '$className.dart');
    final unit = result.unit;
    if (unit == null) return null;
    final classNode = helper.findClass(unit, className);
    if (classNode == null) return null;

    final methods = <String>[];
    final stubs = <String>[];
    for (final method in helper.findMethods(classNode)) {
      final name = method.name.toString();
      methods.add(name);
      // Abstract/interface members carry an EmptyFunctionBody — nothing
      // to inspect; only executable bodies can hide a stub.
      final body = method.body;
      if (body is BlockFunctionBody || body is ExpressionFunctionBody) {
        if (_containsUnimplementedError(body)) stubs.add(name);
      }
    }
    return ProviderClassScan(
      className: className,
      methods: methods,
      stubs: stubs,
    );
  }

  /// Whether [node]'s subtree constructs an `UnimplementedError`.
  bool _containsUnimplementedError(AstNode node) {
    final visitor = _UnimplementedErrorVisitor();
    node.accept(visitor);
    return visitor.found;
  }

  /// Runs both gates for [entity] under [projectRoot].
  ///
  /// Resolution order for the provider file:
  ///   1. the deterministic receipt `.zfa/receipts/provider-<Entity>.json`
  ///      (its `files[].path` entries),
  ///   2. a search under `<outputDir>/data/providers/` for a file
  ///      implementing the target interface.
  ///
  /// The target interface is [service] when given, else the entity's
  /// receipt `interface` value, else `<Entity>Service`.
  Future<ProviderVerifyReport> verify({
    required String projectRoot,
    required String entity,
    String? service,
    String? outputDir,
  }) async {
    final root = outputDir ?? p.join(projectRoot, 'lib', 'src');
    final interface = await _resolveInterface(projectRoot, entity, service);
    final providerName = '${entity}Provider';
    final findings = <ProviderVerifyFinding>[];

    var providerFile = await _resolveProviderFile(
      projectRoot,
      root,
      entity,
      interface,
    );

    if (providerFile == null) {
      return ProviderVerifyReport(
        ok: false,
        entity: entity,
        providerFile: null,
        interface: interface,
        methods: const [],
        stubCount: 0,
        findings: [
          ProviderVerifyFinding(
            kind: ProviderVerifyFinding.kindMissingProvider,
            file: '',
            method: '',
            detail:
                'no provider file found for "$entity" implementing '
                '$interface',
            fix:
                '--> fix: generate it first — '
                '`zfa provider create --name $entity` '
                '(a provider implements a service interface; create the '
                'service first if it does not exist: '
                '`zfa service create --name $entity`).',
          ),
        ],
      );
    }
    // Normalize to an absolute path for the findings.
    final absoluteProvider = p.isAbsolute(providerFile)
        ? providerFile
        : p.join(projectRoot, providerFile);

    final source = File(absoluteProvider).readAsStringSync();
    var scan = scanSource(source, providerName);
    scan ??=
        _scanForImplementor(source, interface) ??
        ProviderClassScan(className: providerName, methods: [], stubs: []);

    // ── Stub gate (order 2) ────────────────────────────────────────────
    for (final stub in scan.stubs) {
      findings.add(
        ProviderVerifyFinding(
          kind: ProviderVerifyFinding.kindStub,
          file: absoluteProvider,
          method: stub,
          detail:
              '$providerName.$stub still throws UnimplementedError — '
              'the stub body shipped with generation was never filled',
          fix:
              '--> fix: implement $stub in $absoluteProvider (the TDD '
              'flow fills generated stubs), or regenerate with '
              '`zfa provider create --name $entity --force`.',
        ),
      );
    }

    // ── Conformance gate (order 4) ─────────────────────────────────────
    final interfaceMethods = await _interfaceMethods(
      projectRoot,
      root,
      interface,
    );
    if (interfaceMethods == null) {
      findings.add(
        ProviderVerifyFinding(
          kind: ProviderVerifyFinding.kindMissingService,
          file: absoluteProvider,
          method: '',
          detail:
              'the service interface $interface declared by the '
              'provider could not be found on disk — conformance cannot '
              'be proven',
          fix:
              '--> fix: create the interface '
              '(`zfa service create --name $entity`) or regenerate the '
              'provider against an existing service.',
        ),
      );
    } else {
      final declared = scan.methods.toSet();
      for (final method in interfaceMethods) {
        if (!declared.contains(method)) {
          findings.add(
            ProviderVerifyFinding(
              kind: ProviderVerifyFinding.kindMissingMethod,
              file: absoluteProvider,
              method: method,
              detail:
                  '$providerName does not implement '
                  '$interface.$method — the provider is missing an '
                  'interface member (the #921 guard, provider analog)',
              fix:
                  '--> fix: implement $method on $providerName — '
                  '`zfa provider create --name $entity --force` '
                  'regenerates the mirror, or add the member by hand.',
            ),
          );
        }
      }
    }

    return ProviderVerifyReport(
      ok: findings.isEmpty,
      entity: entity,
      providerFile: absoluteProvider,
      interface: interface,
      methods: interfaceMethods ?? const [],
      stubCount: scan.stubs.length,
      findings: findings,
    );
  }

  /// When the expected `<Entity>Provider` class is absent from the file,
  /// fall back to whichever class implements the interface (naming drift
  /// tolerance) so the gates still report real findings.
  ProviderClassScan? _scanForImplementor(String source, String interface) {
    final implementsIdx = source.indexOf('implements $interface');
    if (implementsIdx == -1) return null;
    final classMatch = RegExp(
      r'class\s+(\w+)',
    ).allMatches(source.substring(0, implementsIdx));
    if (classMatch.isEmpty) return null;
    final className = classMatch.last.group(1)!;
    return scanSource(source, className);
  }

  Future<String> _resolveInterface(
    String projectRoot,
    String entity,
    String? service,
  ) async {
    if (service != null) {
      return service.endsWith('Service') ? service : '${service}Service';
    }
    final receipt = _loadReceipt(projectRoot, entity);
    final fromReceipt = receipt?['interface'];
    if (fromReceipt is String && fromReceipt.isNotEmpty) {
      return fromReceipt;
    }
    return '${entity}Service';
  }

  Future<String?> _resolveProviderFile(
    String projectRoot,
    String outputDir,
    String entity,
    String interface,
  ) async {
    // 1. The deterministic receipt knows exactly which file this entity's
    //    generation run wrote.
    final receipt = _loadReceipt(projectRoot, entity);
    if (receipt != null) {
      final files = receipt['files'];
      if (files is List) {
        for (final entry in files) {
          if (entry is Map<String, dynamic>) {
            final path = entry['path'];
            if (path is String && path.endsWith('_provider.dart')) {
              final absolute = p.isAbsolute(path)
                  ? path
                  : p.join(projectRoot, path);
              if (File(absolute).existsSync()) return absolute;
            }
          }
        }
      }
    }

    // 2. Search the providers tree for the implementor.
    final found = await FileUtils.findFileImplementing(
      p.join(outputDir, 'data', 'providers'),
      interface,
    );
    if (found != null && File(found).existsSync()) return found;
    if (found != null) {
      final absolute = p.isAbsolute(found) ? found : p.join(projectRoot, found);
      if (File(absolute).existsSync()) return absolute;
    }
    return null;
  }

  /// The declared method names of [interface], or null when the interface
  /// file cannot be found (a missing_service finding, not an empty set).
  Future<List<String>?> _interfaceMethods(
    String projectRoot,
    String outputDir,
    String interface,
  ) async {
    final base = interface.endsWith('Service')
        ? interface.substring(0, interface.length - 7)
        : interface;
    final snake = _camelToSnake(base);
    final candidates = <String>[
      p.join(outputDir, 'domain', 'services', '${snake}_service.dart'),
    ];
    // Entity-based services live one domain folder deeper.
    final servicesDir = Directory(p.join(outputDir, 'domain', 'services'));
    if (servicesDir.existsSync()) {
      for (final entity in servicesDir.listSync()) {
        if (entity is Directory) {
          candidates.add(p.join(entity.path, '${snake}_service.dart'));
        }
      }
    }
    for (final candidate in candidates) {
      if (!File(candidate).existsSync()) continue;
      final parsed = await MethodExtractor.extractMethodsFromInterface(
        candidate,
        interface,
      );
      if (parsed.isNotEmpty) {
        return parsed.map((m) => m.fieldName).toList();
      }
      // The file exists and names the interface but declares no methods.
      if (await _fileDeclares(candidate, interface)) return const [];
    }
    return null;
  }

  Future<bool> _fileDeclares(String path, String interface) async {
    try {
      final source = File(path).readAsStringSync();
      return source.contains('class $interface');
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? _loadReceipt(String projectRoot, String entity) {
    final file = File(
      p.join(projectRoot, '.zfa', 'receipts', 'provider-$entity.json'),
    );
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _camelToSnake(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}

/// Visits a subtree looking for any `UnimplementedError` construction.
class _UnimplementedErrorVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.toString() == 'UnimplementedError') {
      found = true;
      return;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // The parse-level AST (no resolution): `UnimplementedError('x')`
    // written without `new` — the exact shape the provider generator
    // emits for every stub body — parses as a MethodInvocation of the
    // class name. Match it so the gate never misses a generated stub;
    // a hand-written real implementation never CALLS a method with that
    // name (it would not compile).
    if (node.methodName.toString() == 'UnimplementedError') {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }
}
