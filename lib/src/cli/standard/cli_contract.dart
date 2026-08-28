// SPDX-License-Identifier: MIT
//
// CliContract — the standardized CLI contract for Zuraffa apps (FR-002).
//
// Every Zuraffa CLI app that adopts the standard CLI plugin MUST honor this
// contract: the same exit-code vocabulary, the same global flag set, the same
// error shape, and the same output schema. The contract is a value type so it
// can be compared across apps for consistency (SC-002).
//
// Pure-Dart (FR-012): no `package:flutter` import anywhere in this file.
// Extends the existing `args`-based CLI conventions at `lib/src/cli/cli_runner.dart`
// rather than introducing a parallel parser.

import 'package:meta/meta.dart';

/// The standardized CLI contract for Zuraffa apps.
///
/// A single instance of this class is the source of truth for the CLI surface
/// every Zuraffa CLI app must present: exit-code vocabulary, global flag set,
/// error shape field list, output schema name, and help layout header.
///
/// Apps may override individual fields (e.g. to add an app-specific global
/// flag), but the defaults are sensible enough that most apps will use
/// [CliContract.standard] verbatim. The consistency surface (SC-002) is the
/// set of fields that two independently built apps are expected to share.
@immutable
class CliContract {
  /// The standard contract used by every Zuraffa CLI app by default.
  ///
  /// Constructed once; reused by every [CliApp] that does not customize the
  /// contract. Two [CliApp] instances built with [CliContract.standard] share
  /// 100% of the consistency surface (SC-002 ≥ 80% target trivially met).
  static const CliContract standard = CliContract._standard();

  const CliContract._standard()
      : exitCode = CliExitCodes.standard,
        globalFlags = CliGlobalFlags.standard,
        errorShapeFields = const ['code', 'message', 'details'],
        outputSchemaName = 'zuraffa.cli.v1',
        helpHeader = 'USAGE:\n  <app> <command> [options]';

  /// Construct a custom contract. Most apps should use [CliContract.standard].
  const CliContract({
    required this.exitCode,
    required this.globalFlags,
    required this.errorShapeFields,
    required this.outputSchemaName,
    required this.helpHeader,
  });

  /// The exit-code vocabulary (FR-002, FR-009).
  ///
  /// Seven codes covering success, usage errors, runtime errors, the four
  /// edge-case failure modes (not found, conflict, version mismatch, circular
  /// reference), and the standard sysexits.h conventions where applicable.
  final CliExitCodes exitCode;

  /// The global flag set every Zuraffa CLI app recognizes (FR-002).
  ///
  /// Five flags: `--help` / `-h`, `--version` / `-v`, `--verbose`,
  /// `--output=<json|text>`, `--no-color`. These appear on every command's
  /// help screen and are parsed before command dispatch.
  final List<CliGlobalFlag> globalFlags;

  /// The fields every error shape MUST carry (FR-002, FR-008).
  ///
  /// Three fields: `code` (one of the [CliExitCodes] names, as a string),
  /// `message` (human-readable), `details` (a map of additional context, may
  /// be empty). When `--output=json`, the error is emitted as a JSON object
  /// with exactly these keys (plus `outcome: 'error'`).
  final List<String> errorShapeFields;

  /// The name of the output schema, for machine-readable consumers (FR-008).
  ///
  /// Used as the `$schema` field in JSON output so a downstream pipeline can
  /// validate the shape. Versioned: `zuraffa.cli.v1` for the initial release.
  final String outputSchemaName;

  /// The header line of the help screen (FR-002).
  ///
  /// Matches the existing `CliRunner._printHelp()` style: a USAGE section
  /// followed by CORE COMMANDS, MODULAR COMMANDS, and OPTIONS sections.
  final String helpHeader;

