/// The shared `--explain` human-prose emitter (issue #1125).
///
/// `--explain` is the human twin of `--json` (issue #964's verdict.v1
/// envelope): `--json` is machine-readable, `--explain` is human prose,
/// and both may be passed together — the output is then the JSON verdict
/// line, a separator, and the explanation, in that order (issue #1125
/// acceptance). `--json` alone is byte-identical to the pre-#1125
/// behavior: the explanation only ever prints when `--explain` is set.
///
/// The block carries the sections issue #1125 orders:
///
///   * `features touched:` — the feature(s) the verb operated on;
///   * `lane run:` — which lane (engine vs skin) the run drove;
///   * `receipts written:` — the receipts the verb wrote (or validated);
///   * `fix hints:` — the `--> fix:` remediation lines the path emitted;
///   * `summary:` — a one-paragraph narrative of what happened and why.
///
/// Section content reuses the journals where they already record the
/// same events (spec #1085's journal dream, realized as the unified
/// `JournalWriter`/`JournalReader` of spec 1113): the run and status
/// blocks name the receipt refs the journal entries carry, never fresh
/// strings invented per verb.
library;

import 'package:args/command_runner.dart';

/// The `--explain` flag's help text — shared by the four verbs so the
/// flag surface stays in lockstep (the `--json` help text pattern,
/// kJsonFlagHelp).
const String kExplainFlagHelp =
    'Print a human-readable multi-line explanation of what this command '
    'did and why: the features touched, the lane (engine vs skin) run, '
    'the receipts written, the fix hints emitted, and a one-paragraph '
    'narrative summary (issue #1125). The human twin of --json: both '
    'flags may be passed together — the JSON verdict line comes first, '
    'then a separator, then this explanation.';

/// Extracts the `--explain` flag from a command's parsed args.
bool tddExplainMode(Command<void> command) {
  final args = command.argResults;
  if (args == null) return false;
  try {
    return args['explain'] as bool? ?? false;
  } catch (_) {
    return false; // verb does not declare --explain
  }
}

/// The explanation a command body accumulates while it runs.
///
/// Every field is optional except [command]: when the body stopped
/// before it could populate one (a usage refusal, for example), the
/// wrapper derives a minimal block from the verdict context — every
/// `--explain` invocation prints the sections, on every exit path.
class TddExplain {
  TddExplain({
    required this.command,
    this.features = const <String>[],
    this.lane,
    this.receipts = const <String>[],
    this.fixHints = const <String>[],
    this.summary = '',
  });

  /// The verb the block explains (e.g. `plan`).
  final String command;

  /// The features the verb touched.
  final List<String> features;

  /// The lane the verb drove — `engine`, `skin`, `engine + skin`, or a
  /// short clause when the verb drives no lane. Null renders the same
  /// no-lane clause.
  final String? lane;

  /// The receipts the verb wrote (or validated, for the audit verbs):
  /// journal refs and receipt file names, not absolute paths.
  final List<String> receipts;

  /// The `--> fix:` remediation lines the path emitted.
  final List<String> fixHints;

  /// The one-paragraph narrative summary.
  final String summary;
}

/// Renders one list section: the label followed by the items (one per
/// indented line), or `none` on the label line when the list is empty.
void _writeSection(StringBuffer buf, String label, List<String> items) {
  if (items.isEmpty) {
    buf.writeln('$label none');
    return;
  }
  buf.writeln(label);
  for (final item in items) {
    buf.writeln('  - $item');
  }
}

/// Prints the explain block to stdout (the observable-CLI convention:
/// `runCapturing` intercepts `print`, so the block rides the captured
/// output like every other line the verbs emit).
///
/// The block's first line IS the separator the `--explain` + `--json`
/// acceptance names — printed after the envelope, the combined output
/// reads JSON + separator + explanation.
void emitExplainBlock(TddExplain explain) {
  final lane = explain.lane ?? 'none — this verb drives no engine/skin lane';
  final buf = StringBuffer()
    ..writeln('--- explain: ${explain.command} ---')
    ..writeln('features touched: ${explain.features.join(', ')}')
    ..writeln('lane run: $lane')
    .._receipts(explain.receipts)
    .._fixHints(explain.fixHints)
    ..writeln()
    ..writeln('summary: ${explain.summary}');
  // ignore: avoid_print
  print(buf.toString().trimRight());
}

extension on StringBuffer {
  /// `receipts written:` — empty renders `none` (the vacuous-gate
  /// honesty the receipt preflight itself prints).
  void _receipts(List<String> receipts) =>
      _writeSection(this, 'receipts written:', receipts);

  /// `fix hints:` — empty renders `none` (a path with no remediation).
  void _fixHints(List<String> hints) =>
      _writeSection(this, 'fix hints:', hints);
}
