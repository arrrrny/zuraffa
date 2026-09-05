// Spec 976 (issue #976) — byte-identity snapshot gate for the state
// builder.
//
// The dedupe order collapses the 6 duplicated
// needsEntityField/needsEntityListField derivation sites into ONE
// resolver; the hard constraint is provable behavior-neutrality —
// output bytes identical before/after on a fixture matrix. This suite
// pins the fixture matrix (six configs × two target flavors) against
// committed goldens under golden/:
//
//   * goldens are captured from the PRE-dedupe builder
//     (ZFA_STATE_UPDATE_GOLDENS=1 regenerates them — run it ONLY on
//     the pre-change baseline when adding fixtures);
//   * after the dedupe, every regenerated file must still be
//     byte-identical to its golden (SC-3, AC-3).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/state/builders/state_builder.dart';

/// One fixture-matrix slot. [config] fixes the derivation inputs; the
/// label names the golden file.
final _fixtures = <(String, GeneratorConfig Function(String outputDir))>[
  (
    'crud-entity',
    (out) => GeneratorConfig(
      name: 'Product',
      methods: ['get', 'create', 'update', 'delete'],
      generateState: true,
      outputDir: out,
    ),
  ),
  (
    'pagination',
    (out) => GeneratorConfig(
      name: 'Order',
      methods: ['get', 'getList'],
      generateState: true,
      outputDir: out,
    ),
  ),
  (
    'watch-list',
    (out) => GeneratorConfig(
      name: 'Task',
      methods: ['watchList', 'watch'],
      generateState: true,
      outputDir: out,
    ),
  ),
  (
    'orchestrator',
    (out) => GeneratorConfig(
      name: 'Shipment',
      usecases: ['GetShipmentUseCase', 'SyncShipmentUseCase'],
      generateState: true,
      outputDir: out,
    ),
  ),
  (
    'custom-usecase',
    (out) => GeneratorConfig(
      name: 'GetListingByBarcode',
      domain: 'listing',
      paramsType: 'String',
      returnsType: 'Listing?',
      generateState: true,
      outputDir: out,
    ),
  ),
  (
    'no-entity',
    (out) => GeneratorConfig(
      name: 'Session',
      noEntity: true,
      methods: [],
      generateState: true,
      outputDir: out,
    ),
  ),
];

/// The two target-project flavors the state import follows (#512): a
/// pubspec without `flutter:` imports zuraffa core (pureDart); no
/// pubspec at all (unknown) keeps the historical zuraffa_flutter
/// import.
const _flavors = <String, bool>{'flutter': false, 'pure-dart': true};

void main() {
  late Directory base;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('zfa_state_snap_');
  });

  tearDown(() async {
    if (base.existsSync()) {
      try {
        await base.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  test('SC-3: the fixture matrix is byte-identical to the committed goldens '
      '(${_fixtures.length} configs x ${_flavors.length} flavors)', () async {
    final update = Platform.environment['ZFA_STATE_UPDATE_GOLDENS'] == '1';
    final goldenDir = Directory(
      p.join(Directory.current.path, 'test', 'plugins', 'state', 'golden'),
    );
    if (update) {
      await goldenDir.create(recursive: true);
    }
    expect(
      goldenDir.existsSync(),
      isTrue,
      reason:
          'goldens must be committed with the pre-dedupe baseline; '
          'regenerate ONLY on the pre-change builder with '
          'ZFA_STATE_UPDATE_GOLDENS=1',
    );
    final generated = <String, List<int>>{};

    for (final flavor in _flavors.entries) {
      // One sandbox per flavor: pure-dart carries a pubspec.yaml so
      // detectProjectFlavor resolves core imports; flutter stays
      // pubspec-less (unknown flavor keeps the flutter import).
      final flavorRoot = Directory(p.join(base.path, flavor.key));
      await flavorRoot.create(recursive: true);
      if (flavor.value) {
        await File(p.join(flavorRoot.path, 'pubspec.yaml')).writeAsString('''
name: snap_${flavor.key.replaceAll('-', '_')}
publish_to: none
environment:
  sdk: ^3.11.0
''');
      }

      for (final fixture in _fixtures) {
        final (label, buildConfig) = fixture;
        final outputDir = p.join(flavorRoot.path, label, 'lib', 'src');
        await Directory(outputDir).create(recursive: true);

        final builder = StateBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final file = await builder.generate(buildConfig(outputDir));
        final bytes = File(file.path).readAsBytesSync();
        generated['${flavor.key}-$label'] = bytes;

        // `.dart.txt` — the golden is a byte snapshot, not a
        // compilable unit; a bare `.dart` extension would make
        // `dart analyze lib test` (the CI scope) try to resolve the
        // generated imports against the test tree.
        final goldenFile = File(
          p.join(goldenDir.path, '${flavor.key}-$label.dart.txt'),
        );
        if (update) {
          await goldenFile.writeAsBytes(bytes, flush: true);
          continue;
        }

        expect(
          goldenFile.existsSync(),
          isTrue,
          reason:
              'missing golden for ${flavor.key}-$label — regenerate '
              'goldens ONLY on the pre-dedupe baseline with '
              'ZFA_STATE_UPDATE_GOLDENS=1',
        );
        final golden = await goldenFile.readAsBytes();
        expect(
          utf8.decode(bytes),
          equals(utf8.decode(golden)),
          reason:
              'output for ${flavor.key}-$label drifted from the golden '
              'baseline — the dedupe must be byte-neutral; if this is '
              'an INTENTIONAL emission change, re-baseline on a '
              'reviewed decision and document it in the PR',
        );
      }
    }

    if (update) {
      // When regenerating, still assert the matrix is deterministic:
      // a second pass over every fixture must reproduce the same
      // bytes (guards against accidental nondeterminism sneaking
      // into the baseline itself).
      for (final flavor in _flavors.entries) {
        final flavorRoot = Directory(p.join(base.path, flavor.key));
        for (final fixture in _fixtures) {
          final (label, buildConfig) = fixture;
          final outputDir = p.join(flavorRoot.path, label, 'lib', 'src');
          final builder = StateBuilder(
            outputDir: outputDir,
            options: const GeneratorOptions(
              dryRun: false,
              force: true,
              verbose: false,
            ),
          );
          final file = await builder.generate(buildConfig(outputDir));
          expect(
            File(file.path).readAsBytesSync(),
            equals(generated['${flavor.key}-$label']),
            reason:
                'emission must be deterministic across runs '
                '(${flavor.key}-$label)',
          );
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
