// SPDX-License-Identifier: MIT
//
// StandardCommand — the declarative command model for Zuraffa CLI apps
// (FR-003).
//
// A StandardCommand is a value type describing a CLI command: its name, its
// arguments (positional), its flags (named), and a handler bound to domain
// logic. It is NOT a subclass of `args.Command<void>`; instead, [CliApp]
// adapts a StandardCommand to the underlying `args` parser at runtime. This
// keeps the command model declarative (data, not subclassing) while still
// leveraging the existing `args` package conventions.
//
// Pure-Dart (FR-012): no `package:flutter` import anywhere in this file.

import 'package:meta/meta.dart';

import 'cli_contract.dart';

/// The result of running a command (FR-001, FR-008).
///
/// A handler returns a [CommandResult] that [CliApp] translates into the
/// contract's exit code and the chosen output format (text or JSON). The
/// [outcome] field drives the JSON shape: `'success'` for [SuccessResult],
/// `'error'` for [ErrorResult], `'warning'` for [WarningResult].
@immutable
sealed class CommandResult {
  const CommandResult(this.exitCode);

  /// The contract exit code this result maps to.
  final int exitCode;

  /// One of `'success'`, `'error'`, `'warning'` — drives the JSON `$outcome`
  /// field.
  String get outcome;
}

/// Successful command execution.
@immutable
class SuccessResult extends CommandResult {
  const SuccessResult({this.data = const {}, int? exitCode})
      : super(exitCode ?? 0);

  /// Arbitrary JSON-serializable data emitted on stdout. When
  /// `--output=json`, this object is emitted verbatim under the `data` key.
  /// When `--output=text`, [CliApp] calls [text] to render it.
  final Map<String, Object?> data;

  @override
  String get outcome => 'success';

  /// Default text rendering: each key-value pair on its own line, indented
  /// two spaces. Apps may override by extending [SuccessResult] and providing
  /// a custom [text] implementation.
  String get text {
    if (data.isEmpty) return '';
    final buf = StringBuffer();
    data.forEach((k, v) {
      buf.writeln('  $k: $v');
    });
    final s = buf.toString();
    return s.isEmpty ? '' : s.substring(0, s.length - 1);
  }
}

/// Failed command execution.
@immutable
class ErrorResult extends CommandResult {
  const ErrorResult({
    required this.code,
    required this.message,
    this.details = const {},
    int? exitCode,
  }) : super(exitCode ?? 1);

  /// The error code — one of the [CliExitCodes] vocabulary names as a string
  /// (e.g. `'runtime'`, `'notFound'`). Used in the JSON output's `code` field.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Additional context for the error. May be empty.
  final Map<String, Object?> details;

  @override
  String get outcome => 'error';
}

/// Successful but with a warning the user should see (exit code 0, but the
/// output's `outcome` is `'warning'` so a pipeline can detect it).
@immutable
class WarningResult extends CommandResult {
  const WarningResult({
    required this.message,
    this.data = const {},
    int? exitCode,
  }) : super(exitCode ?? 0);

  /// Human-readable warning message.
  final String message;

  /// Optional data payload.
  final Map<String, Object?> data;

  @override
  String get outcome => 'warning';
}

/// A parsed command invocation — what the handler receives (FR-003).
///
/// Carries the positional arguments, the parsed flags, and a reference to the
/// contract the host app is using (so handlers can build contract-compliant
/// [CommandResult]s without importing the contract directly).
@immutable
class CliInvocation {
  const CliInvocation({
    required this.arguments,
    required this.flags,
    required this.contract,
  });

  /// The positional arguments, in declaration order. May be empty.
  final List<String> arguments;

  /// The parsed flags. Each declared flag is present, with its value (or
  /// `null` for absent boolean flags, or the default value for absent
  /// value-taking flags).
  final Map<String, Object?> flags;

  /// The host app's contract.
  final CliContract contract;
}

/// A positional argument declaration.
@immutable
class CommandArgument {
  const CommandArgument({
    required this.name,
    this.help = '',
    this.required = false,
    this.multiple = false,
  });

  /// The argument name as shown in help.
  final String name;

  /// Help text for the argument.
  final String help;

  /// Whether the argument is required.
  final bool required;

  /// Whether the argument accepts multiple values (variadic).
  final bool multiple;
}

/// A named flag declaration.
@immutable
class CommandFlag {
  const CommandFlag({
    required this.name,
    this.abbr = '',
    this.help = '',
    this.negatable = false,
    this.takesValue = false,
    this.defaultsTo,
  });

  /// The long form, e.g. `--name`.
  final String name;

  /// The short form, e.g. `n` (renders as `-n`). Empty string if no abbreviation.
  final String abbr;

  /// Help text for the flag.
  final String help;

  /// Whether the flag can be negated as `--no-<name>`.
  final bool negatable;

  /// Whether the flag takes a value (`--name=value`).
  final bool takesValue;

  /// Default value when the flag is absent.
  final Object? defaultsTo;
}

/// A declarative CLI command (FR-003).
///
/// Construct one with [StandardCommand.new] and register it with a
/// [CommandRegistry]. The handler is invoked with an [CliInvocation] carrying
/// the parsed arguments and flags; it returns a [CommandResult] that
/// [CliApp] translates into the contract exit code and output format.
///
/// This is the contract every Zuraffa CLI command follows: a name, a
/// description, a list of positional arguments, a list of named flags, and a
/// handler. No subclassing required.
@immutable
class StandardCommand {
  const StandardCommand({
    required this.name,
    required this.description,
    this.arguments = const [],
    this.flags = const [],
    required this.handler,
    this.aliases = const [],
  });

  /// The command name as typed on the CLI (e.g. `greet`).
  final String name;

  /// One-line description shown on the help screen.
  final String description;

  /// Positional argument declarations. May be empty.
  final List<CommandArgument> arguments;

  /// Named flag declarations. May be empty.
  final List<CommandFlag> flags;

  /// Aliases for the command (e.g. `g` for `greet`).
  final List<String> aliases;

  /// The handler invoked when the command is dispatched. Receives the parsed
  /// [CliInvocation] and returns a [CommandResult].
  final Future<CommandResult> Function(CliInvocation) handler;
}
