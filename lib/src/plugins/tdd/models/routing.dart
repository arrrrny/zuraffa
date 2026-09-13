/// Routing vocabulary for declared-intent routing (feature 071, issue
/// #951): the types the [RoutingResolver] consumes and produces. Pure
/// data + one pure signature parser; no I/O. Shapes per
/// specs/071-declared-intent-routing/data-model.md.
library;

import '../../../models/mock_priority.dart';
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

/// The refusal for a parameter region [Signature.parse] cannot express
/// in the supported grammar (SPEC 1536 FR-005/FR-006): stray or
/// unbalanced grouping characters, or a nested `(...)` the flat
/// parameters capture cannot hold. A [FormatException] subtype so
/// refusal surfaces discriminate the kind by TYPE, never by message
/// prose; the message carries its own `--> fix:` line.
class ParameterSyntaxException extends FormatException {
  ParameterSyntaxException(super.message);
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

  /// The supported contract-row parameter grammar (SPEC 1536, FR-006),
  /// documented at the ONE parse site every consumer shares:
  ///
  /// - positional `Type name` pairs (`String id`) or bare types
  ///   (`String` — the name is derived);
  /// - an optional-positional group (`[int a, int b]`);
  /// - a Dart named-parameter group (`{Object? level, Object? onRecord}`
  ///   or the names-only form `{level, onRecord}` — a single identifier
  ///   inside the group is the parameter NAME, type `Object?`).
  ///
  /// Groups survive the split as ONE token that keeps its grouping
  /// characters: a comma inside `{}` / `[]` / `<>` never splits the
  /// token, so generics (`Map<String, int>`) and groups ride whole.
  /// The parameters region itself ends at the first `)` ([_shape]'s
  /// `[^)]*` capture), so function-typed parameters are not part of
  /// the supported grammar: they never reach this splitter and refuse
  /// in [Signature.parse] with their own named remedy.
  static List<String> splitParameterTokens(String params) {
    final tokens = <String>[];
    final current = StringBuffer();
    final openers = <String>{'{', '[', '(', '<'};
    final closers = {'}': '{', ']': '[', ')': '(', '>': '<'};
    final stack = <String>[];
    for (var i = 0; i < params.length; i++) {
      final ch = params[i];
      if (openers.contains(ch)) {
        stack.add(ch);
        current.write(ch);
        continue;
      }
      final closer = closers[ch];
      if (closer != null) {
        // A closer without its opener is stray — keep it in the token
        // so the well-formedness check below refuses the row.
        if (stack.isNotEmpty && stack.last == closer) {
          stack.removeLast();
        }
        current.write(ch);
        continue;
      }
      if (ch == ',' && stack.isEmpty) {
        tokens.add(current.toString().trim());
        current.clear();
        continue;
      }
      current.write(ch);
    }
    final rest = current.toString().trim();
    if (rest.isNotEmpty) tokens.add(rest);
    return tokens;
  }

  /// Whether [token] is a well-formed parameter token under the
  /// [splitParameterTokens] grammar: every grouping character is
  /// balanced and properly nested (`{level, onRecord}` is, `{level` and
  /// `}level` are not). A `(` can only appear STRAY here — `_shape`'s
  /// `[^)]*` capture severs a function type before its closing `)` —
  /// so tracking it refuses the severed head instead of degrading it
  /// into rendered source. SPEC 1536 FR-005: an unparseable token
  /// REFUSES with a named remedy instead of silently degrading into a
  /// non-compiling pair.
  static bool isWellFormedParameterToken(String token) {
    final openers = <String>{'{', '[', '(', '<'};
    final closers = {'}': '{', ']': '[', ')': '(', '>': '<'};
    final stack = <String>[];
    for (var i = 0; i < token.length; i++) {
      final ch = token[i];
      if (openers.contains(ch)) {
        stack.add(ch);
      } else if (closers.containsKey(ch)) {
        if (stack.isEmpty || stack.last != closers[ch]) return false;
        stack.removeLast();
      }
    }
    return stack.isEmpty;
  }

  /// The refusal message for an unparseable parameter [token] (SPEC
  /// 1536 FR-005/FR-006): names the supported grammar and the remedy.
  static String parameterSyntaxRemedy(String token) =>
      'parameter syntax "$token" is not parseable — the supported '
      'grammar is positional `name(Type) -> Return` rows (positional '
      '`Type name` pairs, optional-positional `[...]` groups) and named '
      '`{a, b}` groups (`{Type name, ...}` or the names-only '
      '`{name, ...}` form).\n'
      "   --> fix: use the supported parameter grammar, e.g. "
      '`log(String id, {Object? level, Object? onRecord}) -> void`.';

  /// The refusal message for a signature whose parameters nest a `(...)`
  /// — a function-typed parameter (`void Function(int) cb`) — which the
  /// flat [_shape] capture cannot hold (SPEC 1536 FR-005): names the
  /// real cause and the remedy.
  static String functionTypedParameterRemedy(String raw) =>
      'signature "$raw" is not a flat `name(Params) -> Return`: the '
      'parameters region ends at the first `)`, so a function-typed '
      'parameter (`void Function(int) cb`, or the named-group entry '
      '`{void Function(int) cb}`) is not part of the supported '
      'grammar.\n'
      '   --> fix: declare the callback parameter with a plain type — '
      'a typedef or class name, e.g. '
      '`log(OnRecordHandler onRecord) -> void`.';

  /// Parse declared signature text. Throws a plain [FormatException] on
  /// a missing return part — the resolver turns that into a
  /// `malformedDeclaration` refusal naming the row. Throws
  /// [ParameterSyntaxException] on a parameter token with
  /// stray/unbalanced grouping characters and on a function-typed
  /// parameter (`void Function(int) cb` — the flat [_shape] capture
  /// cannot hold a nested `(...)`); its message names the supported
  /// grammar and the remedy (SPEC 1536 FR-005), so the row refuses at
  /// plan time instead of emitting a pair that can only die at
  /// verify-red.
  factory Signature.parse(String raw) {
    final m = _shape.firstMatch(raw);
    if (m == null) {
      // SPEC 1536 FR-005: a function-typed parameter nests a `)` that
      // the flat capture cannot hold, so the shape misses even though
      // the `-> Return` part is present — refuse with the REAL cause
      // instead of the missing-`-> Return` advice.
      if (raw.contains('->') && raw.contains('Function(')) {
        throw ParameterSyntaxException(functionTypedParameterRemedy(raw));
      }
      throw FormatException('not a `name(Params) -> Return` signature: $raw');
    }
    final params = splitParameterTokens(
      m.group(2)!,
    ).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    for (final token in params) {
      if (!isWellFormedParameterToken(token)) {
        throw ParameterSyntaxException(parameterSyntaxRemedy(token));
      }
    }
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
  service,
  function,
}

/// A declared contract row an author can trace a behavior to.
class ContractRowDecl {
  final String name;
  final ContractRowKind kind;
  final List<Signature> signatures;

  /// The declared mock priority (issue #960) — orders dependency-mock
  /// materialization in the loop (P1 → P2 → P3 → none).
  final MockPriority priority;

  /// Raw signature text not yet parsed (parsed lazily by the resolver
  /// so a malformed row names itself instead of failing the parse).
  final List<String> rawSignatures;
  final int? specLine;

  const ContractRowDecl({
    required this.name,
    required this.kind,
    this.signatures = const [],
    this.rawSignatures = const [],
    this.priority = MockPriority.none,
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
