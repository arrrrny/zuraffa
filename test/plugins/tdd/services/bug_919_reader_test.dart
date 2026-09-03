// Bug #919 ([TDD-120], tdd-120-template-structures) — A14 reader side:
// the plan artifact's `## External dependencies` and `## Layer contracts`
// sections must read back through TestListReader so the mock-first make
// path (#909) can consume them. The artifact shape is shared with the
// CLI-driven plan test (bug_919_template_structures_test.dart::A14);
// here it is pinned at the reader boundary with fixture artifacts.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bug919_reader_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> seed(String content) async {
    final dir = p.join(tmp.path, 'specs', '091-demo');
    await Directory(p.join(dir, 'tdd')).create(recursive: true);
    await File(p.join(dir, 'tdd', 'test-list.md')).writeAsString(content);
    return dir;
  }

  const artifact = '''
# Test List: 091-demo

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the saved size is shown | AC-1 | PENDING |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| Hive | storage | `read(key) -> ShoeSizePreference?` | P1 |
| SharedPreferences | storage | `getString(k) -> String?` | P2 |

## Layer contracts

### Domain

- `ShoeSizePreferenceRepository`: `save(ShoeSizePreference) -> Future<Result<void, AppFailure>>`, `getByBrand(String brand) -> Future<Result<ShoeSizePreference?, AppFailure>>`
''';

  test('A14: readDependencies() parses every declared dependency row', () async {
    final dir = await seed(artifact);

    final deps = await TestListReader(dir).readDependencies();

    expect(deps, hasLength(2));
    expect(deps[0].dependency, 'Hive');
    expect(deps[0].type, 'storage');
    expect(deps[0].contract, '`read(key) -> ShoeSizePreference?`');
    expect(deps[0].mockPriority, 'P1');
    expect(deps[1].dependency, 'SharedPreferences');
    expect(deps[1].mockPriority, 'P2');
  });

  test(
    'A14: readLayerContracts() parses layers, interfaces and method '
    'signatures',
    () async {
      final dir = await seed(artifact);

      final contracts = await TestListReader(dir).readLayerContracts();

      expect(contracts, hasLength(1));
      expect(contracts.single.layer, 'Domain');
      expect(contracts.single.interfaceName, 'ShoeSizePreferenceRepository');
      expect(contracts.single.methods, [
        'save(ShoeSizePreference) -> Future<Result<void, AppFailure>>',
        'getByBrand(String brand) -> '
            'Future<Result<ShoeSizePreference?, AppFailure>>',
      ]);
    },
  );

  test(
    'A14: a section-less artifact yields empty dependency and contract '
    'lists (every pre-919 artifact)',
    () async {
      final dir = await seed(
        '# Test List: 091-demo\n\n## Outer loop: acceptance behaviors\n',
      );

      expect(await TestListReader(dir).readDependencies(), isEmpty);
      expect(await TestListReader(dir).readLayerContracts(), isEmpty);
    },
  );
}