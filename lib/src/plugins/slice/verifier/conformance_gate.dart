/// ConformanceGate (feature 074, issue #962): the merge verdict —
/// after landing, routes / DI / views / feature-suite each check
/// against the pre-merge host baseline; any failure rolls the host
/// back byte-identically and names the failed checks.
///
/// Contract: `contracts/conformance-verdict.md` — gate order is
/// routes → di → views → featureSuite; the machine-readable verdict
/// and the final summary line are part of the API.
library;

import 'dart:convert';

import '../merger/host_baseline.dart';
import 'di_graph_check.dart';
import 'route_barrel.dart';

/// One named gate check: pass/fail plus named offenders and the
/// check's positive evidence (resolved routes, resolved tokens).
class MergeCheck {
  final String name;
  final bool pass;
  final List<String> offenders;

  /// Positive evidence (e.g. resolved route paths, resolved token
  /// count) — a pass must show WHAT passed.
  final List<String> evidence;

  const MergeCheck({
    required this.name,
    required this.pass,
    this.offenders = const [],
    this.evidence = const [],
  });
}

/// The full merge conformance verdict.
class MergeVerdict {
  final String feature;
  final MergeCheck routes;
  final MergeCheck di;
  final MergeCheck views;
  final MergeCheck featureSuite;
  final bool rolledBack;

  const MergeVerdict({
    required this.feature,
    required this.routes,
    required this.di,
    required this.views,
    required this.featureSuite,
    this.rolledBack = false,
  });

  bool get passed =>
      routes.pass && di.pass && views.pass && featureSuite.pass;

  /// The failing checks, in gate order.
  List<MergeCheck> get failures =>
      [routes, di, views, featureSuite].where((c) => !c.pass).toList();

  /// The outcome word of the summary line.
  String outcome({required bool gateRan}) {
    if (passed) return 'landed';
    return rolledBack ? 'rolled-back' : 'refused';
  }

  /// Stable JSON per the contract shape.
  String encode() {
    Map<String, Object> check(MergeCheck c) => {
      'pass': c.pass,
      if (c.evidence.isNotEmpty) 'resolved': c.evidence,
      'offenders': c.offenders,
    };
    return const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'check': 'slice-merge-conformance',
      'feature': feature,
      'routes': check(routes),
      'di': {
        'pass': di.pass,
        'tokensResolved': di.evidence.length,
        'offenders': di.offenders,
      },
      'views': check(views),
      'featureSuite': {
        'pass': featureSuite.pass,
        'newFailures': featureSuite.offenders,
        'offenders': featureSuite.offenders,
      },
      'passed': passed,
      'rolled-back': rolledBack,
    });
  }

  /// Parse a verdict JSON (the merge surface reads what the gate wrote).
  static MergeVerdict decode(String json) {
    final doc = jsonDecode(json);
    if (doc is! Map) throw const FormatException('corrupt merge verdict');
    MergeCheck check(String name, {String? evidenceKey}) {
      final node = doc[name];
      if (node is! Map) {
        return MergeCheck(name: name, pass: false);
      }
      return MergeCheck(
        name: name,
        pass: node['pass'] == true,
        offenders: [
          for (final o in (node['offenders'] as List? ?? const []))
            o.toString(),
        ],
        evidence: [
          if (evidenceKey != null)
            for (final e in (node[evidenceKey] as List? ?? const []))
              e.toString(),
        ],
      );
    }

    final diNode = doc['di'];
    final diTokens =
        diNode is Map ? (diNode['tokensResolved'] as num? ?? 0).toInt() : 0;
    return MergeVerdict(
      feature: doc['feature']?.toString() ?? '',
      routes: check('routes', evidenceKey: 'resolved'),
      di: MergeCheck(
        name: 'di',
        pass: diNode is Map && diNode['pass'] == true,
        offenders: [
          if (diNode is Map)
            for (final o in (diNode['offenders'] as List? ?? const []))
              o.toString(),
        ],
        evidence: List.generate(diTokens, (i) => 'token#$i'),
      ),
      views: check('views'),
      featureSuite: check('featureSuite', evidenceKey: 'newFailures'),
      rolledBack: doc['rolled-back'] == true,
    );
  }

  /// The final stdout line (contract shape).
  String summaryLine({required String host, required bool gateRan}) =>
      'slice-merge: feature=$feature host=$host '
      'routes=${routes.pass ? 'pass' : 'fail'} '
      'di=${di.pass ? 'pass' : 'fail'} '
      'views=${views.pass ? 'pass' : 'fail'} '
      'feature-suite=${featureSuite.pass ? 'pass' : 'fail'} '
      'rolled-back=$rolledBack '
      'outcome=${outcome(gateRan: gateRan)}';
}

