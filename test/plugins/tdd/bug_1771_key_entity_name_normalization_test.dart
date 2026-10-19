// Bug #1771 — a data/domain row returning Future<DealListPage> is refused
// as 'no declared Key Entities row' while the same run extracts DealListPage
// as a Key Entity. The declared entity row's stored name must match the
// name mined from the declared return type.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/routing_resolver.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

RoutingRow row(String id, {List<String> traces = const []}) =>
    RoutingRow(behaviorId: id, kind: BehaviorKind.unit, traces: traces);

void main() {
  const resolver = RoutingResolver();

  test(
    'U-1771a: a backticked Key Entities row name matches the mined entity',
    () {
      // Simulates the pre-fix parser output where the entity row name
      // retained backticks while the miner produced a bare identifier.
      final result = resolver.resolve(
        row: row('U3', traces: const ['DealDataSource.getDeals']),
        declarations: SpecDeclarations(
          contractRows: {
            '`DealListPage`': const ContractRowDecl(
              name: '`DealListPage`',
              kind: ContractRowKind.entity,
              specLine: 12,
            ),
            'DealDataSource': ContractRowDecl(
              name: 'DealDataSource',
              kind: ContractRowKind.domain,
              signatures: [
                Signature.parse(
                  'getDeals(limit, offset) -> Future<DealListPage>',
                ),
              ],
              specLine: 20,
            ),
          },
        ),
      );
      expect(result, isA<RoutingDecision>());
      final d = result as RoutingDecision;
      expect(d.surface, GenerationSurface.entityPipeline);
      expect(d.entityName, 'DealListPage');
    },
  );

  test(
    'U-1771b: spec parser normalizes a backticked multi-word entity name',
    () {
      const spec = '''
### Key Entities

| Entity | Fields |
| -- | -- |
| `DealListPage` | deals: List<Deal>, hasMore: bool |

## Layer Contracts

**Domain**:
- `DealDataSource`: `getDeals(limit, offset) -> Future<DealListPage>`
''';
      final rows = const SpecParser().parseContractRows(spec);
      final entityRows = rows
          .where((r) => r.kind == ContractRowKind.entity)
          .toList();
      expect(entityRows, hasLength(1));
      expect(entityRows.single.name, 'DealListPage');
      final ents = const SpecParser().parseKeyEntities(spec);
      expect(ents.map((e) => e.name), contains('DealListPage'));
    },
  );
}
