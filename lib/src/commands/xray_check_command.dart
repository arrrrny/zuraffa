import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/project/project_root.dart';
import '../domain/entities/feature_contract/feature_contract_decorators.dart';
import '../domain/entities/feature_contract/xray_layer_decorators.dart';
import '../plugins/slice/generators/feature_slice_composer.dart';
import '../plugins/slice/models/feature_slice_manifest.dart';
import '../plugins/slice/services/feature_contract_resolution.dart';

/// `zfa xray check <feature-id>` (spec 1115, issue #1115 item 3).
///
/// Uses the slice's SliceBoundary record (#1114 — the contract boundary
/// rides the slice manifest) to verify the feature-grouped deck is
/// COHERENT with the composed slice:
///
/// 1. every `.dart` file in the slice carries an `@XrayLayer` decorator
///    matching its slice half (`engine/**` → engine, `skin/**` → skin,
///    the split the contract's xrayLayer maps onto);
/// 2. no file outside the slice is in the deck — a project file
///    attributed to the feature (`@FeatureOwned('<id>')`) that the
///    slice manifest does not know is a named violator;
/// 3. no file in the slice is missing a layer.
///
/// Exit codes: `0` clean slice · `1` violations (named) · `64` usage
/// errors (missing/unknown feature id).
class XrayCheckCommand extends Command<void> {
  @override
  String get name => 'check';

  @override
  String get description =>
      'Check a feature slice: every file declares its xray layer, the deck '
      'stays inside the slice boundary (spec 1115)';

  XrayCheckCommand() {
    argParser.addOption(
      'root',
      help:
          'Project root to check (default: current directory). Lets tests '
          'run against an explicit sandbox instead of the process working '
          'directory.',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final featureId = rest.isEmpty ? null : rest.first.trim();
    if (featureId == null || featureId.isEmpty) {
      print('Error: provide a feature id, e.g. zfa xray check 004-login-ui');
      exitCode = 64;
      return;
    }
    final projectRoot =
        (argResults?['root'] as String?) ?? ProjectRoot.safeCurrentPath();

    // The SAME typed resolver slice compose and the deck use — xray can
    // never disagree about what a feature is.
    final resolved = resolveFeatureContract(
      projectRoot: projectRoot,
      featureId: featureId,
    );
    if (resolved == null) {
      final known = knownFeatureContractIds(projectRoot);
      print(
        'Error: unknown feature contract: "$featureId". '
        'Known contracts: ${known.isEmpty ? "(none)" : known.join(", ")}.',
      );
      exitCode = 64;
      return;
    }
    final contract = resolved.contract;

    final sliceRoot = FeatureSliceComposer.sliceRootOf(
      projectRoot,
      contract.id,
    );
    final manifestFile = File(p.join(sliceRoot, 'slice.yaml'));
    if (!manifestFile.existsSync()) {
      print(
        'Error: no composed slice for "$featureId" at '
        '${p.relative(sliceRoot, from: projectRoot)}.',
      );
      print('Run: zfa slice compose $featureId');
      exitCode = 1;
      return;
    }
    final FeatureSliceManifest manifest;
    try {
      manifest = FeatureSliceManifest.fromYaml(manifestFile.readAsStringSync());
    } on FeatureSliceManifestYamlError {
      print(
        'Error: corrupt slice.yaml for "$featureId" — re-compose the slice '
        '(zfa slice compose $featureId).',
      );
      exitCode = 1;
      return;
    }

    final violations = <String>[];

    // Checks 1 + 3: every slice .dart file declares its layer, and the
    // declared layer matches the slice half (the split the contract's
    // xrayLayer maps onto). Generated harness files (router, boundary
    // mock, slice DI) are part of the slice and are checked too.
    final sliceFiles = [...manifest.engineFiles, ...manifest.skinFiles];
    final checkedPaths = {
      for (final f in sliceFiles) f.relativePath,
      ...manifest.generatedFiles,
    };
    final breakdown = <XraySplit, int>{
      for (final split in XraySplit.values) split: 0,
    };
    for (final sliceRel in checkedPaths) {
      if (!sliceRel.endsWith('.dart')) continue;
      final file = File(p.join(sliceRoot, sliceRel));
      if (!file.existsSync()) {
        violations.add(
          '$sliceRel: listed in slice.yaml but missing from the composed slice',
        );
        continue;
      }
      final declared = XrayLayerDecorators.scan(file.readAsStringSync());
      final expected = FeatureSliceComposer.sliceSplitOf(sliceRel);
      if (declared == null) {
        violations.add(
          '$sliceRel: missing @XrayLayer decorator '
          '(no layer declared — expected \'${expected.name}\')',
        );
        continue;
      }
      if (declared != expected) {
        violations.add(
          '$sliceRel: @XrayLayer(\'${declared.name}\') does not match its '
          'slice half (expected \'${expected.name}\')',
        );
        continue;
      }
      breakdown[declared] = breakdown[declared]! + 1;
    }

    // The slice's SliceBoundary (#1114): the declared seam must travel
    // with the slice — the boundary interface belongs to the engine half.
    final boundary = manifest.feature.boundary;
    if (boundary != null && boundary.interfaceFile.isNotEmpty) {
      final boundaryInSlice = sliceFiles.any(
        (f) => p.basename(f.relativePath) == p.basename(boundary.interfaceFile),
      );
      if (!boundaryInSlice) {
        violations.add(
          '${boundary.interfaceFile}: the contract boundary interface is not '
          'in the slice (spec 1114: the seam travels with the engine)',
        );
      }
    }

    // Check 2: no file outside the slice is in the deck — every project
    // file the feature OWNS (@FeatureOwned anchor) must be inside the
    // composed slice.
    final owned =
        FeatureContractDecorators.scan(projectRoot)[contract.id] ??
        const <String>{};
    final sliceBasenames = checkedPaths.map(p.basename).toSet();
    for (final rel in owned) {
      if (!sliceBasenames.contains(p.basename(rel))) {
        violations.add(
          '$rel: in the deck (@FeatureOwned(\'${contract.id}\')) but outside '
          'the slice — remove it from the deck or extend the contract',
        );
      }
    }

    // Report.
    print(
      'X-Ray check for feature "${contract.id}" '
      '(slice: ${manifest.sliceRoot}, origin: ${manifest.origin})',
    );
    print(
      'Layer breakdown: engine=${breakdown[XraySplit.engine]}, '
      'skin=${breakdown[XraySplit.skin]}, '
      'shared=${breakdown[XraySplit.shared]} '
      '(${checkedPaths.length} slice file(s))',
    );
    if (violations.isEmpty) {
      print(
        'Clean: every slice file declares its layer, the boundary travels '
        'with the slice, and no deck file lives outside the slice.',
      );
      return;
    }
    print('Found ${violations.length} violation(s):');
    for (final violation in violations) {
      print('  - $violation');
    }
    exitCode = 1;
  }
}
