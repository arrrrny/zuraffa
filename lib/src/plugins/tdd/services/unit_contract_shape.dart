/// UnitContractShape — the contract-derived subject shape for UNIT-lane
/// behaviors (issue #1259).
///
/// Bug #1259: `zfa tdd gen` derived a subject signature disconnected
/// from the spec's declared Layer Contracts (`int subject_u1(String id,
/// num value)` for a behavior whose spec declared
/// `AuthRepo: login(AuthRequest) -> User`), and the paired test's only
/// assertion was the UnimplementedError guard — a placeholder subject
/// returning a dummy value flipped the test green without implementing
/// anything.
///
/// Remediation (issue #1259): gen derives the subject signature from the
/// spec's DECLARED Layer Contracts — params from the request entity,
/// return from the result entity. This helper turns a parsed
/// [Signature] into the compilable shape the writers render.
///
/// Compilability contract (FR-011): the declared request/result entity
/// types may not exist yet (the TDD red phase precedes implementation),
/// so a non-renderable declared type degrades to `Object?` with the
/// declared type preserved alongside — the same pattern the contract
/// lane's writers use (issue #1007). Scalar declared types render
/// verbatim and give the paired test a mechanically assertable outcome
/// surface.
///
/// SPEC 1489 — the degradation is CONDITIONAL, not permanent: when the
/// entity exists on disk (phase-0 has already created it before gen
/// spawns, or the feature declares a pre-existing entity), the registry
/// access via `locateEntityFile` lifts it. The declared type then
/// renders verbatim (`Task subject_u1(...)`, import included) and
/// `scalarOutcome` treats the entity return as a mechanically assertable
/// outcome — the behavior leaves the hand-step seam. The degradation to
/// `Object?` is unconditional ONLY for entities that do not exist on
/// disk, and for callers that pass no registry at all (the legacy
/// byte-for-byte shapes).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/routing.dart';
import 'entity_lookup.dart';

/// The sync entity-membership predicate the renderability check consults
/// for non-scalar base types (SPEC 1489): true when the entity's file
/// exists on disk (the registry fact `locateEntityFile` answers).
typedef EntityExistsPredicate = bool Function(String entityName);

bool _isDartIdentifier(String s) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);

/// The scalar types a generated subject may reference without imports.
const Set<String> _renderableScalars = {
  'void',
  'Never',
  'bool',
  'String',
  'int',
  'double',
  'num',
  'dynamic',
  'Object',
};

/// Whether [type] can be rendered into generated source verbatim: the
/// scalars, their nullable variants, and generics whose type arguments
/// are all renderable. An entity type (`User`, `AuthRequest`) is NOT
/// renderable while its class does not exist — the honest degradation is
/// `Object?` with the declared type preserved in the doc comment
/// (issue #1007 pattern).
///
/// SPEC 1489: when [entityExists] is supplied, an entity type whose file
/// exists on disk IS renderable — the declared type renders verbatim
/// (import included) instead of degrading. The predicate is consulted
/// for every non-scalar base type: single entities (`Task`), their
/// nullable variants (`Task?`), generics (`List<Task>`) and map values
/// (`Map<String, Task>`). Null keeps the legacy behavior byte-for-byte:
/// every entity degrades unconditionally.
bool isRenderableDartType(String type, {EntityExistsPredicate? entityExists}) {
  final trimmed = type.trim();
  var base = trimmed;
  if (base.endsWith('?')) base = base.substring(0, base.length - 1).trim();
  if (_renderableScalars.contains(base)) return true;
  final generic = RegExp(r'^(List|Set|Iterable)<(.+)>$').firstMatch(base);
  if (generic != null) {
    return isRenderableDartType(
      generic.group(2)!.trim(),
      entityExists: entityExists,
    );
  }
  final map = RegExp(r'^Map<\s*([^,>]+)\s*,\s*(.+)>$').firstMatch(base);
  if (map != null) {
    return isRenderableDartType(
          map.group(1)!.trim(),
          entityExists: entityExists,
        ) &&
        isRenderableDartType(map.group(2)!.trim(), entityExists: entityExists);
  }
  // SPEC 1489: not a scalar — an entity base type. The registry lifts
  // the degradation when the entity exists on disk.
  if (entityExists != null && _isDartIdentifier(base)) {
    return entityExists(base);
  }
  return false;
}

