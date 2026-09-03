/// Routing vocabulary for declared-intent routing (feature 071, issue
/// #951): the types the [RoutingResolver] consumes and produces. Pure
/// data + one pure signature parser; no I/O. Shapes per
/// specs/071-declared-intent-routing/data-model.md.
library;

import 'behavior.dart';

/// The generation surface a behavior's declared contract row selects.
enum GenerationSurface {
  entityPipeline,
  dependencyMake,
  viewGeneration,
  plainFunction,
  none,
}

/// Which routing aspect a provenance line justifies.
enum RoutingAspect { kind, surface, entity, signature, persistence }

/// Whether an aspect was decided by a declaration or by the legacy
/// (labeled) fallback.
enum RoutingSource { declared, fallback }

/// Typed refusal codes (errors-are-an-API): every message names the
/// spec line(s) and a `--> fix:` hint.
enum RoutingFailureCode {
  declarationConflict,
  danglingReference,
  malformedDeclaration,
  undeclaredStrict,
}

/// One author-readable routing justification.
class ProvenanceLine {
  final RoutingAspect aspect;
  final RoutingSource source;
  final String detail;

  /// The authoritative (or to-be) spec line.
  final int? specLine;

  const ProvenanceLine({
    required this.aspect,
    required this.source,
    required this.detail,
    this.specLine,
  });

  @override
  String toString() =>
      '$aspect ${source == RoutingSource.declared ? 'declared' : 'fallback'}:'
      ' $detail${specLine == null ? '' : ' (spec line $specLine)'}';
}

/// A declared subject signature: `name(Params) -> Return`.
class Signature {
  final String name;
  final List<String> parameters;
  final String returnType;

  const Signature({
    required this.name,
    required this.parameters,
    required this.returnType,
  });

  static final RegExp _shape = RegExp(
    r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*->\s*(.+?)\s*$',
  );

  /// Parse declared signature text. Throws [FormatException] on a
  /// missing return part — the resolver turns that into a
  /// `malformedDeclaration` refusal naming the row.
  factory Signature.parse(String raw) {
    final m = _shape.firstMatch(raw);
    if (m == null) {
      throw FormatException('not a `name(Params) -> Return` signature: $raw');
    }
    final params = m
        .group(2)!
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return Signature(
      name: m.group(1)!,
      parameters: params,
      returnType: m.group(3)!,
    );
  }

  @override
  String toString() => '$name(${parameters.join(', ')}) -> $returnType';
}

/// The kind of a declared contract row, derived from the section that
/// declares it (Layer Contracts layer label, Key Entities table,
/// External Dependencies type).
enum ContractRowKind {
  presentation,
  domain,
  data,
  entity,
  storage,
  channel,
  function,
}

/// A declared contract row an author can trace a behavior to.
class ContractRowDecl {
  final String name;
  final ContractRowKind kind;
  final List<Signature> signatures;

  /// Raw signature text not yet parsed (parsed lazily by the resolver
  /// so a malformed row names itself instead of failing the parse).
  final List<String> rawSignatures;
  final int? specLine;

  const ContractRowDecl({
    required this.name,
    required this.kind,
    this.signatures = const [],
    this.rawSignatures = const [],
    this.specLine,
  });
}

/// A per-scenario routing declaration: the `**Type**:` marker plus the
/// contract-row names the scenario's trace cell names.
class ScenarioDeclaration {
  final String behaviorId;
  final BehaviorKind? declaredType;
  final List<String> contractRefs;
  final int? specLine;

  const ScenarioDeclaration({
    required this.behaviorId,
    this.declaredType,
    this.contractRefs = const [],
    this.specLine,
  });
}

/// A requirement's explicit persistent-storage intent ([persistent]
/// tag or storage-dependency trace).
class PersistenceDeclaration {
  final String behaviorId;

  /// True when declared by an FR tag, false when via a storage row.
  final bool fromTag;
  final int? specLine;

  const PersistenceDeclaration({
    required this.behaviorId,
    this.fromTag = true,
    this.specLine,
  });
}

/// All parsed declarations for one spec (parsed once, consulted per
/// behavior).
class SpecDeclarations {
  final Map<String, ScenarioDeclaration> scenarios;
  final Map<String, ContractRowDecl> contractRows;
  final Map<String, PersistenceDeclaration> persistence;

  const SpecDeclarations({
    this.scenarios = const {},
    this.contractRows = const {},
    this.persistence = const {},
  });
}

/// The per-behavior inputs the resolver needs: the behavior's identity,
/// its test-list declared kind (rung 3 — section header / kind cell),
/// and its raw trace tokens.
class RoutingRow {
  final String behaviorId;
  final BehaviorKind? kind;
  final List<String> traces;

  const RoutingRow({
    required this.behaviorId,
    this.kind,
    this.traces = const [],
  });
}

/// A decided routing: every non-null aspect is DECLARED (never
/// guessed); provenance accounts for each decided aspect.
class RoutingDecision extends RoutingResult {
  final String behaviorId;
  final BehaviorKind kind;

  /// Null = not declared; the caller runs its labeled fallback for the
  /// aspect (migration window) or refuses (strict — the resolver
  /// already produced that failure instead of this decision).
  final GenerationSurface? surface;
  final String? entityName;
  final Signature? signature;
  final bool persistence;
  final List<ProvenanceLine> provenance;

  const RoutingDecision({
    required this.behaviorId,
    required this.kind,
    this.surface,
    this.entityName,
    this.signature,
    this.persistence = false,
    this.provenance = const [],
  });
}

/// No declaration reached the kind ladder: the caller may run its
/// labeled legacy fallback (migration window) — under strict mode the
/// resolver returns [RoutingFailure] instead of this.
class RoutingUndeclared extends RoutingResult {
  final String behaviorId;

  const RoutingUndeclared({required this.behaviorId});
}

/// A typed refusal naming the spec line(s) and the fix.
class RoutingFailure extends RoutingResult {
  final RoutingFailureCode code;
  final String message;

  const RoutingFailure({required this.code, required this.message});
}

/// The outcome of a routing resolution.
sealed class RoutingResult {
  const RoutingResult();
}
