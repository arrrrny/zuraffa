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
library;

import '../models/routing.dart';

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
/// renderable before its class exists — the honest degradation is
/// `Object?` with the declared type preserved in the doc comment
/// (issue #1007 pattern).
bool isRenderableDartType(String type) {
  final trimmed = type.trim();
  var base = trimmed;
  if (base.endsWith('?')) base = base.substring(0, base.length - 1).trim();
  if (_renderableScalars.contains(base)) return true;
  final generic = RegExp(r'^(List|Set|Iterable)<(.+)>$').firstMatch(base);
  if (generic != null) return isRenderableDartType(generic.group(2)!.trim());
  final map = RegExp(r'^Map<\s*([^,>]+)\s*,\s*(.+)>$').firstMatch(base);
  if (map != null) {
    return isRenderableDartType(map.group(1)!.trim()) &&
        isRenderableDartType(map.group(2)!.trim());
  }
  return false;
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

/// One declared parameter rendered for a unit subject: the declared
/// type verbatim, the renderable degradation, and a derived name.
class UnitContractParam {
  const UnitContractParam({
    required this.declaredType,
    required this.type,
    required this.name,
  });

  /// The declared token verbatim (`AuthRequest`).
  final String declaredType;

  /// The renderable type the generated source uses (`Object?` when the
  /// declared type is an entity that may not exist yet).
  final String type;

  /// The derived parameter name (`authRequest`).
  final String name;
}

/// The contract-derived shape of a unit subject.
class UnitContractShape {
  const UnitContractShape({
    required this.declaredSignature,
    required this.declaredReturn,
    required this.returnType,
    required this.params,
    required this.scalarOutcome,
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
  final bool scalarOutcome;

  /// Derive the shape from a parsed [Signature]. Never null: a declared
  /// signature is always renderable under the degradation rules.
  static UnitContractShape of(Signature signature) {
    final declaredReturn = signature.returnType.trim();
    final returnRenderable = isRenderableDartType(declaredReturn);
    final params = <UnitContractParam>[];
    final usedNames = <String>{};
    for (final token in signature.parameters) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      // A declared token may carry its own name (`AuthRequest request`)
      // — the last identifier-shaped word is the name, the rest the type.
      String declaredType;
      String? declaredName;
      if (parts.length >= 2 && _isIdentifier(parts.last)) {
        declaredName = parts.last;
        declaredType = parts.sublist(0, parts.length - 1).join(' ');
      } else {
        declaredType = trimmed;
      }
      final renderable = isRenderableDartType(declaredType);
      final name = _unique(
        declaredName ?? _defaultParamName(declaredType),
        usedNames,
      );
      params.add(
        UnitContractParam(
          declaredType: declaredType,
          type: renderable ? declaredType : 'Object?',
          name: name,
        ),
      );
    }
    return UnitContractShape(
      declaredSignature: signature.toString(),
      declaredReturn: declaredReturn,
      returnType: returnRenderable ? declaredReturn : 'Object?',
      params: params,
      scalarOutcome: returnRenderable && isAssertableScalarType(declaredReturn),
    );
  }

  static bool _isIdentifier(String s) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);

  /// The parameter name for a type-only declaration token. Scalar types
  /// get a readable default; entity types camelCase the declared name.
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
    final head = words.first.toLowerCase();
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
