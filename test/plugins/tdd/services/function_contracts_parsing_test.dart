// U3 (feature 071): the `**Function**` Layer Contracts bullet parses
// into function-kind contract rows with declared signatures; a
// malformed signature (missing the `-> Return`) is refused naming the
// row; domain/data bullets keep parsing verbatim (#919 grammar
// unchanged). Issue #951; contracts/template-declarations.md §3.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const _spec = '''
### Layer Contracts

**Domain**:
- `ProductRepository`: `save(Product) -> Future<Result<void, AppFailure>>`

**Function**:
- `Formatter`: `format(Template) -> String`, `formatSummary(List<OrderLine>) -> String`

**Presentation**:
- `Login page`: renders the declared form components
''';

const _malformed = '''
### Layer Contracts

**Function**:
- `Broken`: `format(Template)`
''';

void main() {
  test('a Function bullet parses into function-kind rows with signatures',
      () {
    final rows = const SpecParser().parseContractRows(_spec);
    final formatter = rows.where((r) => r.name == 'Formatter').toList();
    expect(formatter, hasLength(1));
    expect(formatter.single.kind, ContractRowKind.function);
    expect(formatter.single.signatures, hasLength(2));
    expect(formatter.single.signatures.first.name, 'format');
    expect(formatter.single.signatures.first.parameters, ['Template']);
    expect(formatter.single.signatures.first.returnType, 'String');
    expect(formatter.single.signatures.last.returnType, 'String');
    expect(formatter.single.specLine, isNotNull,
        reason: 'rows are line-addressable');
  });

  test('a malformed function signature is refused, naming the row', () {
    expect(
      () => const SpecParser().parseContractRows(_malformed),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('Broken'), contains('format(Template)')),
        ),
      ),
    );
  });

  test('domain rows keep parsing verbatim alongside function rows', () {
    final rows = const SpecParser().parseContractRows(_spec);
    final repo = rows.where((r) => r.name == 'ProductRepository').toList();
    expect(repo, hasLength(1));
    expect(repo.single.kind, ContractRowKind.domain);
    expect(
      repo.single.signatures.single.returnType,
      'Future<Result<void, AppFailure>>',
    );
  });

  test('presentation rows parse with the presentation kind', () {
    final rows = const SpecParser().parseContractRows(_spec);
    expect(
      rows.where((r) => r.name == 'Login page').single.kind,
      ContractRowKind.presentation,
    );
  });
}
