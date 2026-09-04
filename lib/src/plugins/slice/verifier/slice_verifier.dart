/// SliceVerifier (feature 073, issue #961): orchestrates the three
/// `slice verify` checks into the machine-readable [SliceVerdict] —
/// self-containment (imports resolve + zero host references), mock
/// certification (every declared dependency binds a certified mock),
/// and suite state (the sandbox suite runs green).
///
/// Pure and synchronous: facts in, verdict out. The sandbox suite run
/// arrives through the injectable [SandboxSuiteRunner] seam, so the
/// verifier itself performs no I/O beyond reading the sandbox.
///
/// Contract: `contracts/verify-verdict.md` — absence of a declared
/// fact reports as a failure naming the absence, never as passing.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../../../core/ast/file_parser.dart';
import '../../mock/models/dependency_contract.dart';
import '../../mock/services/dependency_parity.dart';
import '../generators/sandbox_scaffold.dart';
import '../models/slice_manifest.dart';
import '../models/slice_verdict.dart';
import 'import_verifier.dart';
import 'self_containment.dart';

/// Outcome of one sandbox suite run (injectable seam — the real runner
/// shells out to the sandbox's test command).
class SuiteOutcome {
  final bool passed;

  /// Failing test names (or the runner's failure summary lines).
  final List<String> failures;

  const SuiteOutcome({required this.passed, this.failures = const []});
}

/// Runs the sandbox suite; injectable so verify stays hermetic in tests.
typedef SandboxSuiteRunner = SuiteOutcome Function(String sandboxDir);

/// The three-check slice verifier.
class SliceVerifier {
  /// Creates the verifier with injectable collaborators.
  SliceVerifier({
    ImportVerifier? importVerifier,
    SandboxSuiteRunner? suiteRunner,
    FileParser? parser,
  }) : _importVerifier = importVerifier ?? ImportVerifier(),
       _suiteRunner = suiteRunner,
       _parser = parser ?? const FileParser();

  final ImportVerifier _importVerifier;
  final SandboxSuiteRunner? _suiteRunner;
  final FileParser _parser;

  /// Verify the sandbox at [sandboxDir] against the declared facts
  /// recorded in [manifest] (routes, dependencies) and the host root
  /// it was cut from ([hostRoot]; imports-only self-containment when
  /// absent). With [runSuite] the injected suite runner supplies the
  /// suite-state check; without one, suite state reports as failed
  /// naming the absence — never as passing.
  SliceVerdict verify({
    required String sandboxDir,
    required SliceManifest manifest,
    String? hostRoot,
    bool runSuite = true,
  }) {
    return SliceVerdict(
      selfContainment: _checkSelfContainment(
        sandboxDir: sandboxDir,
        manifest: manifest,
        hostRoot: hostRoot,
      ),
      mockCertification: _checkMockCertification(
        sandboxDir: sandboxDir,
        manifest: manifest,
      ),
      suiteState: _checkSuiteState(sandboxDir, runSuite: runSuite),
    );
  }

  SliceCheck _checkSelfContainment({
    required String sandboxDir,
    required SliceManifest manifest,
    required String? hostRoot,
  }) {
    final offenders = <String>[];

    final importReport = _importVerifier.verify(
      sandboxDir: sandboxDir,
      projectRoot: hostRoot ?? sandboxDir,
    );
    for (final issue in importReport.issues) {
      offenders.add(issue.toString());
    }

    final hostRefs = HostReferenceScanner.scan(
      sandboxDir: sandboxDir,
      hostRoot: hostRoot,
    );
    for (final ref in hostRefs) {
      offenders.add(
        '$ref -- host reference escapes the sandbox --> fix: remove the '
        'host path/reference; the sandbox must be self-contained '
        '(issue #961 self-containment)',
      );
    }

    return SliceCheck(
      name: 'selfContainment',
      pass: offenders.isEmpty,
      offenders: offenders,
    );
  }

  /// Every declared dependency must bind its certified mock in the
  /// sandbox DI and the artifact must carry every declared member
  /// (parity, the 072 rail).
  SliceCheck _checkMockCertification({
    required String sandboxDir,
    required SliceManifest manifest,
  }) {
    final offenders = <String>[];
    final diFile = File(p.join(sandboxDir, 'lib', 'di.dart'));
    final diSource = diFile.existsSync() ? diFile.readAsStringSync() : '';

    for (final dependency in manifest.dependencies) {
      final contract = DependencyContract.parseRow(
        name: dependency.dependency,
        type: dependency.kind,
        contract: dependency.contract,
        priority: dependency.priority,
      );
      final token = SandboxBinding(
        dependency: dependency.dependency,
        kind: dependency.kind,
        mockArtifact: dependency.mockArtifact,
      ).token;
      if (!diSource.contains("sandbox.bind('$token'")) {
        offenders.add(
          "${dependency.dependency} -- unbound in sandbox DI (no "
          "sandbox.bind('$token')) --> fix: declare the dependency at cut "
          'so the certified mock binds (issue #961 mock certification)',
        );
        continue;
      }
      final artifact = File(p.join(sandboxDir, dependency.mockArtifact));
      if (!artifact.existsSync()) {
        offenders.add(
          '${dependency.dependency} -- certified mock artifact missing at '
          '${dependency.mockArtifact} --> fix: cut installs the certified '
          'mock from the 072 dependency-mock rail (issue #961)',
        );
        continue;
      }
      final parity = DependencyParity.check(
        contract: contract,
        adapterMembers: _classMembers(artifact.readAsStringSync()),
      );
      if (!parity.passed) {
        offenders.add(
          '${dependency.dependency} -- certified mock drifts from the '
          'declared contract (missing: ${parity.driftedMembers.join(", ")}) '
          '${parity.fixHint}',
        );
      }
    }

    return SliceCheck(
      name: 'mockCertification',
      pass: offenders.isEmpty,
      offenders: offenders,
    );
  }

  SliceCheck _checkSuiteState(String sandboxDir, {required bool runSuite}) {
    if (!runSuite || _suiteRunner == null) {
      return SliceCheck(
        name: 'suiteState',
        pass: false,
        offenders: [
          'sandbox suite not run --> fix: wire a sandbox suite runner or '
          'run `zfa slice verify --json` from the CLI (issue #961)',
        ],
      );
    }
    final outcome = _suiteRunner(sandboxDir);
    return SliceCheck(
      name: 'suiteState',
      pass: outcome.passed,
      offenders: [
        for (final failure in outcome.failures)
          '$failure --> fix: make the sandbox suite green; the sandbox '
          'runs on certified mocks alone (issue #961 suite state)',
      ],
    );
  }

  /// Class member shapes of a Dart source — the `name(params)` list
  /// [DependencyParity.check] consumes.
  List<String> _classMembers(String source) {
    final unit = _parser.parseSource(source).unit;
    if (unit == null) return const [];
    final shapes = <String>[];
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration) continue;
      final body = declaration.body;
      if (body is! BlockClassBody) continue;
      for (final member in body.members) {
        if (member is MethodDeclaration) {
          shapes.add('${member.name}${member.parameters ?? ''}');
        }
      }
    }
    return shapes;
  }
}
