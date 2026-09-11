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

  /// Issue #1485: the feature's contract documents — every `*.md` file
  /// under `<featureDir>/contracts/`, sorted by file name (the
  /// multi-file collision policy is deterministic last-wins). A feature
  /// with no `contracts/` directory yields an empty list: the
  /// declared-row source reads exactly what it read before. Only
  /// markdown is enumerated — code files inside contracts/ are never
  /// parsed — and an unreadable file contributes nothing (the plan's
  /// zero-rows warning names the directory).
  static List<({String file, String md})> contractFiles(String featureDir) {
    final dir = Directory(p.join(featureDir, 'contracts'));
    if (!dir.existsSync()) return const [];
    final files = <({String file, String md})>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;
      try {
        files.add((
          file: p.basename(entity.path),
          md: entity.readAsStringSync(),
        ));
      } on FileSystemException {
        continue; // unreadable: contributes nothing, never crashes plan
      }
    }
    files.sort((a, b) => a.file.compareTo(b.file));
    return files;
  }

  /// The declared signature for [behaviorId], resolved from the
  /// feature's test-list trace cell against the spec's contract rows.
  /// Null when the behavior is undeclared or any artifact is missing
  /// or unreadable — callers fall back to their legacy inference (the
  /// labeled fallback window; strict surfaces are handled at plan). A
  /// malformed spec declaration throws [StateError]: the caller
  /// surfaces the `--> fix:` message and a non-zero exit instead of a
  /// silent prose fallback.
  /// [featureDir] is the already-resolved feature directory (bug
  /// features live under `.specify/bugs/<slug>`, not `specs/<name>`).
  /// When omitted, the legacy `specs/<featureName>` path is used.
  static Future<Signature?> declaredSignatureFor({
    required String cwd,
    required String featureName,
    required String behaviorId,
    String? featureDir,
  }) async {
    final resolvedDir = featureDir ?? p.join(cwd, 'specs', featureName);
    final List<BehaviorRow> rows;
    try {
      rows = await TestListReader(resolvedDir).read();
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
    final specFile = File(p.join(resolvedDir, 'spec.md'));
    if (!specFile.existsSync()) return null;
    final String specMd;
    try {
      specMd = specFile.readAsStringSync();
    } on FileSystemException {
      return null; // unreadable spec: legacy inference, the fallback window
    }
    // Malformed declarations (StateError) propagate on purpose. Issue
    // #1485: the declared rows include the feature's contracts/*.md
    // rows — a trace bound at plan time resolves its declared signature
    // at gen time from the SAME merged source (declare once, resolve
    // everywhere).
    final declarations = SpecDeclarations(
      contractRows: SpecParser.declaredContractRows(
        specMd,
        contractFiles: contractFiles(resolvedDir),
      ).rows,
    );
    final result = const RoutingResolver().resolve(
      row: RoutingRow(behaviorId: behaviorId, traces: traces),
      declarations: declarations,
    );
    if (result is RoutingDecision) return result.signature;
    return null;
  }
}
