/// Command-side plumbing for declared-intent routing (feature 071):
/// file-reading lookups that feed parsed declarations into the pure
/// [RoutingResolver]. The resolver itself stays pure; these helpers do
/// the reads commands would otherwise duplicate, and fail OPEN (null)
/// so legacy inference keeps serving undeclared behaviors during the
/// fallback window.
library;

import 'dart:io';

import '../models/routing.dart';
import 'routing_resolver.dart';
import 'spec_parser.dart';
import 'test_list_reader.dart';

class DeclaredRouting {
  const DeclaredRouting._();

  /// The declared signature for [behaviorId], resolved from the
  /// feature's test-list trace cell against the spec's contract rows.
  /// Null when the behavior is undeclared or any artifact is missing or
  /// unreadable — callers fall back to their legacy inference (the
  /// labeled fallback window; strict surfaces are handled at plan).
  static Future<Signature?> declaredSignatureFor({
    required String cwd,
    required String featureName,
    required String behaviorId,
  }) async {
    try {
      final featureDir = '$cwd/specs/$featureName';
      final rows = await TestListReader(featureDir).read();
      final row = rows.where((r) => r.id == behaviorId).firstOrNull;
      // The traces cell is a raw string (`FR-001, Formatter.format`) —
      // split into tokens before resolving.
      final traces = row == null
          ? const <String>[]
          : row.traces
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
      if (traces.isEmpty) return null;
      final specFile = File('$featureDir/spec.md');
      if (!specFile.existsSync()) return null;
      final declarations = SpecDeclarations(
        contractRows: {
          for (final r
              in const SpecParser().parseContractRows(specFile.readAsStringSync()))
            r.name: r,
        },
      );
      final result = const RoutingResolver().resolve(
        row: RoutingRow(behaviorId: behaviorId, traces: traces),
        declarations: declarations,
      );
      if (result is RoutingDecision) return result.signature;
      return null;
    } catch (_) {
      return null; // fallback window: never break the legacy scaffold
    }
  }
}
