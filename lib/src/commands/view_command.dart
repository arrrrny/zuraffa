import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/view/capabilities/create_view_capability.dart';
import '../plugins/route/route_plugin.dart';
import '../plugins/route/capabilities/create_route_capability.dart';

class ViewCommand extends PluginCommand {
  @override
  final ViewPlugin plugin;

  ViewCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
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
      return;
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');
    final generateDi = argResults!['di'] as bool;
    final generateState = argResults!['state'] as bool;
    final generateRoute = argResults!['route'] as bool;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateViewCapability)
            as CreateViewCapability;

    if (generateRoute) {
      // For route generation, execute the route command separately
      // to ensure clean view instantiation without DI
      final routeResult = await _generateRoutes(entityName);

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

  Future<dynamic> _generateRoutes(String entityName) async {
    // Use route plugin internally instead of external command
    final routePlugin = RoutePlugin(outputDir: outputDir);
    final routeCapability =
        routePlugin.capabilities.firstWhere((c) => c is CreateRouteCapability)
            as CreateRouteCapability;

    final result = await routeCapability.execute({
      'name': entityName,
      'methods': [],
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    return result;
  }
}