/// Whether [type] renders verbatim WITHOUT consulting any entity
/// registry — the scalars, their nullable variants, and generics whose
/// type arguments are all scalars. SPEC 1489's entity lift never
/// applies: this is the predicate-less legacy check, used to tell a
/// genuinely scalar declared type from one the registry lifted.
bool isRenderableScalarType(String type) => isRenderableDartType(type);

/// Collects every entity base name [type] references — the non-scalar
/// identifier bases left after stripping nullability and recursing
/// through generics (`List<Task>` → `Task`, `Map<String, Task>` →
/// `Task`). Scalars and type-shaped non-identifiers emit nothing.
void _collectEntityNames(String type, void Function(String name) emit) {
  var base = type.trim();
  if (base.endsWith('?')) base = base.substring(0, base.length - 1).trim();
  if (_renderableScalars.contains(base)) return;
  final generic = RegExp(r'^(List|Set|Iterable)<(.+)>$').firstMatch(base);
  if (generic != null) {
    _collectEntityNames(generic.group(2)!, emit);
    return;
  }
  final map = RegExp(r'^Map<\s*([^,>]+)\s*,\s*(.+)>$').firstMatch(base);
  if (map != null) {
    _collectEntityNames(map.group(1)!, emit);
    _collectEntityNames(map.group(2)!, emit);
    return;
  }
  if (_isDartIdentifier(base)) emit(base);
}

/// Whether a declared return type is a mechanically assertable scalar
/// outcome — the paired test can emit `expect(result, isA<T>())` and
/// the assertion is NOT the UnimplementedError guard (issue #1259:
/// green requires at least one observable-outcome assertion). `void`,
/// `dynamic`, `Object`, `Never` and entity types are excluded: asserting
/// `isA<Object?>()` proves nothing.
bool isAssertableScalarType(String type) {
  final base = type.trim();
  return const {'bool', 'String', 'int', 'double', 'num'}.contains(base);
}

/// The import URI for the entity [entityName] whose file sits at the
/// lib-relative path [libRelativePath] (`src/domain/entities/task/task.dart`).
/// A resolvable [packageName] yields the lint-clean `package:` URI; the
/// fallback is the relative path from the subject's home
/// (`lib/tdd/<feature>/`) into `lib/` — `../../` + the lib-relative
/// path. Null is never returned for a non-null path.
String entityImportUri(String libRelativePath, String? packageName) {
  if (packageName != null && !libRelativePath.startsWith('..')) {
    return 'package:$packageName/$libRelativePath';
  }
  return '../../$libRelativePath';
}

/// One declared parameter rendered for a unit subject: the declared
/// type verbatim, the renderable degradation, and a derived name.
class UnitContractParam {
  const UnitContractParam({
    required this.declaredType,
    required this.type,
    required this.name,
    this.named = false,
  });

  /// The declared token verbatim (`AuthRequest`).
  final String declaredType;

  /// The renderable type the generated source uses (`Object?` when the
  /// declared type is an entity that may not exist yet).
  final String type;

  /// The derived parameter name (`authRequest`).
  final String name;

  /// SPEC 1536: whether the parameter was declared inside a Dart
  /// named-parameter group (`({a, b})`). Named params render `{...}` in
  /// subject signatures and pass named arguments at the paired test's
  /// capture site. False for every positional parameter — the legacy
  /// shapes are byte-for-byte unchanged.
  final bool named;
}

/// The contract-derived shape of a unit subject.
class UnitContractShape {
  const UnitContractShape({
    required this.declaredSignature,
    required this.declaredReturn,
    required this.returnType,
    required this.params,
    required this.scalarOutcome,
    this.entityReturn = false,
    this.entityImports = const [],
    this.returnEntityImports = const [],
  });

  /// The declared signature text for provenance headers
  /// (`login(AuthRequest) -> User`).
  final String declaredSignature;

  /// The declared return type verbatim (`User`).
  final String declaredReturn;

  /// The renderable return type (`Object?` when the declared return is
  /// a non-renderable entity).
  final String returnType;

  /// The declared parameters, in declaration order.
  final List<UnitContractParam> params;

  /// Whether the declared return type is a mechanically assertable
  /// scalar (`isA<T>()` emit) — see [isAssertableScalarType].
  ///
  /// SPEC 1489: an EXISTING entity return is also mechanically
  /// assertable (`isA<Task>()` proves the declared outcome) — the paired
  /// test emits the typed assertion instead of routing the behavior to
  /// the hand-step seam. Missing entities keep `false` (the #1308
  /// vacuous-guard seam, unchanged).
  final bool scalarOutcome;

