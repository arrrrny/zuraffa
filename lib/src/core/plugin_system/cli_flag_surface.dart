import 'package:args/command_runner.dart';

/// The flag-surface contract for hand-rolled commands (SPEC 917).
///
/// Most plugin commands register their options on a real `ArgParser`, so
/// `zfa manifest --verify` can read the accepted flag set mechanically
/// from `Command.argParser.options`. A few first-party commands dispatch
/// with `ArgParser.allowAnything()` and parse their own rest arguments
/// (`zfa slice`, `zfa benchmark`) — for those the parser accepts
/// everything and the REAL grammar is the hand-rolled dispatch inside
/// `run()`. Those commands declare the flags they actually accept by
/// implementing this interface; the treaty gate then verifies every
/// manifest-advertised `inputSchema` property against the declared
/// surface instead of a permissive parser.
///
/// The declaration must stay honest: it is asserted against the live
/// dispatch by the gate's fixtures and by the command's own tests. A
/// flag listed here but rejected by `run()` is the #904 drift class —
/// the exact lie the gate exists to catch.
abstract class CliFlagSurface {
  /// Every flag name (without leading dashes, kebab-case) this command's
  /// dispatch accepts across all of its subcommands.
  Set<String> get acceptedFlags;
}

/// Resolves the [Command] that serves [capabilityName] inside [parent]'s
/// subcommand tree, or returns [parent] itself for hand-rolled commands
/// that dispatch capability verbs from rest arguments.
///
/// Capability names are snake/dot-joined (`scaffold_feature`,
/// `ui.schema.export`); subcommand names are the verb leaf
/// (`scaffold`) or the manual registration (`json`). The gate tries the
/// full name first, then the leaf, then the dot-segments.
Command<void> resolveServingCommand(
  Command<void> parent,
  String capabilityName,
) {
  final candidates = <String?>[
    capabilityName,
    capabilityName.replaceAll('.', '_'),
    capabilityName.contains('_') ? capabilityName.split('_').first : null,
    capabilityName.contains('.') ? capabilityName.split('.').last : null,
  ].whereType<String>().toList();

  final subcommands = parent.subcommands;
  for (final candidate in candidates) {
    final match = subcommands[candidate];
    if (match != null) return match;
  }
  return parent;
}
