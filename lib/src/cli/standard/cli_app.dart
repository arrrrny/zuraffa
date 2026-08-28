// SPDX-License-Identifier: MIT
//
// CliApp — the standardized entry point for Zuraffa CLI apps (FR-001).
//
// A [CliApp] is constructed with a name, a version, a [CliContract], and a
// [CommandRegistry]. Its single method [run] parses the args vector,
// dispatches to the appropriate registered command, runs the handler, and
// returns the contract exit code. Output is emitted to stdout/stderr in the
// format dictated by the contract (text or JSON) (FR-008).
//
// Edge cases (FR-009) are handled here: unknown command, ambiguous name,
// missing referenced app, circular reference, version mismatch, non-interactive
// context. Each maps to a specific exit code from [CliContract.exitCode].
//
// Pure-Dart (FR-012): no `package:flutter` import anywhere in this file.

import 'dart:async';
import 'dart:io' as io;

import 'cli_contract.dart';
import 'command_model.dart';
import 'command_registry.dart';
import 'edge_cases.dart';
import 'output_format.dart';

/// The standardized entry point for a Zuraffa CLI app (FR-001).
///
/// Construct one at app startup, register commands into its [registry], then
/// call [run] from `main()`. The exit code returned by [run] is the value
/// `main()` should pass to `dart:io`'s `exit()` (or, in tests, just return).
///
/// Apps that want to coexist with the existing [CliRunner] (e.g. for
/// migration) can do so — `CliApp` does not subclass `CliRunner` and does
/// not interfere with it.
class CliApp {
  /// Construct a [CliApp] with the standard contract and an empty registry.
  ///
  /// Most apps will use [CliApp.withStandardContract] and then call
  /// [register] for each command.
  CliApp({
    required this.name,
    required this.version,
    CliContract? contract,
    CommandRegistry? registry,
    this.stdout,
    this.stderr,
  })  : contract = contract ?? CliContract.standard,
        registry = registry ?? CommandRegistry();

  /// Construct with the standard contract and a pre-built registry.
  CliApp.withStandardContract({
    required this.name,
    required this.version,
    CommandRegistry? registry,
    this.stdout,
    this.stderr,
  })  : contract = CliContract.standard,
        registry = registry ?? CommandRegistry();

  /// The app name (shown in `--version` and the help header).
  final String name;

  /// The app version (shown in `--version`).
  final String version;

  /// The contract this app honors.
  final CliContract contract;

  /// The registry of registered commands.
  final CommandRegistry registry;

  /// The stdout sink to write to. Defaults to the process [Stdout] when null.
  /// Tests may inject a [StringBuffer] to capture output.
  final StringSink? stdout;

  /// The stderr sink to write to. Defaults to the process [Stderr] when null.
  final StringSink? stderr;

  /// The owner-app name used when registering commands via [register].
  /// Defaults to [name]; override by passing `ownerApp:` to [register].
  String get defaultOwnerApp => name;

  /// Register a command under `(defaultOwnerApp, command.name)`.
  ///
  /// Throws [CommandAlreadyRegistered] if the key is already taken.
  void register(StandardCommand command, {String? ownerApp, String? version}) {
    registry.register(
      command,
      ownerApp: ownerApp ?? defaultOwnerApp,
      version: version ?? '0.1.0',
    );
  }

  /// Run the CLI with the given args vector. Returns the exit code.
  ///
  /// The exit code follows [CliContract.exitCode]:
  /// - 0 success (`--help`, `--version`, or a successful handler)
  /// - 64 usage error (bad args, missing required arg, unknown flag)
  /// - 1 runtime error (handler threw a non-edge-case exception)
  /// - 2 not found (unknown command — FR-009 edge case 1)
  /// - 3 conflict (ambiguous name — FR-009 edge case 2)
  /// - 4 version mismatch (FR-009 edge case 5)
  /// - 5 circular reference (FR-009 edge case 4)
  Future<int> run(List<String> args) async {
    final out = stdout ?? io.stdout;
    final err = stderr ?? io.stderr;
    final fmt = OutputFormat();

    // Empty args → print help, exit 0.
    if (args.isEmpty) {
      _printHelp(out);
      return contract.exitCode.success;
    }

    // `--version` / `-v` as the sole arg → print version, exit 0.
    if (_isVersion(args)) {
      out.writeln('$name v$version');
      return contract.exitCode.success;
    }

    // `--help` / `-h` as the sole arg → print help, exit 0.
    if (_isHelp(args)) {
      _printHelp(out);
      return contract.exitCode.success;
    }

    // Strip global flags from the front of the args vector before parsing.
    // The first non-flag token is the command name; the rest is the
    // command's args + flags.
    final parse = _ParseResult.parse(args, contract: contract, registry: registry);
    if (parse.usageError != null) {
      final result = ErrorResult(
        code: 'usage',
        message: parse.usageError!,
        details: {'args': args},
      );
      _emit(out, err, result, fmt, parse.outputKind);
      return contract.exitCode.usage;
    }

    // Look up the command. If no ownerApp was specified by the user
    // (`<ownerApp> <commandName>`), invoke by name only and let the
    // registry raise an ambiguous-command exception if needed.
    try {
      final result = await _dispatch(parse);
      _emit(out, err, result, fmt, parse.outputKind);
      return result.exitCode;
    } on CliEdgeCaseException catch (e) {
      final result = ErrorResult(
        code: e.code,
        message: e.message,
        details: e.details,
        exitCode: _exitCodeFor(e.code),
      );
      _emit(out, err, result, fmt, parse.outputKind);
      return _exitCodeFor(e.code);
    } catch (e, st) {
      final result = ErrorResult(
        code: 'runtime',
        message: '${e.runtimeType}: $e',
        details: {
          if (parse.verbose) 'stackTrace': st.toString(),
        },
      );
      _emit(out, err, result, fmt, parse.outputKind);
      return contract.exitCode.runtime;
    }
  }

