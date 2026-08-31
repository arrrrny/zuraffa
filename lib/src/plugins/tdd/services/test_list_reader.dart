/// `TestListReader` — the SINGLE format contract for a feature's
/// `tdd/test-list.md` (bug #617: plan, gen and run previously spoke two
/// independently-grown dialects; this reader is now the one parser every
/// consumer shares).
///
/// Canonical shape — the 4-column format `plan_command.dart` writes
/// (spec 049-tdd-run, FR-001 / U1-U3):
///
///     | B-001 | description | FR-001 | PENDING |
///
/// The kind (acceptance vs unit) is inferred from the enclosing
/// `## Outer loop:` / `## Inner loop:` section header, and the target
/// defaults to `subject_<snake-id>` (the same defaulting gen's private
/// parser applied before the unification; see [_resolveTarget]).
///
/// Deprecated compatibility shim (one release, bug #617 remediation):
/// hand-written 6-column rows in gen's old private dialect
///
///     | B-001 | description | FR-001 | unit | PENDING | target |
///
/// are still accepted — the kind cell wins over the section header, an
/// empty or path-like target cell falls back to `subject_<snake-id>`, and
/// a deprecation note is printed to stderr once per file. A row that
/// matches NEITHER shape is malformed and stops the caller with an error
/// naming the line (FR-011 misfire-stop; format drift is surfaced, not
/// papered over — see specs/049-tdd-run research, Decision 5).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';

/// One parsed test-list row.
class BehaviorRow {
  const BehaviorRow({
    required this.id,
    required this.description,
    required this.traces,
    required this.state,
    required this.kind,
    required this.target,
  });

  final String id;
  final String description;
  final String traces;
  final BehaviorState state;
  final BehaviorKind kind;

  /// The subject function this behavior targets. Never empty: rows
  /// without an explicit target resolve to `subject_<snake-id>`
  /// (moved here from gen's private parser, bug #617).
  final String target;

  @override
  String toString() =>
      'BehaviorRow(id: $id, kind: ${kind.name}, state: ${state.name}, '
      'traces: $traces)';
}

/// Raised when the test list cannot be read or a row is malformed. The
/// message names the file and — for malformed rows — the line number and
/// content (U3).
class TestListReadException implements Exception {
  const TestListReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TestListReader {
  const TestListReader(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Parse `tdd/test-list.md` into rows, in list order.
  Future<List<BehaviorRow>> read() async {
    final file = File(p.join(featureDir, 'tdd', 'test-list.md'));
    if (!await file.exists()) {
      throw TestListReadException(
        'no test list at ${file.path} — run `zfa tdd plan <feature>` first',
      );
    }
    final lines = (await file.readAsString()).split('\n');
    final rows = <BehaviorRow>[];
    BehaviorKind? kind;
    var deprecatedDialectWarned = false;
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trim();
      if (trimmed.startsWith('## ')) {
        final header = trimmed.substring(3).toLowerCase();
        if (header.startsWith('outer loop')) {
          kind = BehaviorKind.acceptance;
        } else if (header.startsWith('inner loop')) {
          kind = BehaviorKind.unit;
        } else {
          kind = null;
        }
        continue;
      }
      if (!trimmed.startsWith('|')) continue;
      final cells = trimmed.split('|').map((c) => c.trim()).toList();
      if (cells.length > 1 && cells.last.isEmpty) cells.removeLast();
      // Separator rows (`| -- | --- | ...`).
      final isSeparator = cells
          .skip(1)
          .any((c) => c.isNotEmpty && RegExp(r'^-+$').hasMatch(c));
      if (isSeparator) continue;
      // Header rows (`| id | behavior | ...`).
      if (cells.length > 1 && cells[1].toLowerCase() == 'id') continue;
      final (row: row, deprecated: deprecated) = _parseDataRow(
        cells,
        kind: kind,
        lineNo: i + 1,
        raw: raw,
      );
      if (row != null) rows.add(row);
      if (deprecated && !deprecatedDialectWarned) {
        deprecatedDialectWarned = true;
        stderr.writeln(
          'zfa: ${file.path}: deprecated 6-column test-list rows detected '
          '(id/behavior/traces/kind/state/target). The canonical format is '
          "the 4-column shape `zfa tdd plan <feature>` writes — re-run it "
          'to migrate; the 6-column dialect is accepted for one release.',
        );
      }
    }
    return rows;
  }

  /// Parse one data row. Returns the row (null when the line is a row
  /// shaped like the deprecated 6-column dialect but with an unusable
  /// kind cell — that falls through to the malformed error) plus whether
  /// the deprecated dialect was used.
  ({BehaviorRow? row, bool deprecated}) _parseDataRow(
    List<String> cells, {
    required BehaviorKind? kind,
    required int lineNo,
    required String raw,
  }) {
    Never malformed(String reason) => throw TestListReadException(
      'test-list.md line $lineNo: $reason: "$raw"',
    );

    // Canonical 4-column row: `| id | behavior | traces | state |`
    // (cells[0] is the empty string before the leading pipe).
    if (cells.length == 5) {
      if (kind == null) {
        malformed('table row outside an outer/inner loop behavior section');
      }
      final id = cells[1];
      if (id.isEmpty) malformed('empty behavior id');
      final state = _parseState(cells[4]);
      if (state == null) malformed('unknown state "${cells[4]}"');
      return (
        row: BehaviorRow(
          id: id,
          description: cells[2],
          traces: cells[3],
          state: state,
          kind: kind,
          target: resolveDefaultTarget(id),
        ),
        deprecated: false,
      );
    }

    // Deprecated 6-column row (gen's old private dialect):
    // `| id | behavior | traces | kind | state | target |`. Only rows
    // whose kind cell is usable take the shim; anything else falls
    // through to the malformed error so drift stays surfaced.
    if (cells.length == 7) {
      final kindFromCell = _kindFromCell(cells[4]);
      if (kindFromCell != null) {
        final id = cells[1];
        if (id.isEmpty) malformed('empty behavior id');
        final state = _parseState(cells[5]);
        if (state == null) malformed('unknown state "${cells[5]}"');
        return (
          row: BehaviorRow(
            id: id,
            description: cells[2],
            traces: cells[3],
            state: state,
            kind: kindFromCell,
            target: resolveDefaultTarget(id, cell: cells[6]),
          ),
          deprecated: true,
        );
      }
    }

    malformed(
      'expected 4 columns (id/behavior/traces/state), '
      'found ${cells.length - 1}',
    );
  }

  /// The subject function this behavior targets (moved from gen's private
  /// parser, bug #617): an explicit non-path cell wins; an empty or
  /// path-like cell (`/`, `::`, `$`) falls back to `subject_<snake-id>`.
  static String resolveDefaultTarget(String id, {String cell = ''}) {
    final isPathLike =
        cell.isEmpty ||
        cell.contains('/') ||
        cell.contains('::') ||
        cell.contains(r'$');
    if (isPathLike) return 'subject_${id.toLowerCase().replaceAll('-', '_')}';
    return cell;
  }

  static BehaviorKind? _kindFromCell(String cell) {
    final kindStr = cell.toLowerCase();
    if (kindStr.contains('acceptance')) return BehaviorKind.acceptance;
    if (kindStr.contains('unit')) return BehaviorKind.unit;
    return null;
  }

  static BehaviorState? _parseState(String cell) {
    for (final state in BehaviorState.values) {
      if (state.name == cell.toLowerCase()) return state;
    }
    return null;
  }
}
