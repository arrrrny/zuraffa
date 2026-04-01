import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/generator_options.dart';
import '../plugins/controller/controller_plugin.dart';
import '../plugins/datasource/datasource_plugin.dart';
import '../plugins/di/di_plugin.dart';
import '../plugins/graphql/graphql_plugin.dart';
import '../plugins/gql/gql_plugin.dart';
import '../plugins/cache/cache_plugin.dart';
import '../plugins/route/route_plugin.dart';
import '../plugins/provider/provider_plugin.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/observer/observer_plugin.dart';
import '../plugins/test/test_plugin.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/method_append/method_append_plugin.dart';
import '../plugins/presenter/presenter_plugin.dart';
import '../plugins/repository/repository_plugin.dart';
import '../plugins/service/service_plugin.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/feature/feature_plugin.dart';
import '../plugins/shadcn/shadcn_plugin.dart';

class PluginConfig {
  final Set<String> disabled;

  PluginConfig({Set<String>? disabled}) : disabled = disabled ?? {};

  static PluginConfig load({String? projectRoot}) {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(path.join(root, '.zfa.json'));
    if (!configFile.existsSync()) {
      return PluginConfig();
    }
    try {
      final json = jsonDecode(configFile.readAsStringSync());
      if (json is Map<String, dynamic>) {
        final plugins = json['plugins'];
        if (plugins is Map<String, dynamic>) {
          final disabled = plugins['disabled'];
          if (disabled is List) {
            return PluginConfig(
              disabled: disabled.map((e) => e.toString()).toSet(),
            );
          }
        }
        final disabled = json['disabledPlugins'];
        if (disabled is List) {
          return PluginConfig(
            disabled: disabled.map((e) => e.toString()).toSet(),
          );
        }
      }
    } catch (_) {}
    return PluginConfig();
  }

  void save({String? projectRoot}) {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(path.join(root, '.zfa.json'));
    Map<String, dynamic> data = {};
    if (configFile.existsSync()) {
      try {
        final decoded = jsonDecode(configFile.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}
    }
    final plugins = Map<String, dynamic>.from(data['plugins'] ?? {});
    plugins['disabled'] = disabled.toList()..sort();
    data['plugins'] = plugins;
    final encoder = const JsonEncoder.withIndent('  ');
    configFile.writeAsStringSync(encoder.convert(data));
  }
}

class PluginInfo {
  final String id;
  final String name;
  final String version;
  final bool enabled;

  const PluginInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.enabled,
  });
}

class PluginLoader {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final PluginConfig config;

  PluginLoader({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    required this.config,
  });

  PluginRegistry buildRegistry() {
    final registry = PluginRegistry();
    for (final plugin in _plugins()) {
      if (!config.disabled.contains(plugin.id)) {
        registry.register(plugin);
      }
    }
    return registry;
  }

  List<PluginInfo> listPlugins() {
    return _plugins()
        .map(
          (plugin) => PluginInfo(
            id: plugin.id,
            name: plugin.name,
            version: plugin.version,
            enabled: !config.disabled.contains(plugin.id),
          ),
        )
        .toList();
  }

  List<ZuraffaPlugin> _plugins() {
    final options = GeneratorOptions(
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return [
      RepositoryPlugin(outputDir: outputDir, options: options),
      ProviderPlugin(outputDir: outputDir, options: options),
      UseCasePlugin(outputDir: outputDir, options: options),
      PresenterPlugin(outputDir: outputDir, options: options),
      ControllerPlugin(outputDir: outputDir, options: options),
      ViewPlugin(outputDir: outputDir, options: options),
      FeaturePlugin(outputDir: outputDir, options: options),
      StatePlugin(outputDir: outputDir, options: options),
      ObserverPlugin(outputDir: outputDir, options: options),
      TestPlugin(outputDir: outputDir, options: options),
      MockPlugin(outputDir: outputDir, options: options),
      DiPlugin(outputDir: outputDir, options: options),
      DataSourcePlugin(outputDir: outputDir, options: options),
      ServicePlugin(outputDir: outputDir, options: options),
      RoutePlugin(outputDir: outputDir, options: options),
      CachePlugin(outputDir: outputDir, options: options),
      GqlPlugin(outputDir: outputDir, options: options),
      GraphqlPlugin(outputDir: outputDir, options: options),
      ShadcnPlugin(outputDir: outputDir, options: options),
      MethodAppendPlugin(outputDir: outputDir, options: options),
    ];
  }
}