  /// Whether the declared RETURN became renderable through the entity
  /// registry (SPEC 1489) — a non-scalar declared return the registry
  /// lifted. False for plain scalars, for missing entities, and for
  /// every shape derived without a registry.
  final bool entityReturn;

  /// The import URIs for every EXISTING entity the declared signature
  /// references — params first (declaration order), then the return —
  /// deduplicated. Empty when no entity exists on disk (or the shape is
  /// legacy). The subject writer emits these so the stub compiles
  /// against the declared types out of the box (SPEC 1489 SC-2).
  final List<String> entityImports;

  /// The import URIs for the entities the declared RETURN references
  /// (SPEC 1489). The paired test imports exactly these when its
  /// assertion references the declared type — never the param entities
  /// (the `_argN()` placeholders own those), so no unused imports.
  final List<String> returnEntityImports;

  /// Derive the shape from a parsed [Signature]. Never null: a declared
  /// signature is always renderable under the degradation rules.
  ///
  /// SPEC 1489: pass [entityExists] (the entity registry — what
  /// `locateEntityFile` answers) and [entityFiles] (the resolved
  /// lib-relative entity paths) to lift the degradation for entities
  /// that exist on disk; [packageName] turns their import URIs into the
  /// lint-clean `package:` form. Omit all three for the legacy shapes —
  /// byte-for-byte today's behavior.
  static UnitContractShape of(
    Signature signature, {
    EntityExistsPredicate? entityExists,
    Map<String, String> entityFiles = const {},
    String? packageName,
  }) {
    final declaredReturn = signature.returnType.trim();
    final returnRenderable = isRenderableDartType(
      declaredReturn,
      entityExists: entityExists,
    );
    // SPEC 1489: the return is an entity the registry lifted — not a
    // plain scalar. Drives both scalarOutcome and the test-side import.
    final entityReturn =
        returnRenderable && !isRenderableDartType(declaredReturn);
    final params = <UnitContractParam>[];
    final usedNames = <String>{};
    // SPEC 1536: the ONE token-expansion grammar (_expandParamTokens) —
    // positional tokens keep the legacy split, named-group tokens
    // expand into individual named parameters.
    for (final part in _expandParamTokens(signature.parameters)) {
      final renderable = isRenderableDartType(
        part.declaredType,
        entityExists: entityExists,
      );
      final name = _unique(
        part.declaredName ?? _defaultParamName(part.declaredType),
        usedNames,
      );
      params.add(
        UnitContractParam(
          declaredType: part.declaredType,
          type: renderable ? part.declaredType : 'Object?',
          name: name,
          named: part.named,
        ),
      );
    }
    // SPEC 1489: the import URIs for every EXISTING entity the signature
    // references — params first (declaration order), then the return,
    // deduplicated. Missing entities contribute nothing.
    final importUris = <String>{};
    for (final param in params) {
      _collectEntityNames(param.declaredType, (name) {
        final rel = entityFiles[name];
        if (rel == null) return;
        importUris.add(entityImportUri(rel, packageName));
      });
    }
    final returnEntityUris = <String>{};
    _collectEntityNames(declaredReturn, (name) {
      final rel = entityFiles[name];
      if (rel == null) return;
      final uri = entityImportUri(rel, packageName);
      returnEntityUris.add(uri);
      importUris.add(uri);
    });
    return UnitContractShape(
      declaredSignature: signature.toString(),
      declaredReturn: declaredReturn,
      returnType: returnRenderable ? declaredReturn : 'Object?',
      params: params,
      scalarOutcome:
          returnRenderable &&
          (isAssertableScalarType(declaredReturn) || entityReturn),
      entityReturn: entityReturn,
      entityImports: importUris.toList(growable: false),
      returnEntityImports: returnEntityUris.toList(growable: false),
    );
  }

  /// Resolve the shape against the entity registry on disk (SPEC 1489):
  /// every candidate entity name in [signature] is checked with
  /// `locateEntityFile` under [cwd] — the SAME fact the run driver's
  /// phase-0 consults, so an entity phase-0 created before gen spawned
  /// renders with its declared type. The consumer's package name is read
  /// from the pubspec at [cwd] so the emitted imports are lint-clean
  /// `package:` URIs. Entities that do not exist keep the unconditional
  /// `Object?` degradation.
  static Future<UnitContractShape> ofResolved(
    Signature signature, {
    required String cwd,
  }) async {
    // The candidate entities: params first (declaration order, with the
    // same type/name split `of` applies), then the return.
    final candidates = <String>[];
    void addCandidates(String declaredType) {
      _collectEntityNames(declaredType, (name) {
        if (!candidates.contains(name)) candidates.add(name);
      });
    }

    for (final part in _expandParamTokens(signature.parameters)) {
      addCandidates(part.declaredType);
    }
    addCandidates(signature.returnType.trim());

    // The registry fact: which candidates exist on disk, and where.
    final entityFiles = <String, String>{};
    for (final name in candidates) {
      final file = await locateEntityFile(cwd, name);
      if (file == null) continue;
      entityFiles[name] = p.relative(file, from: p.join(cwd, 'lib'));
    }
    return of(
      signature,
      entityExists: entityFiles.containsKey,
      entityFiles: entityFiles,
      packageName: _packageName(cwd),
    );
  }

