// U1 (feature 071): the RoutingResolver ladder — the single owner of
// declaration-based routing. Pins precedence (marker > contract row >
// test-list kind > labeled fallback), per-aspect resolution (kind,
// surface, entity, signature, persistence), typed refusals that name
// spec lines (conflict, dangling, malformed, strict-undeclared), and
// determinism. Issue #951; spec specs/071-declared-intent-routing.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/routing_resolver.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

RoutingRow row(
  String id, {
  BehaviorKind? kind,
  List<String> traces = const [],
}) => RoutingRow(behaviorId: id, kind: kind, traces: traces);

SpecDeclarations decls({
  Map<String, ScenarioDeclaration> scenarios = const {},
  Map<String, ContractRowDecl> contractRows = const {},
  Map<String, PersistenceDeclaration> persistence = const {},
}) => SpecDeclarations(
  scenarios: scenarios,
  contractRows: contractRows,
  persistence: persistence,
);

ScenarioDeclaration marker(String id, BehaviorKind kind, {int line = 10}) =>
    ScenarioDeclaration(behaviorId: id, declaredType: kind, specLine: line);

ContractRowDecl entityRow(String name, {int line = 20}) =>
    ContractRowDecl(name: name, kind: ContractRowKind.entity, specLine: line);

ContractRowDecl functionRow(
  String name,
  List<String> signatures, {
  int line = 30,
}) => ContractRowDecl(
  name: name,
  kind: ContractRowKind.function,
  signatures: signatures.map(Signature.parse).toList(),
  specLine: line,
);

ContractRowDecl presentationRow(String name, {int line = 40}) =>
    ContractRowDecl(
      name: name,
      kind: ContractRowKind.presentation,
      specLine: line,
    );

ContractRowDecl storageRow(String name, {int line = 50}) =>
    ContractRowDecl(name: name, kind: ContractRowKind.storage, specLine: line);

