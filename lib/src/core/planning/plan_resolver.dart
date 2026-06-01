import 'package:args/args.dart';

import '../../cli/plugin_loader.dart';
import '../../config/zfa_config.dart';
import '../plugin_system/plugin_interface.dart';
import '../plugin_system/plugin_registry.dart';
import 'generation_plan.dart';
import 'plugin_alias_resolver.dart';
import 'preset_registry.dart';

class PlanResolver {
  final PluginRegistry registry;
  final ZfaConfig? config;
  final PluginConfig? pluginConfig;

  const PlanResolver({required this.registry, this.config, this.pluginConfig});

  GenerationPlan resolve({
    required String name,
    List<String> explicitPluginIds = const [],
    ArgResults? argResults,
    Map<String, dynamic> options = const {},
  }) {
    final normalizedOptions = _normalizeOptions(argResults, options);
    final requestedPluginIds = <String>[];
    final warnings = <String>[];

    final preset = normalizedOptions['preset'] as String?;
    if (preset != null) {
      if (PresetRegistry.hasPreset(
        preset,
        customPresets: config?.customPresets,
      )) {
        requestedPluginIds.addAll(
          PresetRegistry.pluginIdsFor(
            preset,
            customPresets: config?.customPresets,
          ),
        );
      } else {
        warnings.add('Unknown preset "$preset" ignored.');
      }
    }

    requestedPluginIds.addAll(explicitPluginIds);
    requestedPluginIds.addAll(_stringList(normalizedOptions['with']));
    requestedPluginIds.addAll(_selectionFromOptions(normalizedOptions));

    for (final plugin in registry.plugins) {
      if (config?.isPluginEnabledByDefault(plugin.id) == true) {
        requestedPluginIds.add(plugin.id);
      }
    }

    final expandedPluginIds = PluginAliasResolver.expandAll(
      requestedPluginIds,
      customAliases: config?.customAliases,
    );
    final excluded = PluginAliasResolver.expandAll(
      _stringList(normalizedOptions['without']),
      customAliases: config?.customAliases,
    ).toSet();

    if (argResults != null) {
      for (final plugin in registry.plugins) {
        if (argResults.options.contains(plugin.id) &&
            argResults.wasParsed(plugin.id) &&
            argResults[plugin.id] == false) {
          excluded.add(plugin.id);
        }
      }
    }

    final filteredPluginIds = expandedPluginIds
        .where((id) => !excluded.contains(id))
        .where((id) => !(pluginConfig?.disabled.contains(id) ?? false))
        .toList(growable: false);

    final activePlugins = <ZuraffaPlugin>[];
    for (final id in filteredPluginIds) {
      final plugin = registry.getById(id);
      if (plugin == null) {
        warnings.add('Unknown plugin "$id" ignored.');
        continue;
      }
      activePlugins.add(plugin);
    }

    final sortedPlugins = registry.sortPlugins(activePlugins);

    return GenerationPlan(
      name: name,
      preset: preset,
      requestedPluginIds: requestedPluginIds,
      pluginIds: sortedPlugins
          .map((plugin) => plugin.id)
          .toList(growable: false),
      activePlugins: sortedPlugins,
      warnings: warnings,
      normalizedOptions: normalizedOptions,
    );
  }

  Map<String, dynamic> _normalizeOptions(
    ArgResults? argResults,
    Map<String, dynamic> options,
  ) {
    const ignoredKeys = {
      'output',
      'zorphy',
      'domain-root',
      'domain-output',
      'entity-output',
    };

    final normalized = <String, dynamic>{};
    options.forEach((key, value) {
      if (!ignoredKeys.contains(key)) {
        normalized[key] = value;
      }
    });

    if (argResults == null) {
      return normalized;
    }

    for (final key in argResults.options) {
      if (!argResults.wasParsed(key) || ignoredKeys.contains(key)) continue;
      normalized[key] = argResults[key];
    }

    return normalized;
  }

  List<String> _selectionFromOptions(Map<String, dynamic> options) {
    final selection = <String>[];

    if (_isTrue(options['usecase']) ||
        _hasEntityMethods(options) ||
        _isPresent(options['service'])) {
      selection.add('usecase');
    }
    if (_isTrue(options['repository']) || _isTrue(options['data'])) {
      selection.add('repository');
    }
    if (_isTrue(options['datasource']) || _isTrue(options['data'])) {
      selection.add('datasource');
    }
    if (_isTrue(options['service']) ||
        (_isPresent(options['service']) && !_isTrue(options['append'])) ||
        _isTrue(options['use-service'])) {
      selection.add('service');
    }
    if (_isTrue(options['provider']) ||
        _isPresent(options['service']) ||
        _isTrue(options['use-service'])) {
      selection.add('provider');
    }
    if (_isTrue(options['view'])) {
      selection.add('view');
    }
    if (_isTrue(options['presenter'])) {
      selection.add('presenter');
    }
    if (_isTrue(options['controller'])) {
      selection.add('controller');
    }
    if (_isTrue(options['observer'])) {
      selection.add('observer');
    }
    if (_isTrue(options['vpc']) || _isTrue(options['vpcs'])) {
      selection.addAll(['view', 'presenter', 'controller', 'state']);
    }
    if (_isTrue(options['pc'])) {
      selection.addAll(['presenter', 'controller']);
    }
    if (_isTrue(options['pcs'])) {
      selection.addAll(['presenter', 'controller', 'state']);
    }
    if (_isTrue(options['state'])) {
      selection.add('state');
    }
    if (_isTrue(options['test'])) {
      selection.add('test');
    }
    if (_isTrue(options['di'])) {
      selection.add('di');
    }
    if (_isTrue(options['route'])) {
      selection.add('route');
    }
    if (_isTrue(options['mock'])) {
      selection.add('mock');
    }
    if (_isTrue(options['gql'])) {
      selection.add('gql');
    }
    if (_isTrue(options['graphql'])) {
      selection.add('graphql');
    }
    if (_isTrue(options['cache'])) {
      selection.add('cache');
    }
    if (_isTrue(options['append'])) {
      selection.add('method_append');
    }
    if (_isTrue(options['shadcn'])) {
      selection.add('shadcn');
    }

    return selection;
  }

  bool _hasEntityMethods(Map<String, dynamic> options) {
    final methods = _stringList(options['methods']);
    return methods.isNotEmpty && options['no-entity'] != true;
  }

  bool _isTrue(dynamic value) => value == true;

  /// Returns true if the value is a non-null, non-empty string.
  /// Used for options like 'service' that can be either a boolean flag or a string name.
  bool _isPresent(dynamic value) => value is String && value.isNotEmpty;

  List<String> _stringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .expand((element) => element.toString().split(','))
          .map((element) => element.trim())
          .where((element) => element.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((element) => element.trim())
          .where((element) => element.isNotEmpty)
          .toList(growable: false);
    }
    return [value.toString()];
  }
}
