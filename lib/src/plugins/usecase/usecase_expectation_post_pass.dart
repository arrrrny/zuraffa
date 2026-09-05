import 'dart:io';

import '../../utils/method_extractor.dart';
import 'usecase_verdicts.dart';

/// Spec #972 FR-4 — the `zfa make` post-pass that closes the #921
/// fail-open hole.
///
/// When the source-interface guard failed open (the interface file was
/// absent at usecase-generation time), the run *assumed* the responsible
/// plugin would declare the requested methods. This verifier re-checks
/// that assumption against the tree as it exists AFTER the plan
/// committed: for every recorded expectation whose responsible plugin
/// (repository or service) ran in the plan, the interface file must
/// exist and declare every expected method. Any gap is a same-plan
/// misfire — the generated usecases call methods nobody declared and the
/// project cannot compile — so the make run must fail loudly with the
/// exact repair command instead of letting the build break later.
///
/// Expectations whose responsible plugin did NOT run in the plan are
/// skipped: a usecase-only run keeps the pre-existing fail-open contract
/// (there is no same-plan author to verify).
class UsecaseExpectationPostPass {
  /// Verifies [expectations] against the committed tree under
  /// [projectRoot]. [activePluginIds] is the set of plugin ids that ran
  /// in the plan.
  ///
  /// Returns the failures (empty list = the plan is consistent).
  Future<List<UsecaseExpectationFailure>> verify({
    required String projectRoot,
    required List<UseCaseInterfaceExpectation> expectations,
    required Set<String> activePluginIds,
  }) async {
    final failures = <UsecaseExpectationFailure>[];
    for (final expectation in expectations) {
      if (expectation.methods.isEmpty) continue;
      if (!activePluginIds.contains(expectation.responsiblePluginId)) {
        // No same-plan author for this interface — pre-existing
        // fail-open contract, out of this pass's scope.
        continue;
      }

      final interfacePath = expectation.resolve(projectRoot);
      final interfaceFile = File(interfacePath);
      final declared = await MethodExtractor.extractMethodsFromInterface(
        interfacePath,
        expectation.className,
      );
      final declaredNames = declared.map((m) => m.fieldName).toSet();
      final missing = expectation.methods
          .where((m) => !declaredNames.contains(m))
          .toList(growable: false);

      if (missing.isNotEmpty || !interfaceFile.existsSync()) {
        failures.add(
          UsecaseExpectationFailure(
            expectation: expectation,
            missingMethods: missing,
            interfaceExists: interfaceFile.existsSync(),
          ),
        );
      }
    }
    return failures;
  }
}

/// One unmet interface expectation.
class UsecaseExpectationFailure {
  final UseCaseInterfaceExpectation expectation;

  /// Expected methods the committed interface does not declare (all of
  /// them when the interface file was never created).
  final List<String> missingMethods;

  /// False when the interface file does not exist at all.
  final bool interfaceExists;

  UsecaseExpectationFailure({
    required this.expectation,
    required this.missingMethods,
    required this.interfaceExists,
  });

  /// The full missing set for reporting (the requested set when the
  /// interface never landed).
  List<String> get effectiveMissing =>
      missingMethods.isNotEmpty ? missingMethods : expectation.methods;

  /// The human-facing diagnostic line.
  String get detail {
    final interfacePath = expectation.interfacePath;
    if (!interfaceExists) {
      return '❌ usecase #921 post-pass: ${expectation.entity} usecases '
          'call ${expectation.className}.{${effectiveMissing.join(', ')}} '
          'but $_responsibleName never created the interface '
          '($interfacePath) in this plan.';
    }
    return '❌ usecase #921 post-pass: ${expectation.className} '
        '($interfacePath) does not declare: '
        '${missingMethods.join(', ')} — the usecases generated for '
        '${expectation.entity} call them and will not compile.';
  }

  /// The exact repair command (issue #921's fix hint).
  String get fixLine {
    final methods = effectiveMissing.join(',');
    if (expectation.viaService) {
      return '--> fix: zfa service create ${expectation.entity} '
          '--service=${expectation.className} --methods=$methods';
    }
    return '--> fix: zfa repository create ${expectation.entity} '
        '--methods=$methods';
  }

  String get _responsibleName =>
      expectation.viaService ? 'the service plugin' : 'the repository plugin';
}

/// Loads expectations recorded by [UseCasePlugin] into the plan context
/// (a list of JSON maps under `usecase_interface_expectations`).
List<UseCaseInterfaceExpectation> expectationsFromContextData(
  Map<String, dynamic> data,
) {
  final raw = data['usecase_interface_expectations'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (m) =>
            UseCaseInterfaceExpectation.fromJson(Map<String, dynamic>.from(m)),
      )
      .toList(growable: false);
}
