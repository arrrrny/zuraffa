import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/route/route_plugin.dart';

class RouteCommand extends PluginCommand {
  @override
  final RoutePlugin plugin;

  RouteCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
  }

  @override
  String get name => 'route';

  @override
  String get description => 'Generate route definitions for an entity';

  @override
  Future<void> run() async {
    // When invoked WITHOUT a subcommand (`zfa route <Entity>` rather than
    // `zfa route create <Entity>` / `zfa route deep-link <Name>` etc.),
    // behave as `zfa route create <Entity>` for backward compatibility.
    //
    // All capability-specific flags (--path, --scheme, --host, --view,
    // --auto-verify for deep-link; --scheme, --host, --auto-verify for
    // create) are auto-registered on the corresponding CapabilityCommand
    // subcommands (PluginCommand auto-registers each capability as a
    // subcommand, deriving flags from the capability's inputSchema).
    if (argResults!.rest.isEmpty) {
      print('❌ Usage: zfa route <EntityName> [options]');
      print('   Or use a subcommand:');
      print('   zfa route create <EntityName> [options]');
      print('   zfa route custom <Name> [options]');
      print('   zfa route deep-link <Name> --path <path> --scheme <scheme>');
      print('   zfa route shell <Name> --branch <Label>:<path> [--branch ...] [--bottom-nav] [--adaptive]');
      print('                  [--host <host>] [--auto-verify] [--view <View>]');
      return;
    }

    var entityName = argResults!.rest.first;
    var capabilityName = 'create';

    if (argResults!.rest.length > 1) {
      final first = argResults!.rest.first;
      if (first == 'create' || first == 'custom' || first == 'deep-link' || first == 'shell') {
        capabilityName = first;
        entityName = argResults!.rest[1];
      }
    }

    final methods =
        (argResults?['methods'] as String?)?.split(',') ?? ['get', 'update'];

    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == capabilityName,
    );

    final result = await capability.execute({
      'name': entityName,
      'methods': capabilityName == 'custom' ? [] : methods,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate route');
    }
  }
}
