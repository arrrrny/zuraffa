/// `TestListReader` — parses a feature's `tdd/test-list.md` (the 4-column
/// format `plan_command.dart` writes) into [BehaviorRow]s, in list order
/// (spec 049-tdd-run, FR-001 / U1-U3).
///
/// Rows look like `| B-001 | description | FR-001 | PENDING |`. The kind
/// (acceptance vs unit) is inferred from the enclosing `## Outer loop:` /
/// `## Inner loop:` section header — the writer's format is the contract
/// this reader consumes. A row that is not a well-formed 4-column row with
/// a valid state is malformed and stops the caller with an error naming
/// the line (FR-011 misfire-stop; the plan-vs-gen column mismatch gap is
/// surfaced, not papered over — see specs/049-tdd-run research, Decision 5).
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
  });

  final String id;
  final String description;
  final String traces;
  final BehaviorState state;
  final BehaviorKind kind;

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
      rows.add(_parseDataRow(cells, kind: kind, lineNo: i + 1, raw: raw));
    }
    return rows;
  }

  BehaviorRow _parseDataRow(
    List<String> cells, {
    required BehaviorKind? kind,
    required int lineNo,
    required String raw,
  }) {
    Never malformed(String reason) => throw TestListReadException(
      'test-list.md line $lineNo: $reason: "$raw"',
    );

    if (kind == null) {
      malformed('table row outside an outer/inner loop behavior section');
    }
    if (cells.length != 5) {
      malformed(
        'expected 4 columns (id/behavior/traces/state), '
        'found ${cells.length - 1}',
      );
    }
    final id = cells[1];
    if (id.isEmpty) malformed('empty behavior id');
    final state = _parseState(cells[4]);
    if (state == null) malformed('unknown state "${cells[4]}"');
    return BehaviorRow(
      id: id,
      description: cells[2],
      traces: cells[3],
      state: state,
      kind: kind,
    );
  }

  static BehaviorState? _parseState(String cell) {
    for (final state in BehaviorState.values) {
      if (state.name == cell.toLowerCase()) return state;
    }
    return null;
  }
}
