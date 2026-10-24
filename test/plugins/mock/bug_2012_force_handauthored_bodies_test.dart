// Issue #2012: `zfa mock create --force` replaces hand-authored
// `<Entity>MockDataSource` bodies with no-op template stubs whenever the
// declared member set matches the run's `--methods` — the #1952 refusal
// only arms on member LOSS, so a matching seam sails through and
// `--certify` grades the rewritten contract green (structure only) while
// every behavioral pin that depends on the replaced bodies goes red.
//
// Contract pinned here: a force run whose fresh emission would replace the
// body of an EXISTING same-shape member with the generated stub is REFUSED
// before the first write — naming the mock file and the hand-authored
// members — unless `--overwrite-bodies` opts in. An unmodified GENERATED
// mock (its bodies are byte-equivalent to the fresh stubs) keeps the #1418
// idempotent regeneration; a member whose type shape genuinely changed is
// a requested shape change, not a silent body replacement, and stays
// force-refreshable.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';

// Issue #1747: the CRUD surface `zfa mock create` requires before it emits
// the datasource/provider pair — declared inline.
const _entityFileContent = '''
class Deal {
  final String id;
  const Deal(this.id);

  Deal copyWithField(Object field, Object? value) => this;
}

class DealPatch {}
''';

// The interface whose declared member set EXACTLY matches the run's
// `--methods` (the #2012 shape: `get` from the CRUD vocabulary plus the
// custom `remove:String->void` verb #1956 unblocked). No member is lost,
// so the #1952 refusal correctly does not arm.
const _matchingInterface = '''
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/deal/deal.dart';

abstract class DealDataSource with Loggable, FailureHandler {
  Future<Deal> get(QueryParams<Deal> params);
  Future<void> remove(String id);
}
''';

// The hand-authored mock the issue reproduces: `remove` actually mutates a
// store (`_saved.removeWhere`, idempotent) — semantics the feature's
// behavior tests pin and no generated stub can reproduce.
const _handAuthoredMock = '''
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/deal/deal.dart';
import 'deal_datasource.dart';

class DealMockDataSource
    with Loggable, FailureHandler
    implements DealDataSource {
  final List<Deal> _saved = <Deal>[];

  @override
  Future<Deal> get(QueryParams<Deal> params) async {
    logger.info('get called');
    return _saved.first;
  }

  @override
  Future<void> remove(String id) async {
    logger.info('remove -> \$id');
    _saved.removeWhere((d) => d.id == id);
  }
}
''';

GeneratorConfig _config({
  required String outputDir,
  bool force = false,
  List<String> methods = const ['get', 'remove:String->void'],
  bool overwriteBodies = false,
}) {
  return GeneratorConfig(
    name: 'Deal',
    outputDir: outputDir,
    methods: methods,
    generateMock: true,
    generateDataSource: false,
    force: force,
    overwriteBodies: overwriteBodies,
  );
}

MockBuilder _builder(String outputDir, {bool force = false}) => MockBuilder(
  outputDir: outputDir,
  options: GeneratorOptions(dryRun: false, force: force, verbose: false),
);