void main() {
  const resolver = RoutingResolver();

  group('U1: declaration ladder precedence', () {
    test('a contract row decides kind, surface, and entity name', () {
      final result = resolver.resolve(
        row: row('U1', traces: ['Product']),
        declarations: decls(contractRows: {'Product': entityRow('Product')}),
        strict: false,
      );
      expect(result, isA<RoutingDecision>());
      final d = result as RoutingDecision;
      expect(d.kind, BehaviorKind.unit);
      expect(d.surface, GenerationSurface.entityPipeline);
      expect(d.entityName, 'Product');
      expect(
        d.provenance
            .where((p) => p.aspect == RoutingAspect.kind)
            .map((p) => p.source),
        everyElement(RoutingSource.declared),
      );
    });

    test('a function row decides the plain-function surface + signature', () {
      final result = resolver.resolve(
        row: row('U2', traces: ['Formatter.format']),
        declarations: decls(
          contractRows: {
            'Formatter': functionRow('Formatter', [
              'format(Template) -> String',
            ]),
          },
        ),
        strict: false,
      );
      final d = result as RoutingDecision;
      expect(d.surface, GenerationSurface.plainFunction);
      expect(d.signature?.returnType, 'String');
      expect(d.signature?.name, 'format');
    });

    test('a presentation row decides the widget lane + view generation', () {
      final result = resolver.resolve(
        row: row('A1', traces: ['Login page']),
        declarations: decls(
          contractRows: {'Login page': presentationRow('Login page')},
        ),
        strict: false,
      );
      final d = result as RoutingDecision;
      expect(d.kind, BehaviorKind.widget);
      expect(d.surface, GenerationSurface.viewGeneration);
    });

    test('a marker outranks the test-list kind declaration (rung 1 > 3)', () {
      final result = resolver.resolve(
        row: row('U3', kind: BehaviorKind.unit),
        declarations: decls(
          scenarios: {'U3': marker('U3', BehaviorKind.widget)},
        ),
        strict: false,
      );
      final d = result as RoutingDecision;
      expect(d.kind, BehaviorKind.widget);
    });

    test('a test-list kind (section header) is a declared rung-3 kind', () {
      final result = resolver.resolve(
        row: row('U4', kind: BehaviorKind.ffi),
        declarations: decls(),
        strict: false,
      );
      final d = result as RoutingDecision;
      expect(d.kind, BehaviorKind.ffi);
      expect(d.surface, isNull, reason: 'rung 3 declares kind only');
      expect(
        d.provenance.firstWhere((p) => p.aspect == RoutingAspect.kind).source,
        RoutingSource.declared,
      );
    });

    test('a storage row marks persistence without changing the lane', () {
      final result = resolver.resolve(
        row: row('U5', kind: BehaviorKind.unit, traces: ['CartStorage']),
        declarations: decls(
          contractRows: {'CartStorage': storageRow('CartStorage')},
        ),
        strict: false,
      );
      final d = result as RoutingDecision;
      expect(d.persistence, isTrue);
      expect(d.kind, BehaviorKind.unit, reason: 'from the test-list kind');
    });

    test('a [persistent] tag declares persistence', () {
      final result = resolver.resolve(
        row: row('U6', kind: BehaviorKind.unit),
        declarations: decls(
          persistence: {
            'U6': PersistenceDeclaration(behaviorId: 'U6', specLine: 31),
          },
        ),
        strict: false,
      );
      expect((result as RoutingDecision).persistence, isTrue);
    });

    test('no persistence declaration means unmarked (not fallback)', () {
      final result = resolver.resolve(
        row: row('U7', kind: BehaviorKind.unit),
        declarations: decls(),
        strict: false,
      );
      final d = result as RoutingDecision;
      expect(d.persistence, isFalse);
      expect(
        d.provenance.where((p) => p.aspect == RoutingAspect.persistence),
        isEmpty,
        reason: 'absence of a declaration is the declared unmarked state',
      );
    });
  });

  group('U1: typed refusals name spec lines', () {
    test('marker vs contract-row kind conflict names both lines', () {
      final result = resolver.resolve(
        row: row('A9', traces: ['Product']),
        declarations: decls(
          scenarios: {'A9': marker('A9', BehaviorKind.widget, line: 12)},
          contractRows: {'Product': entityRow('Product', line: 20)},
        ),
        strict: false,
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.code, RoutingFailureCode.declarationConflict);
      expect(f.message, contains('12'));
      expect(f.message, contains('20'));
      expect(f.message, contains('--> fix:'));
    });

    test('a method-qualified trace naming an undeclared method refuses '
        '(never falls back to the row\'s first signature)', () {
      final result = resolver.resolve(
        row: row('U14', traces: ['Formatter.summarise']),
        declarations: decls(
          contractRows: {
            'Formatter': functionRow('Formatter', [
              'format(Template) -> String',
            ]),
          },
        ),
        strict: false,
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.code, RoutingFailureCode.danglingReference);
      expect(f.message, contains('summarise'));
      expect(f.message, contains('Formatter'));
      expect(f.message, contains('--> fix:'));
    });

    test('a dangling trace reference is refused, naming the line', () {
      final result = resolver.resolve(
        row: row('U8', kind: BehaviorKind.unit, traces: ['NonexistentRow']),
        declarations: decls(),
        strict: false,
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.code, RoutingFailureCode.danglingReference);
      expect(f.message, contains('NonexistentRow'));
    });

    test('a malformed signature is refused, naming the row', () {
      final result = resolver.resolve(
        row: row('U9', traces: ['Broken']),
        declarations: decls(
          contractRows: {
            'Broken': ContractRowDecl(
              name: 'Broken',
              kind: ContractRowKind.function,
              signatures: const [],
              rawSignatures: const ['format(Template)'],
              specLine: 33,
            ),
          },
        ),
        strict: false,
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.code, RoutingFailureCode.malformedDeclaration);
      expect(f.message, contains('format(Template)'));
      expect(f.message, contains('33'));
    });

    test('strict mode refuses undeclared intent with a fix hint', () {
      final result = resolver.resolve(
        row: row('U10'),
        declarations: decls(),
        strict: true,
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.code, RoutingFailureCode.undeclaredStrict);
      expect(f.message, contains('U10'));
      expect(f.message, contains('--> fix:'));
    });

    test('non-strict undeclared intent opens the labeled fallback lane', () {
      final result = resolver.resolve(
        row: row('U11'),
        declarations: decls(),
        strict: false,
      );
      expect(result, isA<RoutingUndeclared>());
    });

    test('strict mode passes a fully declared behavior', () {
      final result = resolver.resolve(
        row: row('U12', traces: ['Product']),
        declarations: decls(contractRows: {'Product': entityRow('Product')}),
        strict: true,
      );
      expect(result, isA<RoutingDecision>());
    });

    test(
      'a strict acceptance behavior needs no contract-row surface '
      '(round-2 fix 1: acceptance prose is the composition lane, FR-009)',
      () {
        final result = resolver.resolve(
          row: row('A5', kind: BehaviorKind.acceptance),
          declarations: decls(),
          strict: true,
        );
        expect(result, isA<RoutingDecision>(), reason: 'no surface refusal');
        final d = result as RoutingDecision;
        expect(d.kind, BehaviorKind.acceptance);
        expect(d.surface, isNull);
      },
    );

    test('a marker-declared strict acceptance scenario resolves without a '
        'dangling or surface refusal', () {
      final result = resolver.resolve(
        row: row('A6', kind: BehaviorKind.acceptance, traces: []),
        declarations: decls(
          scenarios: {'A6': marker('A6', BehaviorKind.acceptance, line: 55)},
        ),
        strict: true,
      );
      expect(result, isA<RoutingDecision>());
      expect(
        (result as RoutingDecision).provenance
            .where((p) => p.aspect == RoutingAspect.kind)
            .map((p) => p.source),
        everyElement(RoutingSource.declared),
      );
    });

    test('traces to rows of different kinds conflict, naming the rows '
        '(round-2 fix 4)', () {
      final result = resolver.resolve(
        row: row('U15', traces: ['Login page', 'Product']),
        declarations: decls(
          contractRows: {
            'Login page': presentationRow('Login page', line: 40),
            'Product': entityRow('Product', line: 20),
          },
        ),
        strict: false,
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.code, RoutingFailureCode.declarationConflict);
      expect(f.message, contains('Login page'));
      expect(f.message, contains('Product'));
      expect(f.message, contains('--> fix:'));
    });

    test('a backticked inline signature in traces neither resolves nor '
        'dangles — the row reference still routes (round-2 fix 2)', () {
      const spec = '''
- **FR-004**: The checkout totals the cart and returns the payable amount.
            traces: ProductRepository, `format(Template) -> String`
''';
      final tokens = SpecParser.parseFrContractTraces(spec)['U1']!;
      expect(tokens, [
        'ProductRepository',
      ], reason: 'the inline signature is not a row reference');
      final result = resolver.resolve(
        row: row(
          'U1',
          traces: SpecParser.traceTokens(
            'ProductRepository, `format(Template) -> String`',
          ),
        ),
        declarations: decls(
          contractRows: {
            'ProductRepository': functionRow('ProductRepository', [
              'save(Product) -> Future<void>',
            ], line: 21),
          },
        ),
        strict: true,
      );
      expect(
        result,
        isA<RoutingDecision>(),
        reason: 'the signature token is dropped: no dangle, no refusal',
      );
      expect((result as RoutingDecision).signature, isNotNull);
    });
  });

  group('U1: determinism', () {
    test('identical inputs produce identical decisions', () {
      RoutingResult run() => resolver.resolve(
        row: row('U13', traces: ['Formatter.format']),
        declarations: decls(
          contractRows: {
            'Formatter': functionRow('Formatter', [
              'format(Template) -> String',
            ]),
          },
        ),
        strict: false,
      );
      final a = run() as RoutingDecision;
      final b = run() as RoutingDecision;
      expect(a.kind, b.kind);
      expect(a.surface, b.surface);
      expect(a.signature?.returnType, b.signature?.returnType);
      expect(a.provenance.length, b.provenance.length);
    });
  });
}
