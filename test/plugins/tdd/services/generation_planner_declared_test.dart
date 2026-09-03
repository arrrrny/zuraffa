// A2 (feature 071): generation surfaces come from declared contract
// rows. The planner consults the RoutingResolver when declarations are
// supplied: an entity row plans the entity pipeline with the DECLARED
// entity name, a function row plans the plain-function surface even
// when the prose would have baited the entity branch (the #920/#696
// class), a presentation row plans the view lane, and an UNDECLARED
// summary keeps the exact legacy description-keyed routing (fallback
// window, SC-005). Issue #951; spec FR-004/FR-005/FR-007.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

BehaviorSummary summary({
  String id = 'U2',
  String description = 'returns the computed total',
  List<String> traces = const [],
  SpecDeclarations? declarations,
}) => BehaviorSummary(
  behaviorId: id,
  feature: '071-probe',
  sourceCriterion: 'FR-004',
  description: description,
  traces: traces,
  declarations: declarations,
);

void main() {
  const planner = GenerationPlanner();

  group('A2: declared contract rows decide the generation surface', () {
    test('an entity row plans the entity pipeline with the declared name',
        () {
      final plan = planner.plan(
        summary(
          traces: ['Product'],
          declarations: SpecDeclarations(
            contractRows: {
              'Product': ContractRowDecl(
                name: 'Product',
                kind: ContractRowKind.entity,
                specLine: 20,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'Product']);
      expect(
        plan.steps.map((s) => s.args.first),
        containsAll(['entity', 'build']),
      );
    });

    test('a function row beats entity-bait prose: the plan is tdd func, '
        'not zfa make', () {
      final plan = planner.plan(
        summary(
          // prose deliberately baits the legacy entity branch
          description: 'create entity Invoice with email and totals',
          traces: ['Formatter.format'],
          declarations: SpecDeclarations(
            contractRows: {
              'Formatter': ContractRowDecl(
                name: 'Formatter',
                kind: ContractRowKind.function,
                signatures: [Signature.parse('format(Template) -> String')],
                specLine: 30,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isTrue);
      final args = plan.steps.map((s) => s.args).toList();
      expect(args.first, containsAll(['tdd', 'func']));
      expect(
        args.map((a) => a.first),
        isNot(contains('entity')),
        reason: 'the declared function surface outranks prose',
      );
    });

    test('a presentation row plans the view lane (unexpressible to the '
        'primary planner, routed by the make fallback)', () {
      final plan = planner.plan(
        summary(
          id: 'A1',
          traces: ['Login page'],
          declarations: SpecDeclarations(
            contractRows: {
              'Login page': ContractRowDecl(
                name: 'Login page',
                kind: ContractRowKind.presentation,
                specLine: 40,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.unexpressibleReason, contains('view'));
    });

    test('an undeclared summary keeps the legacy description-keyed '
        'routing (fallback window)', () {
      final plan = planner.plan(
        summary(
          id: 'B-7',
          description: 'create entity Invoice with email',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(
        plan.steps.first.args,
        ['entity', 'create', '-n', 'Invoice'],
      );
    });

    test('a declared conflict surfaces as an honest unexpressible plan '
        'carrying the resolver refusal', () {
      final plan = planner.plan(
        summary(
          id: 'A9',
          traces: ['Product'],
          declarations: SpecDeclarations(
            scenarios: {
              'A9': ScenarioDeclaration(
                behaviorId: 'A9',
                declaredType: BehaviorKind.widget,
                specLine: 12,
              ),
            },
            contractRows: {
              'Product': ContractRowDecl(
                name: 'Product',
                kind: ContractRowKind.entity,
                specLine: 20,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.unexpressibleReason, contains('conflict'));
    });
  });
}
