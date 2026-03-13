import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/route/route_plugin.dart';

class ViewCommand extends PluginCommand {
  @override
  final ViewPlugin plugin;

  ViewCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    argParser.addFlag(
      'di',
      help: 'Generate with DI integration',
      defaultsTo: true,
    );
    argParser.addFlag(
      'state',
      help: 'Generate with State integration',
      defaultsTo: false,
    );
    argParser.addFlag(
      'route',
      help: 'Generate route definitions for this view',
      defaultsTo: false,
    );
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('❌ Usage: zfa view <EntityName> [options]');
      print('   Or use a subcommand:');
      print('   zfa view create <EntityName> [options]');
      print('   zfa view custom <Name> [options]');
      return;
    }

    var entityName = argResults!.rest.first;
    var capabilityName = 'create';

    if (argResults!.rest.length > 1) {
      final first = argResults!.rest.first;
      if (first == 'create' || first == 'custom') {
        capabilityName = first;
        entityName = argResults!.rest[1];
      }
    }

    final methods =
        (argResults?['methods'] as String?)?.split(',') ?? ['get', 'update'];
    final generateDi = argResults?['di'] as bool? ?? false;
    final generateState = argResults?['state'] as bool? ?? false;
    final generateRoute = argResults?['route'] as bool? ?? false;

    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == capabilityName,
    );

    if (generateRoute) {
      // For route generation, execute the route command separately
      // to ensure clean view instantiation without DI
      final routeResult = await _generateRoutes(entityName, capabilityName);

      // Generate view
      final viewResult = await capability.execute({
        'name': entityName,
        'methods': methods,
        'di': generateDi,
        'state': generateState,
        'route': false, // Don't generate route in view capability
        'dryRun': isDryRun,
        'force': isForce,
        'verbose': isVerbose,
        'outputDir': outputDir,
      });

      // Combine results
      final allFiles = <GeneratedFile>[];
      if (viewResult.data?['generatedFiles'] != null) {
        allFiles.addAll(viewResult.data!['generatedFiles']);
      }
      if (routeResult.data?['generatedFiles'] != null) {
        allFiles.addAll(routeResult.data!['generatedFiles']);
      }

      print('\n✅ Generated view and routes successfully!');
      logSummary(allFiles);
    } else {
      // Generate only view
      final result = await capability.execute({
        'name': entityName,
        'methods': methods,
        'di': generateDi,
        'state': generateState,
        'route': false,
        'dryRun': isDryRun,
        'force': isForce,
        'verbose': isVerbose,
        'outputDir': outputDir,
      });

      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    }
  }

  Future<dynamic> _generateRoutes(
    String entityName,
    String capabilityName,
  ) async {
    // Use route plugin internally instead of external command
    final routePlugin = RoutePlugin(outputDir: outputDir);
    final routeCapability = routePlugin.capabilities.firstWhere(
      (c) => c.name == capabilityName,
    );

    // For non-custom capabilities, reuse the same methods list that was parsed
    // for entity-based views. For the "custom" capability, keep an empty list.
    final List<String> routeMethods;
    if (capabilityName == 'custom') {
      routeMethods = <String>[];
    } else {
      final methodsArg = argResults?['methods'] as String? ?? '';
      routeMethods = methodsArg
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();
    }

    final result = await routeCapability.execute({
      'name': entityName,
      'methods': routeMethods,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    return result;
  }
}