  /// The consistency surface — the set of field names two contracts must
  /// agree on for SC-002 to pass.
  ///
  /// Two apps with the same [exitCode] vocabulary, [globalFlags] names,
  /// [errorShapeFields], [outputSchemaName], and [helpHeader] meet the SC-002
  /// 80% threshold trivially.
  List<String> get consistencySurface => const [
        'exitCode.success',
        'exitCode.usage',
        'exitCode.runtime',
        'exitCode.notFound',
        'exitCode.conflict',
        'exitCode.versionMismatch',
        'exitCode.circularRef',
        'globalFlags.names',
        'errorShapeFields',
        'outputSchemaName',
        'helpHeader',
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CliContract &&
          exitCode == other.exitCode &&
          _listEq(globalFlags, other.globalFlags) &&
          _listEq(errorShapeFields, other.errorShapeFields) &&
          outputSchemaName == other.outputSchemaName &&
          helpHeader == other.helpHeader;

  @override
  int get hashCode => Object.hash(
        exitCode,
        Object.hashAll(globalFlags),
        Object.hashAll(errorShapeFields),
        outputSchemaName,
        helpHeader,
      );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The exit-code vocabulary for the standard CLI contract (FR-002, FR-009).
@immutable
class CliExitCodes {
  const CliExitCodes({
    required this.success,
    required this.usage,
    required this.runtime,
    required this.notFound,
    required this.conflict,
    required this.versionMismatch,
    required this.circularRef,
  });

  /// The standard exit-code vocabulary used by every Zuraffa CLI app by
  /// default. Apps may override individual codes, but doing so breaks the
  /// SC-002 consistency surface — override at your peril.
  static const CliExitCodes standard = CliExitCodes(
    success: 0,
    usage: 64, // sysexits.h EX_USAGE
    runtime: 1,
    notFound: 2,
    conflict: 3,
    versionMismatch: 4,
    circularRef: 5,
  );

  /// Operation succeeded. Mirrors POSIX convention.
  final int success;

  /// Usage error (bad args, unknown flag, missing required arg). Mirrors
  /// `sysexits.h EX_USAGE` (64).
  final int usage;

  /// Runtime error inside a command handler. The handler threw; the user
  /// should see a stack trace with `--verbose`.
  final int runtime;

  /// The requested command is not registered. Used by
  /// [UnknownCommandException] (FR-009 edge case "unknown / mistyped
  /// command").
  final int notFound;

  /// A name conflict was detected at registration time. Used by
  /// [AmbiguousCommandException] (FR-009 edge case "ambiguous / conflicting
  /// command names").
  final int conflict;

  /// A cross-app invocation referenced a command whose published version is
  /// below the requested minimum. Used by [VersionMismatchException] (FR-009
  /// edge case "version mismatch between sharing apps").
  final int versionMismatch;

  /// A cross-app invocation chain detected a cycle. Used by
  /// [CircularReferenceException] (FR-009 edge case "circular command
  /// references").
  final int circularRef;

  /// The full vocabulary, as a name → code map, for help / introspection.
  Map<String, int> get vocabulary => {
        'success': success,
        'usage': usage,
        'runtime': runtime,
        'notFound': notFound,
        'conflict': conflict,
        'versionMismatch': versionMismatch,
        'circularRef': circularRef,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CliExitCodes &&
          success == other.success &&
          usage == other.usage &&
          runtime == other.runtime &&
          notFound == other.notFound &&
          conflict == other.conflict &&
          versionMismatch == other.versionMismatch &&
          circularRef == other.circularRef;

  @override
  int get hashCode => Object.hash(
        success,
        usage,
        runtime,
        notFound,
        conflict,
        versionMismatch,
        circularRef,
      );
}

/// A global flag specification (FR-002).
@immutable
class CliGlobalFlag {
  const CliGlobalFlag({
    required this.name,
    required this.abbr,
    required this.help,
    required this.negatable,
    this.takesValue = false,
  });

  /// The long form, e.g. `--help`.
  final String name;

  /// The short form, e.g. `h` (renders as `-h`). Empty string if no abbreviation.
  final String abbr;

  /// The help text shown on the help screen.
  final String help;

  /// Whether the flag can be negated as `--no-<name>` (e.g. `--no-color`).
  final bool negatable;

  /// Whether the flag takes a value (`--output=json`) or is a boolean
  /// (`--verbose`).
  final bool takesValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CliGlobalFlag &&
          name == other.name &&
          abbr == other.abbr &&
          help == other.help &&
          negatable == other.negatable &&
          takesValue == other.takesValue;

  @override
  int get hashCode => Object.hash(name, abbr, help, negatable, takesValue);
}

/// The standard set of global flags every Zuraffa CLI app recognizes (FR-002).
class CliGlobalFlags {
  /// The five standard flags: `--help`, `--version`, `--verbose`,
  /// `--output`, `--no-color`.
  static const List<CliGlobalFlag> standard = [
    CliGlobalFlag(
      name: '--help',
      abbr: 'h',
      help: 'Show help and exit',
      negatable: false,
    ),
    CliGlobalFlag(
      name: '--version',
      abbr: 'v',
      help: 'Print version and exit',
      negatable: false,
    ),
    CliGlobalFlag(
      name: '--verbose',
      abbr: '',
      help: 'Verbose output (includes stack traces on errors)',
      negatable: false,
    ),
    CliGlobalFlag(
      name: '--output',
      abbr: '',
      help: 'Output format: json or text (default: auto-detect)',
      negatable: false,
      takesValue: true,
    ),
    CliGlobalFlag(
      name: '--no-color',
      abbr: '',
      help: 'Disable ANSI color codes (auto-disabled when stdout is piped)',
      negatable: false,
    ),
  ];

  CliGlobalFlags._(); // prevent instantiation
}