/// Seeds the entity, the matching declared interface, and (optionally) the
/// hand-authored mock; returns the mock path.
Future<String> _seedTree(
  String outputDir, {
  String mockContent = _handAuthoredMock,
}) async {
  final entityDir = Directory('$outputDir/domain/entities/deal');
  await entityDir.create(recursive: true);
  await File('${entityDir.path}/deal.dart').writeAsString(_entityFileContent);

  final dsDir = Directory('$outputDir/data/datasources/deal');
  await dsDir.create(recursive: true);
  await File(
    '${dsDir.path}/deal_datasource.dart',
  ).writeAsString(_matchingInterface);
  final mockPath = '${dsDir.path}/deal_mock_datasource.dart';
  await File(mockPath).writeAsString(mockContent);
  return mockPath;
}

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_2012_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('A1 — force refuses a hand-authored mock body (issue #2012)', () {
    test(
      'the run throws, naming the mock file and the replaced member',
      () async {
        await _seedTree(outputDir);

        await expectLater(
          _builder(
            outputDir,
            force: true,
          ).generate(_config(outputDir: outputDir, force: true)),
          throwsA(
            isA<StateError>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('deal_mock_datasource.dart'),
                )
                .having((e) => e.message, 'message', contains('remove')),
          ),
        );
      },
    );

    test('the refused run leaves the tree byte-identical', () async {
      final mockPath = await _seedTree(outputDir);
      final interfacePath =
          '$outputDir/data/datasources/deal/deal_datasource.dart';
      final mockBefore = await File(mockPath).readAsString();
      final interfaceBefore = await File(interfacePath).readAsString();

      try {
        await _builder(
          outputDir,
          force: true,
        ).generate(_config(outputDir: outputDir, force: true));
      } catch (_) {
        // The refusal is asserted in A1; here only the tree matters.
      }

      expect(
        await File(mockPath).readAsString(),
        mockBefore,
        reason: 'the refused run must not rewrite the hand-authored mock',
      );
      expect(
        await File(interfacePath).readAsString(),
        interfaceBefore,
        reason: 'the refused run must not rewrite the declared interface',
      );
      expect(
        File('$outputDir/data/mock/deal_mock_data.dart').existsSync(),
        isFalse,
        reason: 'no fixture is written by a refused run',
      );
    });
  });

  group('B1 — an unmodified generated mock keeps regenerating', () {
    test(
      'a second force run over the generator\'s own output does not refuse',
      () async {
        final freshDir = Directory('${tempDir.path}/fresh/lib/src')
          ..createSync(recursive: true);
        final entityDir = Directory('${freshDir.path}/domain/entities/deal');
        entityDir.createSync(recursive: true);
        await File(
          '${entityDir.path}/deal.dart',
        ).writeAsString(_entityFileContent);
        final dsDir = Directory('${freshDir.path}/data/datasources/deal');
        dsDir.createSync(recursive: true);
        await File(
          '${dsDir.path}/deal_datasource.dart',
        ).writeAsString(_matchingInterface);

        final builder = _builder(freshDir.path, force: true);
        final config = _config(outputDir: freshDir.path, force: true);

        await builder.generate(config);
        final mockPath = '${dsDir.path}/deal_mock_datasource.dart';
        final run1 = await File(mockPath).readAsString();

        await builder.generate(config);
        expect(
          await File(mockPath).readAsString(),
          run1,
          reason:
              'the second force run over a generated mock loses nothing, '
              'is not refused, and stays byte-stable',
        );
      },
    );
  });

  group('C1 — --overwrite-bodies opts in to the destructive run', () {
    test('the bodies are replaced with the generated stubs', () async {
      final mockPath = await _seedTree(outputDir);

      final files = await _builder(outputDir, force: true).generate(
        _config(outputDir: outputDir, force: true, overwriteBodies: true),
      );

      final after = File(mockPath).readAsStringSync();
      expect(
        after,
        isNot(contains('_saved.removeWhere')),
        reason: 'the opt-in run discards the hand-authored body',
      );
      expect(
        after,
        contains('remove('),
        reason: 'the member set survives the opt-in regeneration',
      );
      expect(
        files.map((f) => f.path),
        contains(endsWith('deal_mock_datasource.dart')),
      );
    });
  });

  group('D — a shape migration runs loudly, not silently', () {
    test('a member whose shape the run migrates is refused until opted in, '
        'then regenerated from the fresh template', () async {
      // The interface still carries the OLD `remove(String id)` shape;
      // the run's `--methods` migrate the verb to
      // `remove:QueryParams<Deal>->void`. The pre-flight resolves the
      // fresh emission against the on-disk interface (the same read the
      // #1952 guard makes), so this run is a behavior-bearing member
      // replacement it cannot prove shape-only: refuse, with the same
      // explicit opt-in contract as #1952.
      final mockPath = await _seedTree(outputDir);

      await expectLater(
        _builder(outputDir, force: true).generate(
          _config(
            outputDir: outputDir,
            force: true,
            methods: const ['get', 'remove:QueryParams<Deal>->void'],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('remove'),
          ),
        ),
      );
      expect(
        File(mockPath).readAsStringSync(),
        contains('_saved.removeWhere'),
        reason: 'the refused run leaves the hand-authored body in place',
      );

      // The opt-in carries the migration: the member is regenerated from
      // the fresh template.
      final files = await _builder(outputDir, force: true).generate(
        _config(
          outputDir: outputDir,
          force: true,
          methods: const ['get', 'remove:QueryParams<Deal>->void'],
          overwriteBodies: true,
        ),
      );

      final after = File(mockPath).readAsStringSync();
      expect(
        after,
        isNot(contains('_saved.removeWhere')),
        reason: 'the opt-in run discards the old-shape body',
      );
      expect(
        after,
        contains('remove('),
        reason: 'the member set survives the opt-in regeneration',
      );
      expect(
        files.map((f) => f.path),
        contains(endsWith('deal_mock_datasource.dart')),
      );
    });
  });

  group('E — overwriteBodies round-trips through JSON', () {
    test('toJson emits the key and fromJson reads it back', () {
      final on = _config(outputDir: outputDir, overwriteBodies: true);
      expect(on.toJson()['overwrite_bodies'], isTrue);
      expect(
        GeneratorConfig.fromJson({
          'overwrite_bodies': true,
        }, 'Deal').overwriteBodies,
        isTrue,
        reason:
            'a JSON replay of an --overwrite-bodies run '
            'must keep the opt-in',
      );

      expect(
        GeneratorConfig.fromJson({
          'overwrite_bodies': false,
        }, 'Deal').overwriteBodies,
        isFalse,
      );
      // Workaround (arrrrny/zuraffa#1962): the assertions above test the two
      // directions separately instead of a full `fromJson(toJson())`
      // round-trip — that round-trip crashes today on the pre-existing
      // bool-vs-String? overload of the presenter/controller keys, unrelated
      // to `overwrite_bodies`. When #1962 lands, tighten this to the full
      // round-trip.
    });
  });
}
