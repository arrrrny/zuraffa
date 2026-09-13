// Bug #1498 — a Domain/Data Layer Contract row resolves
// `surface: entityPipeline` but never yields `entityName`, so the plan
// builder discarded the computed surface (`if (name == null) return
// null`) and every entity-returning domain behavior fell through to the
// legacy `tdd func` lane — `Object? subject` + vacuous guard, stopped at
// the hand seam (#1489's symptom). 16 of 21 unit behaviors in
// 001-todo-app are entityPipeline by declaration and NONE of them
// reached the entity→mock→wire engine.
//
// Remediation pinned here (routing_resolver.dart + generation_planner.dart
// ONLY — the state machine, gen, wire and loop semantics are untouched):
//   1. The resolver mines the domain/data row's OWN declared return
//      type (issue #920: declaration outranks inference) — unwrap
//      `Future<T>` / `List<T>` / `Set<T>` / `Iterable<T>` (repeatedly,
//      nullability tolerated) and the remaining non-scalar declared
//      identifier IS the declared entity. Never prose, never
//      Key-Entities-only.
//   2. When the spec declares Key Entities rows, the mined name must
//      name one of them — a dangling entity return refuses
//      (errors-are-an-API), naming the row and the fix.
//   3. The surface is recorded in routing provenance
//      (`surface: entityPipeline`); the refusal carries
//      `surface: entityPipeline (dropped: no entity name)`.
//   4. The plan builder refuses (honest unexpressible plan with a
//      `--> fix:` hint) when entityPipeline is computed but entityName
//      is underivable — never a silent fall-through into the legacy
//      keyword branches.
//   5. A renderable-scalar declared return (`bool`, `String`, …) is a
//      plain-function contract by declaration: no entity is mined, no
//      refusal fires, the legacy func lane keeps serving it (the issue
//      #1310 lineage — U5/U6 pin the certified declared-scalar path).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';
import 'package:zuraffa/src/plugins/tdd/services/routing_resolver.dart';

RoutingRow row(String id, {List<String> traces = const []}) =>
    RoutingRow(behaviorId: id, kind: BehaviorKind.unit, traces: traces);

/// The 001-todo-app shape: a Domain-layer store whose `create` returns
/// the declared entity, with the entity declared in Key Entities.
SpecDeclarations todoDecls({List<Signature> storeSignatures = const []}) =>
    SpecDeclarations(
      contractRows: {
        'Task': const ContractRowDecl(
          name: 'Task',
          kind: ContractRowKind.entity,
          specLine: 12,
        ),
        'TaskStore': ContractRowDecl(
          name: 'TaskStore',
          kind: ContractRowKind.domain,
          signatures: storeSignatures,
          specLine: 20,
        ),
      },
    );

BehaviorSummary summary({
  String id = 'U2',
  List<String> traces = const ['TaskStore.create'],
  SpecDeclarations? declarations,
}) => BehaviorSummary(
  behaviorId: id,
  feature: '001-todo-app',
  sourceCriterion: 'FR-001',
  description: 'the system MUST create a task by supplying a title',
  traces: traces,
  declarations: declarations,
);

