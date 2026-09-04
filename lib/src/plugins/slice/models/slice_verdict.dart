/// SliceVerdict (feature 073, issue #961): the machine-readable result
/// of `zfa slice verify --json` — three named checks, each with
/// pass/fail and named offenders.
///
/// Contract: `contracts/verify-verdict.md` — exit 0 iff all pass;
/// absence of a manifest section reports as absent, never as passing.
library;

import 'dart:convert';

/// One named check of the verify verdict.
class SliceCheck {
  final String name;
  final bool pass;
  final List<String> offenders;

  const SliceCheck({
    required this.name,
    required this.pass,
    this.offenders = const [],
  });

  Map<String, Object> toJson() => {'pass': pass, 'offenders': offenders};
}

/// The full verify verdict.
class SliceVerdict {
  final SliceCheck selfContainment;
  final SliceCheck mockCertification;
  final SliceCheck suiteState;

  const SliceVerdict({
    required this.selfContainment,
    required this.mockCertification,
    required this.suiteState,
  });

  bool get passed =>
      selfContainment.pass && mockCertification.pass && suiteState.pass;

  /// The failing checks, in contract order (self-containment,
  /// mock-certification, suite).
  List<SliceCheck> get failures => [
    selfContainment,
    mockCertification,
    suiteState,
  ].where((c) => !c.pass).toList();

  Map<String, Object> toJson() => {
    'check': 'slice-verify',
    'selfContainment': selfContainment.toJson(),
    'mockCertification': mockCertification.toJson(),
    'suiteState': suiteState.toJson(),
    'passed': passed,
  };

  /// Serialize to the verdict JSON file (stable key order, no
  /// timestamps — determinism). Uses JsonEncoder for proper escaping;
  /// the decode path relies on jsonDecode, so the roundtrip must match.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Parse a verdict JSON (the merge gate reads what verify wrote).
  ///
  /// Proper JSON decoding: offenders may contain brackets or quotes —
  /// the shape is parsed, never regexed.
  static SliceVerdict decode(String json) {
    final dynamic doc;
    try {
      doc = jsonDecode(json);
    } on FormatException {
      throw const FormatException('corrupt verify-verdict.json');
    }
    if (doc is! Map) {
      throw const FormatException('corrupt verify-verdict.json');
    }
    SliceCheck check(String name) {
      final node = doc[name];
      if (node is! Map) {
        return SliceCheck(name: name, pass: false, offenders: const []);
      }
      final offenders = <String>[
        for (final offender in (node['offenders'] as List? ?? const []))
          offender.toString(),
      ];
      return SliceCheck(
        name: name,
        pass: node['pass'] == true,
        offenders: offenders,
      );
    }

    return SliceVerdict(
      selfContainment: check('selfContainment'),
      mockCertification: check('mockCertification'),
      suiteState: check('suiteState'),
    );
  }

  /// The final stdout summary line.
  String summaryLine(String feature) =>
      'slice-verify: feature=$feature '
      'self-containment=${selfContainment.pass ? 'pass' : 'fail'} '
      'mock-certification=${mockCertification.pass ? 'pass' : 'fail'} '
      'suite=${suiteState.pass ? 'pass' : 'fail'} '
      'outcome=${passed ? 'verified' : 'failed'}';
}
