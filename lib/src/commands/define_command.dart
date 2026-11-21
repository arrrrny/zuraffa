import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli/exit_protocol.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../plugins/provider/capabilities/create_provider_capability.dart';
import '../plugins/provider/provider_plugin.dart';
import '../plugins/service/service_plugin.dart';
import '../plugins/usecase/usecase_plugin.dart';
import 'capability_command.dart';
import 'service_create_command.dart';
import 'usecase_create_command.dart';

/// Issue #2114 — the `define` grammar.
///
/// The generation contract advertises `zfa define usecase`,
/// `zfa define service` and `zfa define provider` as the way to define
/// domain/application types without hand-written implementations, but the
/// top-level registry only exposed `usecase create`, `service create` and
/// `provider create` — `zfa define --help` answered exit 2 with
/// `Could not find a command named "define"`.
///
/// This command mounts the EXISTING create grammars under `define`:
///
/// ```text
/// zfa define usecase  <Name> [options]   ≡  zfa usecase create <Name>
/// zfa define service  <Name> [options]   ≡  zfa service create <Name>
/// zfa define provider <Name> [options]   ≡  zfa provider create <Name>
/// ```
///
/// The subcommands are FRESH instances of the create commands, mounted
/// under their `define` name — never the instances the plugin commands
/// own. Two rules of package:args force that shape:
///
///   * a subcommand is bound to ONE parent (the last `addSubcommand` wins),
///     so re-registering a plugin command's own `create` instance here would
///     leave it unparented on the plugin surface and crash that surface's
///     `--help` (issue #761);
///   * every create command is named `create`, so three of them cannot be
///     siblings under one parent at all — each is subclassed only to rename
///     it (`DefineUsecaseCommand`, …), and to print the grammar the user
///     actually typed in its usage hints.
///
/// The plugin instances come from the shared [PluginRegistry] when they are
/// loaded, so `define` and the plugin surfaces generate through the same
/// configured plugins (`outputDir`, options); a registry without them (a
/// plugin-free invocation in a reused runner) falls back to the loader's
/// defaults.
class DefineCommand extends Command<void> {
  /// The loader's default generation root — the same constant the create
  /// commands use, so a fallback plugin writes where the plugin surface
  /// writes.
  static const String fixedOutputDir = 'lib/src';

  final PluginRegistry _registry;

  DefineCommand([PluginRegistry? registry])
    : _registry = registry ?? PluginRegistry.instance {
    addSubcommand(DefineUsecaseCommand(_plugin('usecase', _defaultUsecase)));
    addSubcommand(DefineServiceCommand(_plugin('service', _defaultService)));
    addSubcommand(
      DefineProviderCommand(
        CreateProviderCapability(_plugin('provider', _defaultProvider)),
        pluginId: 'provider',
      ),
    );
  }

  static UseCasePlugin _defaultUsecase() =>
      UseCasePlugin(outputDir: fixedOutputDir);

  static ServicePlugin _defaultService() =>
      ServicePlugin(outputDir: fixedOutputDir);

  static ProviderPlugin _defaultProvider() =>
      ProviderPlugin(outputDir: fixedOutputDir);

  /// The registered plugin of type [T], or [fallback] when the registry
  /// does not carry one — or carries another type under that id, which a
  /// stale registry must not be allowed to turn into a cast crash.
  T _plugin<T extends ZuraffaPlugin>(String id, T Function() fallback) {
    final registered = _registry.getById(id);
    return registered is T ? registered : fallback();
  }

  @override
  String get name => 'define';

  @override
  String get description =>
      'Define domain and application types: zfa define usecase|service|'
      'provider <Name> [options]';

  @override
  String get invocation =>
      'zfa define <usecase|service|provider> <Name> [arguments]';

  @override
  Future<void> run() async {
    // `define` is a group, not a generator: package:args only reaches
    // run() when no subcommand was given, so the honest answer is the
    // grammar plus a usage exit (bug #856 family).
    print('❌ Usage: zfa define <usecase|service|provider> <Name> [arguments]');
    print('   Run `zfa define --help` to list the definition grammars.');
    print(
      ExitProtocol.fixLine(
        'pick a definition grammar — `zfa define usecase|service|provider '
        '--help` — then re-invoke',
      ),
    );
    exitCode = ExitProtocol.usage;
  }
}

/// `zfa define usecase <Name>` — the [UseCaseCreateCommand] grammar under
/// the define group.
class DefineUsecaseCommand extends UseCaseCreateCommand {
  DefineUsecaseCommand(super.plugin);

  @override
  String get name => 'usecase';

  @override
  String get description =>
      'Define a Clean Architecture UseCase — the `zfa define usecase` form '
      'of `zfa usecase create`';

  @override
  String get invocation => 'zfa define usecase <EntityName> [options]';

  @override
  String get usagePrefix => 'zfa define usecase';
}

/// `zfa define service <Name>` — the [ServiceCreateCommand] grammar under
/// the define group.
class DefineServiceCommand extends ServiceCreateCommand {
  DefineServiceCommand(super.plugin, {super.projectRoot});

  @override
  String get name => 'service';

  @override
  String get description =>
      'Define a Service interface — the `zfa define service` form of '
      '`zfa service create`';

  @override
  String get invocation => 'zfa define service <ServiceName> [options]';

  @override
  String get usagePrefix => 'zfa define service';
}

/// `zfa define provider <Name>` — the provider create capability under the
/// define group.
class DefineProviderCommand extends CapabilityCommand {
  DefineProviderCommand(super.capability, {super.pluginId, super.projectRoot});

  @override
  String get name => 'provider';

  @override
  String get description =>
      'Define a Provider — the `zfa define provider` form of '
      '`zfa provider create`';

  @override
  String get invocation => 'zfa define provider <Name> [options]';
}
