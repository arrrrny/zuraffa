/// `SpecMarkerEmitter` — the one-time routing migration (issue #1186).
///
/// Specs authored by the speckit template never carry the per-scenario
/// `**Type**` markers the declared-intent grammar wants, so `zfa tdd
/// plan` routes EVERY behavior through the labeled legacy classifier
/// fallback and `--strict-routing` refuses everything (unusable on
/// speckit-authored specs). The classifier is accurate — it lands the
/// route in the right lane — so plan can emit the classified marker
/// back into the spec once, post-derivation: the fallback becomes a
/// one-time migration instead of a per-run warning (mirror of
/// #1183/#990, the template-drift family).
///
/// What is emitted: exactly one `   **Type**: <kind>` line per
/// UNDECLARED scenario behavior that routed via the fallback, inserted
/// directly after the scenario's `1. **Given**` header (inside the
/// scenario block, where [SpecParser.parseScenarioTypeMarkers] reads
/// markers). Only scenario-emittable kinds (`acceptance`, `widget`)
/// migrate — a unit behavior's strict lane declaration is a contract
/// trace no classifier can invent, so the FR fallback keeps its hint.
///
/// Safety properties:
/// * idempotent — a scenario already carrying any `**Type**` marker is
///   never re-declared (a duplicate marker refuses the plan);
/// * scenario-walk-faithful — the id walk mirrors the parser's
///   `_extractAcceptance` (same header regex on RAW lines, the same
///   document-wide `A<n>` numbering, manual scenarios consuming a
///   number but emitting no row) so emitted ids align with the
///   behaviors actually derived;
/// * fence-safe — a numbered `**Given**` example inside a fenced code
///   block is documentation: it still consumes its id (the parser's
///   raw walk derives from it) but never receives a marker, and an
///   existing marker inside a fence never counts as declared;
/// * content-preserving — nothing but the inserted marker lines
///   changes; every other byte is preserved verbatim.
library;

import '../models/behavior.dart';

/// What [SpecMarkerEmitter.emit] decided to do with the spec.
class MarkerEmissionResult {
  const MarkerEmissionResult({required this.content, required this.emitted});

  /// The spec content to persist — identical to the input when
  /// [emitted] is empty.
  final String content;

  /// The markers actually written: behavior id (`A<n>`) → the kind
  /// declared, in document order.
  final Map<String, BehaviorKind> emitted;

  bool get migrated => emitted.isNotEmpty;

  @override
  String toString() =>
      'MarkerEmissionResult(${emitted.length} markers: '
      '${emitted.keys.join(', ')})';
}

class SpecMarkerEmitter {
  const SpecMarkerEmitter();

  /// A scenario block header (`1. **Given** ...`) — the same walk
  /// `_extractAcceptance` uses, so emitted ids align with the derived
  /// behaviors.
  static final RegExp _scenarioHeader = RegExp(r'^\s*(\d+)\.\s*\*\*Given\*\*');

  /// Any existing `**Type**` marker line — presence inside a scenario
  /// block means the scenario is already declared (never re-declare).
  static final RegExp _markerLine = RegExp(r'^\s*\*\*Type\*\*:');

  /// A fenced code block boundary (``` … ```).
  static final RegExp _fenceLine = RegExp(r'^[ \t]*```');

  /// Emit [markers] (behavior id → classified kind) into [specMd].
  /// Never throws on a spec without scenarios — an empty emission is
  /// the normal no-op result, not an error.
  MarkerEmissionResult emit(String specMd, Map<String, BehaviorKind> markers) {
    final wanted = <String, BehaviorKind>{
      for (final MapEntry(:key, :value) in markers.entries)
        if (_emittable(value)) key: value,
    };
    if (wanted.isEmpty || !specMd.contains('**Given**')) {
      return MarkerEmissionResult(content: specMd, emitted: const {});
    }
    final lines = specMd.split('\n');
    final out = <String>[];
    final emitted = <String, BehaviorKind>{};
    var inFence = false;
    var aIdx = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Fence state flips BEFORE any matching so a line's own
      // in-fence status is known (a ``` line is a boundary, never a
      // scenario header).
      if (_fenceLine.hasMatch(line)) inFence = !inFence;
      out.add(line);
      if (!_scenarioHeader.hasMatch(line)) continue;
      // Document-wide id — the same raw-line numbering walk the
      // parser's scenario extraction uses.
      aIdx += 1;
      final id = 'A$aIdx';
      final kind = wanted[id];
      if (kind == null) continue; // declared, manual, or not emittable
      if (inFence) continue; // a fenced example is documentation
      // A marker anywhere in this block (outside fences) means the
      // scenario declares itself — never create a duplicate.
      if (_blockDeclaresMarker(lines, i, inFence)) continue;
      out.add('   **Type**: ${kind.name}');
      emitted[id] = kind;
    }
    if (emitted.isEmpty) {
      return MarkerEmissionResult(content: specMd, emitted: const {});
    }
    return MarkerEmissionResult(content: out.join('\n'), emitted: emitted);
  }

  /// Whether the scenario block starting at line [headerIndex] (0-based)
  /// already carries a `**Type**` marker. The block ends at the next
  /// scenario header or markdown heading; fenced spans are skipped
  /// (a fenced marker is documentation, not a declaration).
  bool _blockDeclaresMarker(
    List<String> lines,
    int headerIndex,
    bool headerInFence,
  ) {
    var fence = headerInFence;
    for (var i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (_fenceLine.hasMatch(line)) fence = !fence;
      if (fence) continue;
      if (_scenarioHeader.hasMatch(line) || line.trimLeft().startsWith('#')) {
        return false;
      }
      if (_markerLine.hasMatch(line)) return true;
    }
    return false;
  }

  /// Only scenario-derived kinds migrate: the parse-time sniffer
  /// produces acceptance/widget for scenarios; a unit behavior's
  /// strict declaration is a contract trace (not a marker).
  static bool _emittable(BehaviorKind kind) =>
      kind == BehaviorKind.acceptance || kind == BehaviorKind.widget;
}
