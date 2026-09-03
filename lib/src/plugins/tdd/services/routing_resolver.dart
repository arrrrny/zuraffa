/// `RoutingResolver` — the single owner of declared-intent routing
/// (feature 071, issue #951). Consumes parsed spec declarations and a
/// behavior row; returns a [RoutingDecision] (every non-null aspect is
/// DECLARED), a [RoutingUndeclared] (nothing declares the lane — the
/// caller may run its LABELED legacy fallback in the migration window),
/// or a [RoutingFailure] naming the spec line(s) and the fix.
///
/// Ladder (specs/071-declared-intent-routing/research.md D1):
///   1. per-scenario `**Type**` marker;
///   2. contract-row traces (Layer Contracts / Key Entities /
///      External Dependencies rows);
///   3. the test list's declared kind (section header / kind cell);
///   4. the caller's legacy keyword fallback — OUT OF SCOPE here except
///      that this resolver reports `undeclared` so the caller labels it
///      (strict mode turns that case into `undeclaredStrict` instead).
///
/// Pure: no filesystem, no subprocess, deterministic.
library;

import '../models/behavior.dart';
import '../models/routing.dart';

class RoutingResolver {
  const RoutingResolver();

  /// Tokens shaped like criterion traces (`FR-001`, `AC-2`) are not
  /// contract references and never dangle.
  static final RegExp _criterionToken = RegExp(
    r'^(FR|AC|SC)[-]?\d+',
    caseSensitive: false,
  );

  RoutingResult resolve({
    required RoutingRow row,
    required SpecDeclarations declarations,
    bool strict = false,
  }) {
    final marker = declarations.scenarios[row.behaviorId];

    // ---- resolve trace tokens to contract rows --------------------
    final resolved = <_RowRef>[];
    for (final token in row.traces) {
      final ref = _resolveToken(token, declarations.contractRows);
      if (ref == null) {
        if (_criterionToken.hasMatch(token)) continue;
        return RoutingFailure(
          code: RoutingFailureCode.danglingReference,
          message:
              'behavior "${row.behaviorId}" traces to "$token", which names no '
              'declared contract row (Key Entities, Layer Contracts, or External '
              'Dependencies).\n'
              '   --> fix: declare the row, or correct the trace token.',
        );
      }
      resolved.add(ref);
    }

    // ---- malformed raw signatures on consulted function rows -------
    for (final ref in resolved) {
      if (ref.row.kind != ContractRowKind.function) continue;
      for (final raw in ref.row.rawSignatures) {
        try {
          Signature.parse(raw);
        } on FormatException {
          return RoutingFailure(
            code: RoutingFailureCode.malformedDeclaration,
            message:
                'contract row "${ref.row.name}" carries a malformed signature '
                '"$raw" — declared signatures must be `name(Params) -> Return`.\n'
                '   --> fix: add the `-> Return` part at '
                '${ref.row.specLine ?? 'the row'} .',
          );
        }
      }
    }

    // ---- lane hints: marker + lane-mapped rows ---------------------
    final kindSources = <_KindSource>[];
    if (marker?.declaredType != null) {
      kindSources.add(
        _KindSource(marker!.declaredType!, 'type marker', marker.specLine),
      );
    }
    ContractRowDecl? surfaceRow;
    ContractRowDecl? entityRow;
    ContractRowDecl? functionRow;
    var storageDeclared = false;
    for (final ref in resolved) {
      switch (ref.row.kind) {
        case ContractRowKind.storage:
          storageDeclared = true;
        case ContractRowKind.presentation:
          kindSources.add(
            _KindSource(
              BehaviorKind.widget,
              'contract row: ${ref.row.name}',
              ref.row.specLine,
            ),
          );
          surfaceRow ??= ref.row;
        case ContractRowKind.domain:
        case ContractRowKind.data:
          kindSources.add(
            _KindSource(
              BehaviorKind.unit,
              'contract row: ${ref.row.name}',
              ref.row.specLine,
            ),
          );
          surfaceRow ??= ref.row;
        case ContractRowKind.entity:
          kindSources.add(
            _KindSource(
              BehaviorKind.unit,
              'contract row: ${ref.row.name}',
              ref.row.specLine,
            ),
          );
          surfaceRow ??= ref.row;
          entityRow ??= ref.row;
        case ContractRowKind.function:
          kindSources.add(
            _KindSource(
              BehaviorKind.unit,
              'contract row: ${ref.row.name}',
              ref.row.specLine,
            ),
          );
          surfaceRow ??= ref.row;
          functionRow ??= ref.row;
        case ContractRowKind.channel:
          kindSources.add(
            _KindSource(
              BehaviorKind.platform,
              'contract row: ${ref.row.name}',
              ref.row.specLine,
            ),
          );
          surfaceRow ??= ref.row;
      }
    }

    // Conflicting lane declarations refuse, naming both lines.
    final distinctKinds = kindSources.map((k) => k.kind).toSet();
    if (distinctKinds.length > 1) {
      final lines = kindSources
          .map((k) => '"${k.kind.name}" at ${k.specLine ?? 'test list'}')
          .join(' vs ');
      return RoutingFailure(
        code: RoutingFailureCode.declarationConflict,
        message:
            'behavior "${row.behaviorId}" has conflicting lane declarations: '
            '$lines.\n'
            '   --> fix: keep exactly one routing declaration for '
            '${row.behaviorId}.',
      );
    }

    // ---- rung decision ---------------------------------------------
    BehaviorKind? kind;
    final provenance = <ProvenanceLine>[];
    if (kindSources.isNotEmpty) {
      kind = kindSources.first.kind;
      provenance.add(
        ProvenanceLine(
          aspect: RoutingAspect.kind,
          source: RoutingSource.declared,
          detail: kindSources.first.detail,
          specLine: kindSources.first.specLine,
        ),
      );
    } else if (row.kind != null) {
      kind = row.kind;
      provenance.add(
        const ProvenanceLine(
          aspect: RoutingAspect.kind,
          source: RoutingSource.declared,
          detail: 'test-list kind declaration',
        ),
      );
    }

    // Surface / entity / signature from the deciding rows.
    GenerationSurface? surface;
    String? entityName;
    Signature? signature;
    if (surfaceRow != null) {
      switch (surfaceRow.kind) {
        case ContractRowKind.presentation:
          surface = GenerationSurface.viewGeneration;
        case ContractRowKind.domain:
        case ContractRowKind.data:
        case ContractRowKind.entity:
          surface = GenerationSurface.entityPipeline;
        case ContractRowKind.function:
          surface = GenerationSurface.plainFunction;
        case ContractRowKind.channel:
          surface = GenerationSurface.none;
        case ContractRowKind.storage:
          surface = null;
      }
      if (surface != null) {
        provenance.add(
          ProvenanceLine(
            aspect: RoutingAspect.surface,
            source: RoutingSource.declared,
            detail: 'contract row: ${surfaceRow.name}',
            specLine: surfaceRow.specLine,
          ),
        );
      }
    }
    if (entityRow != null) {
      entityName = entityRow.name;
      provenance.add(
        ProvenanceLine(
          aspect: RoutingAspect.entity,
          source: RoutingSource.declared,
          detail: 'entity row: ${entityRow.name}',
          specLine: entityRow.specLine,
        ),
      );
    }
    if (functionRow != null) {
      signature = _signatureFor(functionRow, row.traces);
      if (signature != null) {
        provenance.add(
          ProvenanceLine(
            aspect: RoutingAspect.signature,
            source: RoutingSource.declared,
            detail: 'contract row: ${functionRow.name}.${signature.name}',
            specLine: functionRow.specLine,
          ),
        );
      }
    }

    // Persistence is orthogonal to the lane ladder.
    var persistence = false;
    final persistenceDecl = declarations.persistence[row.behaviorId];
    if (persistenceDecl != null) {
      persistence = true;
      provenance.add(
        ProvenanceLine(
          aspect: RoutingAspect.persistence,
          source: RoutingSource.declared,
          detail: persistenceDecl.fromTag
              ? '[persistent] tag'
              : 'storage dependency',
          specLine: persistenceDecl.specLine,
        ),
      );
    } else if (storageDeclared) {
      persistence = true;
      provenance.add(
        ProvenanceLine(
          aspect: RoutingAspect.persistence,
          source: RoutingSource.declared,
          detail: 'storage dependency row',
        ),
      );
    }

    // ---- strict gate ------------------------------------------------
    if (kind == null) {
      if (strict) {
        return _undeclaredStrict(row);
      }
      return RoutingUndeclared(behaviorId: row.behaviorId);
    }
    // Widget rows are exempt from the surface requirement: the view
    // lane needs no contract row (the view builder reads the declared
    // Presentation contract directly, issue #939); ffi/platform/theme
    // never had a generation surface.
    final surfaceRequired =
        kind == BehaviorKind.unit || kind == BehaviorKind.acceptance;
    if (strict && surfaceRequired && surface == null) {
      return RoutingFailure(
        code: RoutingFailureCode.undeclaredStrict,
        message:
            'behavior "${row.behaviorId}" declares no generation surface '
            '(strict mode).\n'
            '   --> fix: trace it to a declared contract row, or add a '
            '`**Type**` marker plus a contract trace.',
      );
    }

    return RoutingDecision(
      behaviorId: row.behaviorId,
      kind: kind,
      surface: surface,
      entityName: entityName,
      signature: signature,
      persistence: persistence,
      provenance: provenance,
    );
  }

