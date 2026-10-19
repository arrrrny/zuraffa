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

import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

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
  final MergeCheck cache;
  final MergeCheck i18n;
  final MergeCheck localization;
  final MergeCheck localizationKeys;
  final MergeCheck hardcodedStrings;
  final MergeCheck featureSuite;
  final bool rolledBack;

  MergeVerdict({
    required this.feature,
    required this.routes,
    required this.di,
    MergeCheck? views,
    MergeCheck? cache,
    MergeCheck? i18n,
    MergeCheck? localization,
    MergeCheck? localizationKeys,
    MergeCheck? hardcodedStrings,
    MergeCheck? featureSuite,
    this.rolledBack = false,
  }) : views = views ?? const MergeCheck(name: 'views', pass: true),
       cache = cache ?? const MergeCheck(name: 'cache', pass: true),
       i18n = i18n ?? const MergeCheck(name: 'i18n', pass: true),
       localization =
           localization ??
           i18n ??
           const MergeCheck(name: 'localization', pass: true),
       localizationKeys =
           localizationKeys ??
           i18n ??
           const MergeCheck(name: 'localizationKeys', pass: true),
       hardcodedStrings =
           hardcodedStrings ??
           i18n ??
           const MergeCheck(name: 'hardcodedStrings', pass: true),
       featureSuite =
           featureSuite ?? const MergeCheck(name: 'featureSuite', pass: true);

  bool get passed =>
      routes.pass &&
      di.pass &&
      views.pass &&
      cache.pass &&
      i18n.pass &&
      localization.pass &&
      localizationKeys.pass &&
      hardcodedStrings.pass &&
      featureSuite.pass;

  /// The failing checks, in gate order.
  List<MergeCheck> get failures => [
    routes,
    di,
    views,
    cache,
    i18n,
    localization,
    localizationKeys,
    hardcodedStrings,
    featureSuite,
  ].where((c) => !c.pass).toList();

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
      'cache': check(cache),
      'i18n': check(i18n),
      'localization': check(localization),
      'localizationKeys': check(localizationKeys),
      'hardcodedStrings': check(hardcodedStrings),
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
    final diTokens = diNode is Map
        ? (diNode['tokensResolved'] as num? ?? 0).toInt()
        : 0;
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
      cache: check('cache', evidenceKey: 'resolved'),
      i18n: check('i18n', evidenceKey: 'resolved'),
      localization: check('localization', evidenceKey: 'resolved'),
      localizationKeys: check('localizationKeys', evidenceKey: 'resolved'),
      hardcodedStrings: check('hardcodedStrings', evidenceKey: 'resolved'),
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
      'cache=${cache.pass ? 'pass' : 'fail'} '
      'i18n=${i18n.pass ? 'pass' : 'fail'} '
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
          if (resolves(binding.token, flavor)) '${binding.token}@$flavor',
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
      evidence: currentFailures.where((f) => !newFailures.contains(f)).toList(),
    );
  }

  /// Check — cache: every expected entity adapter is registered in the
  /// Hive registrar. Offenders name the missing entity with a fix hint.
  static MergeCheck cache({
    List<String>? expectedEntities,
    List<String>? registeredEntities,
    List<String>? expected,
    List<String>? registered,
  }) {
    final exp = expectedEntities ?? expected ?? const <String>[];
    final reg = registeredEntities ?? registered ?? const <String>[];
    final regSet = reg.toSet();
    final offenders = [
      for (final entity in exp)
        if (!regSet.contains(entity))
          "cache adapter for '$entity' is missing from the Hive registrar "
              '--> fix: run `zfa cache adapter $entity`, then re-run '
              '`zfa slice merge --into <host>`.',
    ];
    final resolved = [
      for (final entity in exp)
        if (regSet.contains(entity)) entity,
    ];
    return MergeCheck(
      name: 'cache',
      pass: offenders.isEmpty,
      offenders: offenders,
      evidence: resolved,
    );
  }

  /// Alias for [cache].
  static MergeCheck cacheAdapter({
    List<String>? expectedEntities,
    List<String>? registeredEntities,
    List<String>? expected,
    List<String>? registered,
  }) => cache(
    expectedEntities: expectedEntities,
    registeredEntities: registeredEntities,
    expected: expected,
    registered: registered,
  );

  /// Check — i18n: every `t.<key>` accessor in the merged views has a
  /// corresponding translation entry, and there are no hardcoded
  /// user-facing strings. Offenders name the key/file with a fix hint.
  static MergeCheck i18n({
    String name = 'i18n',
    Map<String, String>? viewSources,
    Map<String, String>? views,
    Iterable<String>? translationKeys,
    Iterable<String>? definedKeys,
    Iterable<String>? keys,
    Map<String, String>? translations,
    Iterable<String>? allowedLiterals,
  }) {
    return _i18n(
      name: name,
      viewSources: viewSources ?? views ?? const <String, String>{},
      translationKeys: <String>{
        ...?translationKeys,
        ...?definedKeys,
        ...?keys,
        ...?translations?.keys,
      },
      allowedLiterals: allowedLiterals ?? const <String>[],
      keysOnly: false,
      hardcodedOnly: false,
    );
  }

  static MergeCheck localization({
    Map<String, String>? viewSources,
    Map<String, String>? views,
    Iterable<String>? translationKeys,
    Iterable<String>? definedKeys,
    Iterable<String>? keys,
    Map<String, String>? translations,
    Iterable<String>? allowedLiterals,
  }) => i18n(
    name: 'localization',
    viewSources: viewSources,
    views: views,
    translationKeys: translationKeys,
    definedKeys: definedKeys,
    keys: keys,
    translations: translations,
    allowedLiterals: allowedLiterals,
  );

  static MergeCheck l10n({
    Map<String, String>? viewSources,
    Map<String, String>? views,
    Iterable<String>? translationKeys,
    Iterable<String>? definedKeys,
    Iterable<String>? keys,
    Map<String, String>? translations,
    Iterable<String>? allowedLiterals,
  }) => i18n(
    name: 'l10n',
    viewSources: viewSources,
    views: views,
    translationKeys: translationKeys,
    definedKeys: definedKeys,
    keys: keys,
    translations: translations,
    allowedLiterals: allowedLiterals,
  );

  /// Check — localization keys only: every `t.<key>` in the merged views
  /// has a corresponding translation entry.
  static MergeCheck localizationKeys({
    Map<String, String>? viewSources,
    Map<String, String>? views,
    Iterable<String>? translationKeys,
    Iterable<String>? definedKeys,
    Iterable<String>? keys,
    Map<String, String>? translations,
  }) {
    return _i18n(
      name: 'localizationKeys',
      viewSources: viewSources ?? views ?? const <String, String>{},
      translationKeys: <String>{
        ...?translationKeys,
        ...?definedKeys,
        ...?keys,
        ...?translations?.keys,
      },
      allowedLiterals: const <String>[],
      keysOnly: true,
      hardcodedOnly: false,
    );
  }

  /// Check — hardcoded user-facing strings only: no quoted user-facing
  /// string in the merged views.
  static MergeCheck hardcodedStrings({
    Map<String, String>? viewSources,
    Map<String, String>? views,
    Iterable<String>? allowedLiterals,
  }) {
    return _i18n(
      name: 'hardcodedStrings',
      viewSources: viewSources ?? views ?? const <String, String>{},
      translationKeys: const <String>{},
      allowedLiterals: allowedLiterals ?? const <String>[],
      keysOnly: false,
      hardcodedOnly: true,
    );
  }

  static MergeCheck _i18n({
    String name = 'i18n',
    required Map<String, String> viewSources,
    required Set<String> translationKeys,
    required Iterable<String> allowedLiterals,
    required bool keysOnly,
    required bool hardcodedOnly,
  }) {
    final offenders = <String>[];
    final usedKeys = <String>{};
    for (final src in viewSources.values) {
      for (final m in RegExp(r't\.([a-zA-Z_][\w.]*)').allMatches(src)) {
        usedKeys.add(m.group(1)!);
      }
    }
    final resolvedKeys = <String>[];
    if (!hardcodedOnly) {
      for (final k in usedKeys) {
        if (!translationKeys.contains(k)) {
          offenders.add(
            "localization key 't.$k' has no translation entry "
            '--> fix: add \'$k\' to lib/i18n/strings.i18n.json, then '
            're-run `zfa slice merge --into <host>`.',
          );
        } else {
          resolvedKeys.add(k);
        }
      }
    }
    if (!keysOnly) {
      for (final path in viewSources.keys) {
        final src = viewSources[path]!;
        for (final literal in UiLedgerBuilder.quotedUserFacingStrings(src)) {
          if (allowedLiterals.contains(literal)) continue;
          offenders.add(
            "hardcoded user-facing string '$literal' in '$path' "
            '--> fix: replace with a t.<key> accessor, then re-run '
            '`zfa slice merge --into <host>`.',
          );
        }
      }
    }
    return MergeCheck(
      name: name,
      pass: offenders.isEmpty,
      offenders: offenders,
      evidence: resolvedKeys..sort(),
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