  /// The consumer's package name — the `name:` line of the pubspec at
  /// [cwd]. Null when absent or unreadable (fixture contexts): the import
  /// URIs fall back to the lib-relative shape.
  static String? _packageName(String cwd) {
    final file = File(p.join(cwd, 'pubspec.yaml'));
    if (!file.existsSync()) return null;
    try {
      return RegExp(
        r'^name:\s*(.+?)\s*$',
        multiLine: true,
      ).firstMatch(file.readAsStringSync())?.group(1)?.trim();
    } on FileSystemException {
      return null;
    }
  }

  /// How many of [declaredReturns] still hand-step (SPEC 1489 SC-4): an
  /// entity-shaped declared return whose entity does NOT exist on disk.
  /// Scalars and void/dynamic/Object/Never are never seams; undeclared
  /// behaviors (null) are not counted; an entity the registry lifted is
  /// no longer a seam — that is the whole point of the fix.
  static int countEntityReturnSeams({
    required Iterable<String?> declaredReturns,
    EntityExistsPredicate? entityExists,
  }) {
    var seams = 0;
    for (final declared in declaredReturns) {
      final returnType = declared?.trim();
      if (returnType == null || returnType.isEmpty) continue;
      if (isRenderableDartType(returnType)) continue; // plain scalar
      if (!isRenderableDartType(returnType, entityExists: entityExists)) {
        seams++;
      }
    }
    return seams;
  }

  /// The resolved seam-cost count for command-side callers (plan, run
  /// driver): resolves each [declared] signature against the registry at
  /// [cwd] via [ofResolved] and counts the entity-shaped returns still
  /// degrading. Malformed/missing artifacts are the caller's problem —
  /// pass null for an undeclared behavior. Best-effort by contract: a
  /// resolution failure counts nothing for that behavior.
  static Future<int> countEntityReturnSeamsResolved({
    required Iterable<Signature?> declared,
    required String cwd,
  }) async {
    var seams = 0;
    for (final signature in declared) {
      if (signature == null) continue;
      if (isRenderableDartType(signature.returnType)) continue; // plain scalar
      try {
        final shape = await ofResolved(signature, cwd: cwd);
        if (!shape.scalarOutcome) seams++;
      } on Exception {
        // Best-effort forecast: an unreadable artifact is not a seam.
      }
    }
    return seams;
  }

  /// The surfaced seam-cost line (SPEC 1489 SC-4). Null when there is
  /// nothing to surface — a lane whose every unit behavior asserts a
  /// real outcome prints no forecast.
  static String? entityReturnSeamCostLine({
    required int seams,
    required int total,
  }) {
    if (seams <= 0) return null;
    return 'Seam cost: $seams of $total unit behaviors will hand-step '
        'because return is an entity.';
  }