  RoutingFailure _undeclaredStrict(RoutingRow row) {
    return RoutingFailure(
      code: RoutingFailureCode.undeclaredStrict,
      message:
          'behavior "${row.behaviorId}" has no routing declaration (strict '
          'mode): no `**Type**` marker, no contract-row trace, no test-list '
          'kind declaration.\n'
          '   --> fix: add `**Type**: unit` (or widget/ffi/...) to the '
          'scenario, or trace it to a declared contract row.',
    );
  }

  /// Match a trace token to a declared row: exact name, or
  /// `<row>.<method>` prefix form.
  _RowRef? _resolveToken(String token, Map<String, ContractRowDecl> rows) {
    final exact = rows[token];
    if (exact != null) return _RowRef(exact);
    final dot = token.indexOf('.');
    if (dot > 0) {
      final prefix = token.substring(0, dot);
      final prefixRow = rows[prefix];
      if (prefixRow != null) {
        return _RowRef(prefixRow, method: token.substring(dot + 1));
      }
    }
    return null;
  }

  Signature? _signatureFor(ContractRowDecl row, List<String> traces) {
    final all = [
      ...row.signatures,
      ...row.rawSignatures.map((raw) {
        try {
          return Signature.parse(raw);
        } on FormatException {
          return null;
        }
      }).whereType<Signature>(),
    ];
    if (all.isEmpty) return null;
    for (final token in traces) {
      final dot = token.indexOf('.');
      if (dot > 0 && token.substring(0, dot) == row.name) {
        final wanted = token.substring(dot + 1);
        for (final s in all) {
          if (s.name == wanted) return s;
        }
      }
    }
    return all.first;
  }
}

class _RowRef {
  final ContractRowDecl row;
  final String? method;
  const _RowRef(this.row, {this.method});
}

class _KindSource {
  final BehaviorKind kind;
  final String detail;
  final int? specLine;
  const _KindSource(this.kind, this.detail, [this.specLine]);
}
