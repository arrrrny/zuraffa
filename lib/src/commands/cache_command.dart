import 'base_plugin_command.dart';
import 'cache_verify_command.dart';
import '../plugins/cache/cache_plugin.dart';

class CacheCommand extends PluginCommand {
  @override
  final CachePlugin plugin;

  /// `CacheVerifyCommand` is registered manually below; if a future
  /// capability with the same `verify` name is added, its auto-registered
  /// `CapabilityCommand` must be skipped or the duplicate registration
  /// would leave the manual command unparented and crash `cache verify
  /// --help` (issue #761).
  @override
  Set<String> get manualSubcommandNames => const {'verify'};

  CacheCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'policy',
      help: 'Cache policy (daily, hourly, etc.)',
      defaultsTo: 'daily',
    );
    argParser.addOption('storage', help: 'Storage backend (hive, etc.)');
    argParser.addOption('ttl', help: 'Time to live in minutes');
    addSubcommand(CacheVerifyCommand(plugin));
  }

  @override
  String get name => 'cache';

  @override
  String get description => 'Generate Cache logic';

  @override
  Future<void> run() async {
    // Spec #975 (mirrors state_command.dart:25-32 / bug #856): the
    // positional grammar this command's usage strings once advertised
    // (`zfa cache <EntityName>`) is unreachable through the CLI —
    // package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. run() is only reachable through direct
    // (programmatic) invocation, and its only honest behavior is to tell
    // the truth about the grammar, never generate, and signal a usage
    // error. The pre-#975 dead positional path (`argResults!.rest.first`,
    // the RangeError source) is gone.
    reportSubcommandUsage();
  }
}
