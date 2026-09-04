// SPDX-License-Identifier: MIT
//
// OutputFormat — uniform, machine-readable output for the standard CLI
// plugin (FR-008).
//
// Two renderers: [OutputFormat.json] (single-line JSON for pipelines) and
// [OutputFormat.text] (human-readable multi-line). [OutputFormat.detect]
// auto-selects based on whether stdout is a TTY.
//
// Every command's [CommandResult] can be rendered in either format. The JSON
// shape follows the contract's `zuraffa.cli.v1` schema:
//
//   {
//     "$schema": "zuraffa.cli.v1",
//     "outcome": "success" | "error" | "warning",
//     "data": { ... },          // present on success / warning
//     "error": {                // present on error
//       "code": "runtime" | "notFound" | ...,
//       "message": "...",
//       "details": { ... }
//     }
//   }
//
// Pure-Dart (FR-012).

import 'dart:convert';

import 'cli_contract.dart';
import 'command_model.dart';

/// The output format renderer for the standard CLI contract (FR-008).
class OutputFormat {
  const OutputFormat();

  /// Render a [CommandResult] as a single-line JSON string.
  ///
  /// The JSON has a `$schema` field set to [CliContract.outputSchemaName], an
  /// `outcome` field (`'success'`, `'error'`, `'warning'`), and either a
  /// `data` field (success/warning) or an `error` field (error). The output
  /// is a single line with no trailing newline, suitable for piping into
  /// `jq` or another JSON consumer.
  String json(
    CommandResult result, {
    CliContract contract = CliContract.standard,
  }) {
    final map = <String, Object?>{
      '\$schema': contract.outputSchemaName,
      'outcome': result.outcome,
    };
    switch (result) {
      case SuccessResult(:final data):
        map['data'] = data;
      case WarningResult(:final message, :final data):
        map['data'] = data;
        map['warning'] = message;
      case ErrorResult(:final code, :final message, :final details):
        map['error'] = {'code': code, 'message': message, 'details': details};
    }
    return jsonEncode(map);
  }

  /// Render a [CommandResult] as plain text with no emoji and no ANSI color
  /// codes. Used by `zfa route verify --plain` and any other command that
  /// needs byte-identical output across runs in CI logs.
  ///
  /// Unlike [text], the plain path omits the two-space indent so output
  /// can be parsed by simple `key: value` grep patterns in CI. Do not
  /// change the indent to match [text] — it is intentionally flatter.
  /// The order of `details` keys is the `Map` iteration order
  /// (insertion order), so two calls over the same input return
  /// byte-identical output — required for stable CI log diffs.
  String plain(CommandResult result) {
    switch (result) {
      case SuccessResult(:final data):
        if (data.isEmpty) return '';
        final buf = StringBuffer();
        data.forEach((k, v) => buf.writeln('$k: $v'));
        final s = buf.toString();
        return s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
      case WarningResult(:final message, :final data):
        final buf = StringBuffer('WARN: $message');
        if (data.isNotEmpty) {
          for (final entry in data.entries) {
            buf.writeln();
            buf.write('  ${entry.key}: ${entry.value}');
          }
        }
        return buf.toString();
      case ErrorResult(:final code, :final message, :final details):
        final buf = StringBuffer('ERROR: [$code] $message');
        if (details.isNotEmpty) {
          for (final entry in details.entries) {
            buf.writeln();
            buf.write('  ${entry.key}: ${entry.value}');
          }
        }
        return buf.toString();
    }
  }

  /// Render a [CommandResult] as a human-readable multi-line string.
  ///
  /// For errors, the format is `❌ [<code>] <message>` followed by any
  /// `details` keys (indented). For success, the result's [SuccessResult.text]
  /// is emitted. For warnings, `⚠️ <message>` is emitted on the first line
  /// followed by the data.
  String text(CommandResult result) {
    switch (result) {
      case SuccessResult(:final String text):
        return text;
      case WarningResult(:final message, :final data):
        final buf = StringBuffer('⚠️ $message\n');
        if (data.isNotEmpty) {
          data.forEach((k, v) => buf.writeln('  $k: $v'));
        }
        final s = buf.toString();
        return s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
      case ErrorResult(:final code, :final message, :final details):
        final buf = StringBuffer('❌ [$code] $message');
        if (details.isNotEmpty) {
          for (final entry in details.entries) {
            buf.writeln();
            buf.write('  ${entry.key}: ${entry.value}');
          }
        }
        return buf.toString();
    }
  }

  /// Auto-detect the appropriate output format for the current process.
  ///
  /// Returns [OutputFormatKind.text] when stdout is a TTY (interactive),
  /// [OutputFormatKind.json] when stdout is piped or redirected. This is the
  /// FR-009 non-interactive edge case: when piped, output MUST be
  /// machine-readable so pipelines compose reliably.
  ///
  /// Pass `stdout.hasTerminal` (the production call site) or `false` in tests
  /// to simulate a piped stdout.
  OutputFormatKind detect(bool isTty) {
    return isTty ? OutputFormatKind.text : OutputFormatKind.json;
  }
}

/// The output format kind, used by [OutputFormat.detect].
enum OutputFormatKind { text, json }
