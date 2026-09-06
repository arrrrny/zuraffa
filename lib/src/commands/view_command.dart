import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../models/generated_file.dart';
import '../core/plugin_system/capability.dart';
import 'base_plugin_command.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/route/route_plugin.dart';
import '../config/zfa_config.dart';

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
      'v6-state',
      help:
          'Generate v6 dual-layer state (DomainState + ViewState + '
          'DualLayerPresenter) and ControlledWidget/FragmentBuilder-based view',
      defaultsTo: false,
    );
    argParser.addFlag(
      'route',
      help: 'Generate route definitions for this view',
      defaultsTo: false,
    );
    argParser.addFlag(
      'xray',
      help: 'Generate with X-Ray integration',
      defaultsTo: false,
    );
    argParser.addFlag(
      'skin',
      help:
          'Generate with the runtime skin-contract auditor wrap (issue '
          '#1102): the view getter mounts SkinContractAuditor with a '
          'starter k<ViewName>SkinRows contract, and the auditor kit '
          '(skin/skin_contract_auditor.dart) is emitted when missing.',
      defaultsTo: false,
    );
  }

  /// SPEC 917 / #876 sweep: run()'s programmatic positional path reads
  /// every parent-level flag listed below — they are LIVE, declared here so
  /// `zfa manifest --verify` certifies them instead of flagging them dead
  /// (spec #979).
  @override
  Set<String> get consumedParentFlags => const {
    'di',
    'methods',
    'route',
    'skin',
    'state',
    'v6-state',
    'xray',
  };

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      reportSubcommandUsage();
      return;
    }

    var entityName = argResults!.rest.first;
    var capabilityName = 'create';

    if (argResults!.rest.length > 1) {
      final first = argResults!.rest.first;
      if (first == 'create' || first == 'custom' || first == 'register') {
        capabilityName = first;
        entityName = argResults!.rest[1];
      }
    }

    final methods =
        (argResults?['methods'] as String?)?.split(',') ?? ['get', 'update'];
    final generateDi = argResults?['di'] as bool? ?? false;
    final generateState = argResults?['state'] as bool? ?? false;
    final generateV6State = argResults?['v6-state'] as bool? ?? false;
    final generateRoute = argResults?['route'] as bool? ?? false;
    final config = ZfaConfig.load();
    final generateXRay = argResults!.wasParsed('xray')
        ? (argResults?['xray'] as bool? ?? false)
        : (config?.xrayByDefault ?? false);
    final generateSkin = argResults?['skin'] as bool? ?? false;

    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == capabilityName,
    );

    if (capabilityName == 'register') {
      final entities = argResults!.rest.skip(2).toList();
      // Issue #1138: wrapper-persisted proof.v1 receipt (best-effort).
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: plugin.id,
      );
      final result = await wrapper.execute({
        'target': entityName,
        'entities': entities,
        'dryRun': isDryRun,
        'force': isForce,
        'verbose': isVerbose,
        'outputDir': outputDir,
      });

      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
      return;
    }

    if (generateRoute) {
      // For route generation, execute the route command separately
      // to ensure clean view instantiation without DI
      final routeResult = await _generateRoutes(entityName, capabilityName);

      // Generate view
      // Issue #1138: wrapper-persisted proof.v1 receipt (best-effort).
      final viewWrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: plugin.id,
      );
      final viewResult = await viewWrapper.execute({
        'name': entityName,
        'methods': methods,
        'di': generateDi,
        'state': generateState,
        'v6-state': generateV6State,
        'route': false, // Don't generate route in view capability
        'xray': generateXRay,
        'skin': generateSkin,
        'dryRun': isDryRun,
        'force': isForce,
        'verbose': isVerbose,
        'outputDir': outputDir,
      });

      // Combine results
      final allFiles = <GeneratedFile>[];
      // Bug #1139 (exit-code sweep, #856 pattern): a failed capability run
      // is a failure — the process must never exit 0 after reporting it.
      final routeFailed =
          routeResult is ExecutionResult && !routeResult.success;
      if (!viewResult.success || routeFailed) {
        print(
          '❌ Failed to generate view and routes: '
          '${viewResult.message ?? routeResult?.message ?? "unknown error"}',
        );
        exitCode = 1;
        return;
      }
      if (viewResult.data?['generatedFiles'] != null) {
        allFiles.addAll(viewResult.data!['generatedFiles']);
      }
      if (routeResult?.data?['generatedFiles'] != null) {
        allFiles.addAll(routeResult?.data!['generatedFiles']);
      }

      print('\n✅ Generated view and routes successfully!');
      logSummary(allFiles);
    } else {
      // Generate only view
      // Issue #1138: wrapper-persisted proof.v1 receipt (best-effort).
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: plugin.id,
      );
      final result = await wrapper.execute({
        'name': entityName,
        'methods': methods,
        'di': generateDi,
        'state': generateState,
        'v6-state': generateV6State,
        'route': false,
        'xray': generateXRay,
        'skin': generateSkin,
        'dryRun': isDryRun,
        'force': isForce,
        'verbose': isVerbose,
        'outputDir': outputDir,
      });

      // Bug #1139 (exit-code sweep, #856 pattern): a failed generation is a
      // failure — the process must never exit 0 after printing an error.
      if (!result.success) {
        print(
          '❌ Failed to generate view: ${result.message ?? "unknown error"}',
        );
        exitCode = 1;
        return;
      }

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

    // Issue #1138: the route capability runs as its own standalone
    // invocation here — persist its own proof.v1 receipt under the
    // route plugin id (best-effort inside the wrapper).
    final wrapper = CapabilityInvocationWrapper(
      capability: routeCapability,
      pluginId: routePlugin.id,
    );
    final result = await wrapper.execute({
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
