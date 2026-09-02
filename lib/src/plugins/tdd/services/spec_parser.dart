/// `SpecParser` — reads a `spec.md` and emits a list of behaviors.
library;

import '../models/behavior.dart';

class SpecParser {
  const SpecParser();

  /// The UI-intent signature (bug #830): acceptance prose that names a
  /// UI-observable outcome — rendered surfaces, layout regions, navigation
  /// outcomes, the app shell — cannot be expressed by a plain-function
  /// subject, so such scenarios are marked [BehaviorKind.widget] and their
  /// gen pair is a view-builder stub + a `testWidgets` test. The signature
  /// is deliberately tight and pinned to the issue's named acceptance
  /// prose ("renders brand theme", "sidebar on macOS", "bottom nav on
  /// iOS") plus unambiguous widget nouns — deliberately NOT generic
  /// display verbs/nouns ("shows", "displays", "screen") that CLI and
  /// pipeline specs carry without being UI behaviors (e.g. "they see the
  /// home screen" is an ordinary acceptance scenario, spec 041). The
  /// explicit `zfa tdd gen <id> --kind widget` override covers anything
  /// the prose misses.
  static final RegExp uiAcceptanceIntent = RegExp(
    r'\b(renders?|sidebar|bottom nav|tab bar|app bar|app shell|themes?|'
    r'widgets?|navigat(?:es|ion|ing))\b',
    caseSensitive: false,
  );

  /// Whether an acceptance scenario's prose carries UI intent (bug #830).
  static bool isUiAcceptance(String description) =>
      uiAcceptanceIntent.hasMatch(description);

  List<Behavior> parse(String feature, String specMd) {
    final acceptance = _extractAcceptance(feature, specMd);
    if (acceptance.isEmpty) {
      throw StateError(
        'spec.md for feature "$feature" contains no acceptance scenarios '
        '(`Given ... When ... Then ...` blocks). Cannot derive a TDD test '
        'list from a spec with no acceptance criteria. See FR-012.',
      );
    }
    final unit = _extractUnit(feature, specMd);
    return [...acceptance, ...unit];
  }

  List<Behavior> _extractAcceptance(String feature, String specMd) {
    final behaviors = <Behavior>[];
    final lines = specMd.split('\n');
    var scenarioBuffer = <String>[];
    var aIdx = 0;

    Behavior? flush() {
      if (scenarioBuffer.isEmpty) return null;
      final header = RegExp(
        r'^\s*(\d+)\.\s*\*\*Given\*\*',
      ).firstMatch(scenarioBuffer.first);
      if (header == null) {
        scenarioBuffer = <String>[];
        return null;
      }
      aIdx += 1;
      final description = _extractScenarioText(scenarioBuffer.join('\n'));
      final behavior = Behavior(
        id: 'A$aIdx',
        feature: feature,
        // Bug #830: spec-driven widget marking — an acceptance scenario
        // whose prose is UI-observable gets the widget subject kind so
        // plan writes it into the widget section and gen emits a
        // testWidgets pair instead of a smoke-shaped plain-function stub.
        kind: isUiAcceptance(description)
            ? BehaviorKind.widget
            : BehaviorKind.acceptance,
        description: description,
        sourceCriterion: 'AC-${header.group(1)}',
        target: '',
      );
      scenarioBuffer = <String>[];
      return behavior;
    }

    for (final line in lines) {
      if (RegExp(r'^\s*\d+\.\s*\*\*Given\*\*').hasMatch(line) &&
          scenarioBuffer.isNotEmpty) {
        final flushed = flush();
        if (flushed != null) behaviors.add(flushed);
      }
      scenarioBuffer.add(line);
    }
    final last = flush();
    if (last != null) behaviors.add(last);
    return behaviors;
  }

  String _extractScenarioText(String line) {
    final match = RegExp(
      r'\*\*Then\*\*\s*(.+)$',
      multiLine: true,
    ).firstMatch(line);
    if (match != null) {
      return match.group(1)!.replaceAll('**', '').trim();
    }
    return line.replaceAll('**', '').trim();
  }

  List<Behavior> _extractUnit(String feature, String specMd) {
    final behaviors = <Behavior>[];
    final frPattern = RegExp(r'^\s*-\s*\*\*(FR-\d{3})\*\*:\s*(.+)$');
    var uIdx = 0;
    for (final line in specMd.split('\n')) {
      final m = frPattern.firstMatch(line);
      if (m != null) {
        uIdx += 1;
        final frId = m.group(1)!;
        final desc = m.group(2)!.replaceAll('**', '').trim();
        behaviors.add(
          Behavior(
            id: 'U$uIdx',
            feature: feature,
            kind: BehaviorKind.unit,
            description: desc,
            sourceCriterion: frId,
            target: '',
          ),
        );
      }
    }
    return behaviors;
  }
}