/// The four-gate conformance check over the merged host.
abstract final class ConformanceGate {
  /// Check 1 — routes: every declared path resolves through the
  /// regenerated barrel (pure table traversal, per-route offenders).
  static MergeCheck routes({
    required String barrel,
    required List<RouteDecl> declared,
  }) {
    final offenders = RouteBarrel.resolutionOffenders(
      barrelSource: barrel,
      declared: declared,
    );
    final resolved = [
      for (final route in declared) route.path,
    ].where((path) => !offenders.any((o) => o.contains("'$path'"))).toList();
    return MergeCheck(
      name: 'routes',
      pass: offenders.isEmpty,
      offenders: offenders,
      evidence: resolved,
    );
  }

  /// Check 2 — DI: every token resolves per flavor (construction
  /// results injected; the runner is the host's own suite).
  static MergeCheck di({
    required List<DiBindingDecl> bindings,
    required bool Function(String token, String flavor) resolves,
  }) {
    final offenders = DiGraphCheck.resolutionOffenders(
      bindings: bindings,
      resolves: resolves,
    );
    final resolved = [
      for (final binding in bindings)
        for (final flavor in binding.flavors)
          if (resolves(binding.token, flavor))
            '${binding.token}@$flavor',
    ];
    return MergeCheck(
      name: 'di',
      pass: offenders.isEmpty,
      offenders: offenders,
      evidence: resolved,
    );
  }

  /// Check 3 — views: every merged view composes the host shell
  /// convention (structural check); off-convention artifacts are named.
  static MergeCheck views({
    required Map<String, String> viewSources,
    required String shellConvention,
  }) {
    final offenders = <String>[];
    final paths = viewSources.keys.toList()..sort();
    for (final path in paths) {
      if (!viewSources[path]!.contains(shellConvention)) {
        offenders.add(
          "view '$path' does not compose the host shell convention "
          '($shellConvention) --> fix: wrap the page in the host '
          'adaptive shell, then re-run `zfa slice merge --into <host>`.',
        );
      }
    }
    return MergeCheck(
      name: 'views',
      pass: offenders.isEmpty,
      offenders: offenders,
      evidence: offenders.isEmpty ? paths : const [],
    );
  }

  /// Check 4 — feature suite: baseline-aware. Pre-existing reds are
  /// reported, never blamed; new reds always fail the gate.
  static MergeCheck featureSuite({
    required List<String> baselineFailures,
    required List<String> currentFailures,
  }) {
    final newFailures = HostBaseline.newFailures(
      baseline: baselineFailures,
      current: currentFailures,
    );
    return MergeCheck(
      name: 'featureSuite',
      pass: newFailures.isEmpty,
      offenders: [
        for (final failure in newFailures)
          '$failure --> fix: make the newly red behavior green '
              '(pre-existing reds are tolerated, new ones are not).',
      ],
      evidence: currentFailures
          .where((f) => !newFailures.contains(f))
          .toList(),
    );
  }
}

/// The 075 composition point: the coverage gate as a merge check —
/// an incomplete ledger blocks the landing, naming the gaps.
///
/// The coverage facts come from `zfa tdd coverage`'s verdict (tdd
/// plugin); this check stays in the gate's own shape.
class CoverageCheck {
  /// Build the coverage gate check from the coverage verdict's counts.
  static MergeCheck fromCounts({
    required int surfaces,
    required int proven,
    required List<String> gaps,
  }) {
    final unproven = surfaces - proven;
    return MergeCheck(
      name: 'coverage',
      pass: unproven == 0,
      offenders: [
        for (final gap in gaps)
          '$gap --> fix: write/land the proving behavior for the surface '
              '— no behavior traces it (issue #963).',
      ],
      evidence: List.generate(proven, (i) => 'proven#$i'),
    );
  }
}
