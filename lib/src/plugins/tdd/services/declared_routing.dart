/// Command-side plumbing for declared-intent routing (feature 071):
/// file-reading lookups that feed parsed declarations into the pure
/// [RoutingResolver]. The resolver itself stays pure; these helpers do
/// the reads commands would otherwise duplicate. Absent/unreadable
/// artifacts fail OPEN (null) so legacy inference keeps serving
/// undeclared behaviors during the fallback window; a MALFORMED
/// declaration (the parser's [StateError] refusals) propagates —
/// falling back to prose inference exactly when the declaration is
/// malformed is the #920 regression class (round-2 review fix 3c).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/routing.dart';
import 'routing_resolver.dart';
import 'spec_parser.dart';
import 'test_list_reader.dart';

class DeclaredRouting {
  const DeclaredRouting._();

  /// The declared signature for [behaviorId], resolved from the
  /// feature's test-list trace cell against the spec's contract rows.
  /// Null when the behavior is undeclared or any artifact is missing
  /// or unreadable — callers fall back to their legacy inference (the
  /// labeled fallback window; strict surfaces are handled at plan). A
  /// malformed spec declaration throws [StateError]: the caller
  /// surfaces the `--> fix:` message and a non-zero exit instead of a
  /// silent prose fallback.
  static Future<Signature?> declaredSignatureFor({
    required String cwd,
    required String featureName,
    required String behaviorId,
  }) async {
    final featureDir = p.join(cwd, 'specs', featureName);
    final List<BehaviorRow> rows;
    try {
      rows = await TestListReader(featureDir).read();
    } on TestListReadException {
      return null; // unreadable list: legacy inference, the fallback window
    }
    final row = rows.where((r) => r.id == behaviorId).firstOrNull;
    // The traces cell is a raw string (`FR-001, Formatter.format`) —
    // tokenize with the shared [SpecParser.traceTokens] contract so a
    // backticked inline signature never splits and never dangles
    // (round-2 review fix 2).
    final traces = row == null
        ? const <String>[]
        : SpecParser.traceTokens(row.traces);
    if (traces.isEmpty) return null;
    final specFile = File(p.join(featureDir, 'spec.md'));
    if (!specFile.existsSync()) return null;
    final String specMd;
    try {
      specMd = specFile.readAsStringSync();
    } on FileSystemException {
      return null; // unreadable spec: legacy inference, the fallback window
    }
    // Malformed declarations (StateError) propagate on purpose.
    final declarations = SpecDeclarations(
      contractRows: {
        for (final r in const SpecParser().parseContractRows(specMd)) r.name: r,
      },
    );
    final result = const RoutingResolver().resolve(
      row: RoutingRow(behaviorId: behaviorId, traces: traces),
      declarations: declarations,
    );
    if (result is RoutingDecision) return result.signature;
    return null;
  }
}
