import 'base_plugin_command.dart';
import 'di_verify_command.dart';
import '../plugins/di/di_plugin.dart';

class ModularDiCommand extends PluginCommand {
  /// SPEC 1106 (issue #1106): `verify` is registered manually — the gate
  /// must own `--json` as *JSON output* (the canonical verdict.v1
  /// envelope), while the generic `CapabilityCommand` owns `--json` as
  /// *JSON input*. Same seam cache/route/provider verify took
  /// (the `manualSubcommandNames` hook, issue #761).
  @override
  Set<String> get manualSubcommandNames => const {'verify'};

  ModularDiCommand(super.plugin) {
    // SPEC 917 / #876 sweep: the parent-level generator flags
    // (--domain/--service/--repo/--methods/--usecases/--no-entity/
    // --use-mock) were parsed and advertised but NEVER read — run() is
    // dispatch-only (the live surfaces are `zfa di generate ...` and
    // `zfa di verify`, whose parsers own their flags). Silent parent
    // options are the #876 "flags that lie" family; gone and certified by
    // `zfa manifest --verify` (spec #979).

    // SPEC 1106: the verify gate as a manual subcommand (see
    // [manualSubcommandNames]).
    addSubcommand(DiVerifyCommand(plugin as DiPlugin));
  }

  @override
  String get name => 'di';

  @override
  String get description =>
      'Generate DI registration for a UseCase or Entity via subcommands: '
      'zfa di create <Name> | zfa di register <ClassName> | zfa di verify '
      '(dangling-binding gate).';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa di <Name>`) is unreachable through the CLI —
    // package:args rejects a bare name as a subcommand attempt before run()
    // ever executes. The subcommand grammar is the only live contract
    // (`zfa manifest`): `zfa di create|register`.
    reportSubcommandUsage();
  }
}