  Future<CommandResult> _dispatch(_ParseResult parse) async {
    if (parse.ownerApp != null) {
      final entry = registry.lookup(parse.ownerApp!, parse.commandName);
      if (entry == null) {
        // Check whether the ownerApp exists at all (FR-009 edge case 3).
        if (registry.enumerateFor(parse.ownerApp!).isEmpty) {
          throw ReferencedAppMissingException(
            ownerApp: parse.ownerApp!,
            registeredApps: registry
                .enumerate()
                .map((c) => c.ownerApp)
                .toSet()
                .toList(growable: false),
          );
        }
        throw UnknownCommandException(
          commandName: parse.commandName,
          ownerApp: parse.ownerApp,
          availableCommands: registry
              .enumerateFor(parse.ownerApp!)
              .map((c) => c.key.toString())
              .toList(growable: false),
        );
      }
      return _invoke(entry, parse);
    }

    // No ownerApp specified — look up by name across all owners.
    final matches = registry.enumerateByName(parse.commandName);
    if (matches.isEmpty) {
      throw UnknownCommandException(
        commandName: parse.commandName,
        availableCommands: registry
            .enumerate()
            .map((c) => c.key.toString())
            .toList(growable: false),
      );
    }
    if (matches.length > 1) {
      throw AmbiguousCommandException(
        commandName: parse.commandName,
        matches: matches.map((m) => m.key.toString()).toList(growable: false),
      );
    }
    return _invoke(matches.first, parse);
  }

  Future<CommandResult> _invoke(
      RegisteredCommand entry, _ParseResult parse) async {
    // Parse the command-specific flags + args.
    final parsedFlags = <String, Object?>{};
    for (final f in entry.command.flags) {
      parsedFlags[f.name] = parse.flagValues[f.name] ?? f.defaultsTo;
    }
    // Validate required positional args (FR-009 usage edge case).
    for (var i = 0; i < entry.command.arguments.length; i++) {
      final arg = entry.command.arguments[i];
      if (arg.required && i >= parse.positionalArgs.length) {
        throw CliUsageException(
          'Missing required argument "${arg.name}" for command '
          '"${entry.command.name}".',
        );
      }
    }
    final invocation = CliInvocation(
      arguments: parse.positionalArgs,
      flags: parsedFlags,
      contract: contract,
    );
    return entry.command.handler(invocation);
  }

  void _emit(
    StringSink out,
    StringSink err,
    CommandResult result,
    OutputFormat fmt,
    OutputFormatKind kind,
  ) {
    final rendered =
        kind == OutputFormatKind.json ? fmt.json(result, contract: contract) : fmt.text(result);
    if (result is ErrorResult) {
      err.writeln(rendered);
    } else {
      out.writeln(rendered);
    }
  }

  void _printHelp(StringSink out) {
    out.writeln('$name v$version');
    out.writeln(contract.helpHeader);
    out.writeln('');
    out.writeln('CORE COMMANDS:');
    final cmds = registry.enumerate();
    if (cmds.isEmpty) {
      out.writeln('  (no commands registered)');
    } else {
      for (final c in cmds) {
        out.writeln('  ${c.key.toString().padRight(28)} ${c.command.description}');
      }
    }
    out.writeln('');
    out.writeln('GLOBAL OPTIONS:');
    for (final f in contract.globalFlags) {
      final abbr = f.abbr.isEmpty ? '' : '-${f.abbr}, ';
      final value = f.takesValue ? '=<value>' : '';
      out.writeln('${'  $abbr${f.name}$value'.padRight(28)} ${f.help}');
    }
    out.writeln('');
    out.writeln('Run "$name <command> --help" for command-specific help.');
  }

