// SPDX-License-Identifier: MIT
//
// Public API for the standard CLI plugin (018-cli-plugin).
//
// Apps import this barrel to access the standardized CLI surface:
//
//   import 'package:zuraffa/src/cli/standard/standard.dart';
//
// All exports below are pure-Dart (FR-012): no `package:flutter` import
// anywhere in this subdirectory.

// The contract.
export 'cli_contract.dart'
    show CliContract, CliExitCodes, CliGlobalFlag, CliGlobalFlags;

// The declarative command model.
export 'command_model.dart'
    show
        CommandResult,
        SuccessResult,
        ErrorResult,
        WarningResult,
        CliInvocation,
        CommandArgument,
        CommandFlag,
        StandardCommand;

// The shared command registry.
export 'command_registry.dart'
    show CommandRegistry, RegisteredCommand, RegistryKey;

// Cross-app invocation.
export 'cross_app_invoker.dart' show CrossAppInvoker;

// Shared command definitions.
export 'shared_command.dart' show SharedCommand;

// DI binding.
export 'di_binding.dart'
    show DiBinding, DiContainer, DependencyRequest, BoundInvocation;

// Output formatting.
export 'output_format.dart' show OutputFormat, OutputFormatKind;

// Edge-case exceptions.
export 'edge_cases.dart'
    show
        CliEdgeCaseException,
        UnknownCommandException,
        AmbiguousCommandException,
        ReferencedAppMissingException,
        CircularReferenceException,
        VersionMismatchException,
        NonInteractiveContextException,
        CommandAlreadyRegistered,
        BindingException;

// The standardized entry point.
export 'cli_app.dart' show CliApp, CliUsageException;

// The plugin metadata (FR-010).
export 'cli_plugin.dart' show CliPlugin;
