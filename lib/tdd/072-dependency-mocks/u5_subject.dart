// GENERATED subject — implemented (issue #960 U5 / FR-005).
//
// Routing: a behavior whose trace names a declared service row routes
// to the dependency-mock surface with provenance naming the row; prose
// without a trace never routes there. Exercised through the resolver on
// a declared in-memory spec.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/models/mock_priority.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/routing_resolver.dart';

Object? subject_u5() {
  final declarations = SpecDeclarations(
    contractRows: {
      'FirebaseAuth': ContractRowDecl(
        name: 'FirebaseAuth',
        kind: ContractRowKind.service,
        signatures: [
          Signature(name: 'signIn', parameters: const [], returnType: 'User'),
        ],
        priority: MockPriority.p1,
        specLine: 12,
      ),
    },
    scenarios: {
      'A1': ScenarioDeclaration(
        behaviorId: 'A1',
        contractRefs: const ['FirebaseAuth'],
        specLine: 30,
      ),
    },
  );
  final resolver = const RoutingResolver();
  final result = resolver.resolve(
    declarations: declarations,
    row: RoutingRow(behaviorId: 'A1', traces: const ['FirebaseAuth']),
    strict: false,
  );
  expect(result, isA<RoutingDecision>());
  final success = result as RoutingDecision;
  expect(
    success.surface,
    equals(GenerationSurface.dependencyMake),
    reason: 'the traced service row routes to the dependency-mock surface',
  );
  expect(
    success.provenance.map((p) => p.detail).join(' '),
    contains('FirebaseAuth'),
    reason: 'provenance names the consulted dependency row',
  );

  // Prose without a declaration: a behavior whose wording says
  // "authenticates" but whose trace names nothing must NOT route to
  // the dependency surface.
  final proseOnly = resolver.resolve(
    declarations: SpecDeclarations(
      contractRows: declarations.contractRows,
      scenarios: {'A2': ScenarioDeclaration(behaviorId: 'A2', specLine: 31)},
    ),
    row: RoutingRow(behaviorId: 'A2', traces: const []),
    strict: false,
  );
  // No declaration → either an explicit refusal or a non-dependency
  // fallback: NEVER a dependency-mock route (no prose sniffing).
  if (proseOnly is RoutingDecision) {
    expect(proseOnly.surface, isNot(equals(GenerationSurface.dependencyMake)));
  } else {
    // Non-strict undeclared intent yields the named RoutingUndeclared
    // result — still never a dependency-mock route by prose.
    expect(
      proseOnly,
      anyOf(isA<RoutingFailure>(), isA<RoutingUndeclared>()),
      reason: 'undeclared intent refuses; it never routes by prose',
    );
  }
  return null;
}