  static bool _isIdentifier(String s) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);

  /// The parameter list the generated source renders (SPEC 1536,
  /// FR-003) — the ONE renderer every generated signature shares: the
  /// positional parameters first, then the named group as ONE trailing
  /// `{...}` block. A signature with no named params renders exactly
  /// the legacy positional list, byte-for-byte.
  ///
  /// Consumers: [SubjectWriter] (the gen stub) and `func_command`'s
  /// declared scaffold (`zfa tdd func`) — the grammar lives in ONE
  /// place, never scattered across call sites (#1323 lesson).
  static String renderParameterList(List<UnitContractParam> params) {
    final positional = params
        .where((param) => !param.named)
        .map((param) => '${param.type} ${param.name}')
        .toList();
    final named = params
        .where((param) => param.named)
        .map((param) => '${param.type} ${param.name}')
        .toList();
    return [
      ...positional,
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ].join(', ');
  }

  /// The parameter name for a type-only declaration token. Scalar types
  /// get a readable default; entity types camelCase the declared name.
  ///
  /// SPEC 1536 (FR-004): an already lower-first word is kept VERBATIM —
  /// `onRecord` must not degrade to `onrecord` (the issue's Defect 2
  /// mangle). Upper-first type-derived names keep the legacy output
  /// byte-for-byte (`AuthRequest` → `authrequest`), so no existing
  /// positional row's generated shape changes.
  static String _defaultParamName(String declaredType) {
    final base = declaredType.trim().endsWith('?')
        ? declaredType.trim().substring(0, declaredType.trim().length - 1)
        : declaredType.trim();
    switch (base) {
      case 'String':
        return 'text';
      case 'int':
      case 'num':
        return 'value';
      case 'bool':
        return 'flag';
      case 'double':
        return 'amount';
      case 'Object':
      case 'dynamic':
        return 'input';
    }
    final camel = base.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
    if (camel.isEmpty) return 'input';
    final words = camel.split(RegExp(r'\s+'));
    // SPEC 1536 (FR-004): a lower-first head word is kept VERBATIM —
    // `onRecord` must not degrade to `onrecord`. An upper-first head
    // keeps the legacy output byte-for-byte (`AuthRequest` →
    // `authrequest` — the legacy rule lowercased the whole word).
    final headWord = words.first;
    final isUpperFirst =
        headWord.isNotEmpty &&
        headWord.codeUnitAt(0) >= 0x41 &&
        headWord.codeUnitAt(0) <= 0x5A;
    final head = isUpperFirst ? headWord.toLowerCase() : headWord;
    final tail = words.skip(1).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join();
    final name = '$head$tail';
    return _isIdentifier(name) ? name : 'input';
  }

  static String _unique(String name, Set<String> used) {
    if (used.add(name)) return name;
    var i = 2;
    while (!used.add('$name$i')) {
      i += 1;
    }
    return '$name$i';
  }
}

/// One declared parameter token split into its parts: the declared type
/// verbatim, the declared name (null when derived), and whether the
/// token came from a Dart named-parameter group (SPEC 1536).
typedef _ParamParts = ({String declaredType, String? declaredName, bool named});

/// The ONE token-expansion grammar every shape derivation shares (the
/// #1323 lesson: the grammar lives in ONE place, never scattered across
/// call sites).
///
/// SPEC 1536 (FR-002): a named-group token (`{a, b}` — kept whole by
/// `Signature.parse`'s brace-aware split) expands into its individual
/// named parameters. Inside a group a single-identifier token is the
/// parameter NAME (Dart named parameters always carry a name) whose
/// renderable type is the shape's `Object?` degradation; a multi-word
/// token keeps the existing `Type name` split. Positional tokens keep
/// the legacy single-identifier = TYPE reading byte-for-byte.
List<_ParamParts> _expandParamTokens(Iterable<String> tokens) {
  final parts = <_ParamParts>[];
  for (final token in tokens) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) continue;
    final namedGroup = trimmed.startsWith('{') && trimmed.endsWith('}');
    if (!namedGroup) {
      parts.add(_paramPartsOf(trimmed, named: false));
      continue;
    }
    final inner = trimmed.substring(1, trimmed.length - 1);
    // The SAME brace-aware splitter the outer parse used — a generic
    // inside the group (`{Map<String, int> table}`) never splits.
    for (final groupToken in Signature.splitParameterTokens(inner)) {
      final g = groupToken.trim();
      if (g.isEmpty) continue;
      parts.add(_paramPartsOf(g, named: true));
    }
  }
  return parts;
}

/// The `Type name` split for one parameter token, positional or inside
/// a named group (SPEC 1536: a single identifier inside a group is a
/// declared NAME with the `Object?` renderable degradation).
_ParamParts _paramPartsOf(String trimmed, {required bool named}) {
  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  // A declared token may carry its own name (`AuthRequest request`)
  // — the last identifier-shaped word is the name, the rest the type.
  if (parts.length >= 2 && _isParamIdentifier(parts.last)) {
    return (
      declaredType: parts.sublist(0, parts.length - 1).join(' '),
      declaredName: parts.last,
      named: named,
    );
  }
  // SPEC 1536: a single identifier inside a named group is the
  // parameter NAME — the type degrades to `Object?` like every
  // non-renderable declared type.
  if (named && parts.length == 1 && _isParamIdentifier(parts.single)) {
    return (declaredType: 'Object?', declaredName: parts.single, named: true);
  }
  return (declaredType: trimmed, declaredName: null, named: named);
}

bool _isParamIdentifier(String s) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);