void main() {
  const resolver = RoutingResolver();
  const planner = GenerationPlanner();

  group('U-1498: the domain row’s declared return type names the entity', () {
    test('U-1498a: create(String title) -> Task resolves entityName "Task" '
        '(not null) with the entityPipeline surface', () {
      final result = resolver.resolve(
        row: row('U2', traces: const ['TaskStore.create']),
        declarations: todoDecls(
          storeSignatures: [Signature.parse('create(String title) -> Task')],
        ),
      );
      final d = result as RoutingDecision;
      expect(d.surface, GenerationSurface.entityPipeline);
      expect(
        d.entityName,
        'Task',
        reason:
            'the declared return type IS the entity declaration '
            '(issue #920) — the #1498 gap left it null',
      );
      expect(d.signature?.name, 'create');
    });

    test('U-1498b: the plan builder serves the declared entityPipeline '
        'plan — entity create → mock create (certify) → tdd wire → build', () {
      final plan = planner.plan(
        summary(
          declarations: todoDecls(
            storeSignatures: [Signature.parse('create(String title) -> Task')],
          ),
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(
        plan.steps.map((s) => s.args),
        containsAll([
          containsAll(['entity', 'create', '-n', 'Task']),
          containsAll(['mock', 'create', '--name', 'Task']),
          containsAll(['tdd', 'wire', 'U2', '--entity', 'Task']),
          containsAll(['build']),
        ]),
        reason:
            'the full entity→mock→wire engine, never the legacy '
            'tdd func fall-through',
      );
      expect(
        plan.steps.map((s) => s.args),
        isNot(contains(containsAll(['tdd', 'func', 'U2']))),
        reason:
            'no func step: the declared surface is the entity pipeline '
            '(the `tdd` first-arg is the wire step — allowed; '
            '`tdd func` is the #1498 fall-through — forbidden)',
      );
    });

    test('U-1498c: the surface is recorded in routing provenance '
        '(surface: entityPipeline in the route line)', () {
      final result = resolver.resolve(
        row: row('U2', traces: const ['TaskStore.create']),
        declarations: todoDecls(
          storeSignatures: [Signature.parse('create(String title) -> Task')],
        ),
      );
      final d = result as RoutingDecision;
      expect(
        d.provenance
            .where((p) => p.aspect == RoutingAspect.surface)
            .map((p) => p.detail)
            .join(' '),
        contains('surface: entityPipeline'),
        reason:
            'the route line must name the computed surface (#1498: '
            'the surface was computed and then silently dropped)',
      );
    });

    test('U-1498d: the unwrap matrix — Future/List/Set/Iterable (nested, '
        'nullable) all mine Task', () {
      for (final returnType in const [
        'Task',
        'Future<Task>',
        'List<Task>',
        'Set<Task>',
        'Iterable<Task>',
        'Future<List<Task>>',
        'List<Task>?',
        'Task?',
        'Future<List<Task>?>',
      ]) {
        final result = resolver.resolve(
          row: row('U2', traces: const ['TaskStore.create']),
          declarations: todoDecls(
            storeSignatures: [
              Signature.parse('create(String title) -> $returnType'),
            ],
          ),
        );
        expect(
          (result as RoutingDecision).entityName,
          'Task',
          reason: 'return type `$returnType` must mine the declared entity',
        );
      }
    });

    test('U-1498e: a DATA row mines the entity the same way '
        '(data rows share the entityPipeline surface)', () {
      final result = resolver.resolve(
        row: row('U3', traces: const ['CacheDao.fetch']),
        declarations: SpecDeclarations(
          contractRows: {
            'Task': const ContractRowDecl(
              name: 'Task',
              kind: ContractRowKind.entity,
              specLine: 12,
            ),
            'CacheDao': ContractRowDecl(
              name: 'CacheDao',
              kind: ContractRowKind.data,
              signatures: [Signature.parse('fetch(String key) -> Task')],
              specLine: 22,
            ),
          },
        ),
      );
      final d = result as RoutingDecision;
      expect(d.surface, GenerationSurface.entityPipeline);
      expect(d.entityName, 'Task');
    });

    test('U-1498f: the mined entity is DECLARED provenance naming the '
        'return type — never fallback, never prose', () {
      final result = resolver.resolve(
        row: row('U2', traces: const ['TaskStore.create']),
        declarations: todoDecls(
          storeSignatures: [Signature.parse('create(String title) -> Task')],
        ),
      );
      final d = result as RoutingDecision;
      final entityLines = d.provenance
          .where((p) => p.aspect == RoutingAspect.entity)
          .toList();
      expect(entityLines, hasLength(1));
      expect(entityLines.single.source, RoutingSource.declared);
      expect(
        entityLines.single.detail,
        contains('create(String title) -> Task'),
      );
      expect(entityLines.single.detail, contains('Task'));
    });

    test('U-1498g: an entity-shaped return the spec’s Key Entities do '
        'not declare is a refusal — surface: entityPipeline (dropped: no '
        'entity name) — never a silent decision', () {
      final result = resolver.resolve(
        row: row('U2', traces: const ['InvoiceStore.create']),
        declarations: SpecDeclarations(
          contractRows: {
            // The spec declares Key Entities — and Invoice is not among
            // them: the row's entity-shaped return dangles.
            'User': const ContractRowDecl(
              name: 'User',
              kind: ContractRowKind.entity,
              specLine: 12,
            ),
            'InvoiceStore': ContractRowDecl(
              name: 'InvoiceStore',
              kind: ContractRowKind.domain,
              signatures: [Signature.parse('create(String title) -> Invoice')],
              specLine: 20,
            ),
          },
        ),
      );
      expect(result, isA<RoutingFailure>());
      final f = result as RoutingFailure;
      expect(f.message, contains('surface: entityPipeline'));
      expect(f.message, contains('dropped: no entity name'));
      expect(f.message, contains('InvoiceStore'));
      expect(f.message, contains('--> fix:'));
    });

    test('U-1498h: the plan builder refuses (never falls through) when '
        'entityPipeline is computed but entityName is underivable and '
        'the declared return is not a renderable scalar', () {
      // Result<…> is neither an unwrappable entity container nor a
      // renderable scalar: the computed entityPipeline surface cannot
      // be served, and the honest answer is the refusal — not the
      // legacy func lane that manufactured the #1489 vacuous greens.
      final plan = planner.plan(
        summary(
          id: 'U9',
          traces: const ['DealRepository.list'],
          declarations: SpecDeclarations(
            contractRows: {
              'DealRepository': ContractRowDecl(
                name: 'DealRepository',
                kind: ContractRowKind.domain,
                signatures: [
                  Signature.parse(
                    'list() -> Future<Result<List<Deal>, AppFailure>>',
                  ),
                ],
                specLine: 20,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.unexpressibleReason, contains('surface: entityPipeline'));
      expect(plan.unexpressibleReason, contains('dropped: no entity name'));
      expect(plan.unexpressibleReason, contains('--> fix:'));
      expect(
        plan.steps,
        isEmpty,
        reason:
            'a refusal carries no steps — the legacy func lane must '
            'not engage behind the declared surface',
      );
    });

    test('U-1498i: a declared scalar contract keeps its lane — no entity '
        'mined, no refusal, the legacy func plan still serves it '
        '(issue #1310 U5/U6 lineage)', () {
      final result = resolver.resolve(
        row: row('U1', traces: const ['TodoRepository.create']),
        declarations: SpecDeclarations(
          contractRows: {
            'TodoRepository': ContractRowDecl(
              name: 'TodoRepository',
              kind: ContractRowKind.domain,
              signatures: [Signature.parse('create(String title) -> bool')],
              specLine: 20,
            ),
          },
        ),
      );
      final d = result as RoutingDecision;
      expect(d.entityName, isNull, reason: 'bool is not an entity');
      expect(d.signature?.returnType, 'bool');
      final plan = planner.plan(
        summary(
          id: 'U1',
          traces: const ['TodoRepository.create'],
          declarations: SpecDeclarations(
            contractRows: {
              'TodoRepository': ContractRowDecl(
                name: 'TodoRepository',
                kind: ContractRowKind.domain,
                signatures: [Signature.parse('create(String title) -> bool')],
                specLine: 20,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(
        plan.steps.map((s) => s.args.first),
        contains('tdd'),
        reason:
            'the declared scalar contract IS a plain function — the '
            'func lane keeps serving it (pinned by #1310 U5/U6)',
      );
    });
  });
}
