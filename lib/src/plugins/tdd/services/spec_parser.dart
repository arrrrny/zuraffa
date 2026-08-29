/// `SpecParser` — reads a `spec.md` and emits a list of behaviors.
library;

import '../models/behavior.dart';

class SpecParser {
  const SpecParser();

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
      final behavior = Behavior(
        id: 'A$aIdx',
        feature: feature,
        kind: BehaviorKind.acceptance,
        description: _extractScenarioText(scenarioBuffer.join('\n')),
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