  int _exitCodeFor(String code) {
    return switch (code) {
      'success' => contract.exitCode.success,
      'usage' => contract.exitCode.usage,
      'runtime' => contract.exitCode.runtime,
      'notFound' => contract.exitCode.notFound,
      'conflict' => contract.exitCode.conflict,
      'versionMismatch' => contract.exitCode.versionMismatch,
      'circularRef' => contract.exitCode.circularRef,
      _ => contract.exitCode.runtime,
    };
  }

  bool _isVersion(List<String> args) =>
      args.length == 1 &&
      (args[0] == '--version' || args[0] == '-v' || args[0] == 'version');

  bool _isHelp(List<String> args) =>
      args.length == 1 && (args[0] == '--help' || args[0] == '-h');
}

/// A usage error raised internally by [CliApp] when args fail to parse or
/// a required positional arg is missing. Carries no edge-case metadata; the
/// exit code is [CliExitCodes.usage].
class CliUsageException implements Exception {
  const CliUsageException(this.message);
  final String message;
  @override
  String toString() => 'CliUsageException: $message';
}

/// The parsed args vector — extracted from [CliApp.run] for testability.
class _ParseResult {
  _ParseResult({
    this.ownerApp,
    required this.commandName,
    required this.positionalArgs,
    required this.flagValues,
    required this.outputKind,
    required this.verbose,
    this.usageError,
  });

  factory _ParseResult.parse(List<String> args,
      {required CliContract contract, required CommandRegistry registry}) {
    var outputKind = OutputFormatKind.text;
    var verbose = false;
    final rest = <String>[];
    String? usageError;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '--help' || a == '-h') {
        rest.add(a);
      } else if (a == '--verbose') {
        verbose = true;
      } else if (a == '--no-color') {
        // Auto-handled; no-op here. ANSI codes are not emitted in v1.
      } else if (a.startsWith('--output=')) {
        final value = a.substring('--output='.length);
        if (value == 'json') {
          outputKind = OutputFormatKind.json;
        } else if (value == 'text') {
          outputKind = OutputFormatKind.text;
        } else {
          usageError = 'Unknown --output value "$value". Use json or text.';
        }
      } else if (a == '--output') {
        if (i + 1 >= args.length) {
          usageError = '--output requires a value (json or text).';
        } else {
          i++;
          final value = args[i];
          if (value == 'json') {
            outputKind = OutputFormatKind.json;
          } else if (value == 'text') {
            outputKind = OutputFormatKind.text;
          } else {
            usageError = 'Unknown --output value "$value". Use json or text.';
          }
        }
      } else if (a.startsWith('-')) {
        // Unknown global flag — assume it belongs to the command, defer
        // parsing. The command will reject it if it's not declared.
        rest.add(a);
      } else {
        rest.add(a);
      }
    }

    if (rest.isEmpty) {
      return _ParseResult(
        commandName: '',
        positionalArgs: const [],
        flagValues: const {},
        outputKind: outputKind,
        verbose: verbose,
        usageError: usageError ?? 'No command given.',
      );
    }

    // Detect two-token `<ownerApp> <commandName>` form: if the first token
    // is a registered owner app AND there is a second non-flag token, treat
    // the first as ownerApp and the second as commandName. Otherwise the
    // first token is the commandName (invoke-by-name-only).
    String? ownerApp;
    String commandName;
    var positionalStart = 0;
    final first = rest[0];
    final isOwnerApp = registry.enumerateFor(first).isNotEmpty;
    if (isOwnerApp &&
        rest.length >= 2 &&
        !rest[1].startsWith('-') &&
        registry.contains(first, rest[1])) {
      ownerApp = first;
      commandName = rest[1];
      positionalStart = 2;
    } else {
      commandName = first;
      positionalStart = 1;
    }

    final positionalArgs = <String>[];
    final flagValues = <String, Object?>{};
    for (var j = positionalStart; j < rest.length; j++) {
      final t = rest[j];
      if (t.startsWith('--')) {
        if (t.contains('=')) {
          final eq = t.indexOf('=');
          flagValues[t.substring(0, eq)] = t.substring(eq + 1);
        } else if (j + 1 < rest.length && !rest[j + 1].startsWith('-')) {
          flagValues[t] = rest[j + 1];
          j++;
        } else {
          flagValues[t] = true;
        }
      } else {
        positionalArgs.add(t);
      }
    }

    return _ParseResult(
      ownerApp: ownerApp,
      commandName: commandName,
      positionalArgs: positionalArgs,
      flagValues: flagValues,
      outputKind: outputKind,
      verbose: verbose,
      usageError: usageError,
    );
  }

  final String? ownerApp;
  final String commandName;
  final List<String> positionalArgs;
  final Map<String, Object?> flagValues;
  final OutputFormatKind outputKind;
  final bool verbose;
  final String? usageError;
}
