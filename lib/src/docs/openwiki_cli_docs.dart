/// Openwiki CLI docs helpers (SPEC 1132 / EPIC 1 lane 4, issue #1383).
///
/// `docs/openwiki/cli.md` is GENERATED from the live dispatcher by
/// `tool/generate_openwiki_cli_docs.dart`. The generator's command-list
/// parser used to be line-anchored: the first command description that
/// wrapped past the CLI's 120-column `kUsageLineLength`
/// (`lib/src/cli/usage_length.dart`) landed on a continuation line, the
/// regex stopped matching, and the tool "generated" a 12-command doc —
/// silently clobbering the committed 59-command file. The docs could not
/// be refreshed after any command-surface change.
///
/// This module owns the parser so the tool, the unit tests and the
/// drift-guard regression test share ONE implementation: continuation
/// lines are consumed (they are part of the previous command's
/// description), only a genuinely new command row (or the end of the
/// block) advances or terminates the scan.
library;

/// Parses the command names out of a `zfa --help` output's
/// "Available commands:" block.
///
/// A command row is exactly two leading spaces, the command name, then
/// two or more spaces of padding before the description:
/// `  corpus              Import and walk ...`. A WRAPPED description
/// continues on a line indented past the command column
/// (`                      ledger (merge gate). ...`) — that line is
/// part of the previous row's description, not a new command. The scan
/// ends at the first line that is neither (e.g. the trailing
/// `Run "zfa help" ...` line or a blank line).
List<String> parseCommandNames(String helpOutput) {
  final names = <String>[];
  var inCommands = false;
  final commandRow = RegExp(r'^  (\S+)\s{2,}');
  final continuation = RegExp(r'^   +\S');
  for (final line in helpOutput.split('\n')) {
    if (!inCommands) {
      if (line.startsWith('Available commands:')) {
        inCommands = true;
      }
      continue;
    }
    final match = commandRow.firstMatch(line);
    if (match != null) {
      names.add(match.group(1)!);
      continue;
    }
    // A continuation of the previous command's wrapped description:
    // consume it — the description column is far past the command
    // column, so the row regex cannot match it by construction.
    if (continuation.hasMatch(line)) continue;
    // Anything else (a blank line, the trailing "Run zfa help" line,
    // a differently-shaped row) ends the command block.
    break;
  }
  return names;
}
