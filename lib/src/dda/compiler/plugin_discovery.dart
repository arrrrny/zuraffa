import 'dart:io';

import 'package:yaml/yaml.dart';

import 'zorphy_decorator_plugin.dart';

/// Discovers and loads [ZorphyDecoratorPlugin]s from packages listed in
/// `pubspec.yaml` under the `zuraffa_decorators` key.
class PluginDiscovery {
  PluginDiscovery({required this.projectRoot});

  final String projectRoot;

  /// Load all decorator plugins from the project's pubspec.yaml.
  List<ZorphyDecoratorPlugin> discover() {
    final pubspecPath = '$projectRoot/pubspec.yaml';
    final file = File(pubspecPath);
    if (!file.existsSync()) {
      throw PluginDiscoveryError('pubspec.yaml not found at $pubspecPath');
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;
    if (yaml == null) {
      throw PluginDiscoveryError('Failed to parse pubspec.yaml');
    }

    final decoratorPackages = yaml['zuraffa_decorators'];
    if (decoratorPackages == null) return [];

    if (decoratorPackages is! YamlList) {
      throw PluginDiscoveryError(
        'zuraffa_decorators must be a list of package names',
      );
    }

    final plugins = <ZorphyDecoratorPlugin>[];
    for (final packageName in decoratorPackages) {
      if (packageName is! String) {
        _warn('zuraffa_decorators entry "$packageName" is not a string');
        continue;
      }
      try {
        final loaded = _loadPackagePlugins(packageName);
        plugins.addAll(loaded);
      } on PluginDiscoveryError catch (e) {
        _warn('Failed to load decorator package "$packageName": $e');
      }
    }
    return plugins;
  }

  List<ZorphyDecoratorPlugin> _loadPackagePlugins(String packageName) {
    throw PluginDiscoveryError(
      'Dynamic decorator package loading is not yet implemented '
      '(planned for Track 5.x). Register plugins manually via '
      'ZorphyPluginRegistry.register() in your main library.',
    );
  }

  void _warn(String message) {
    // ignore: avoid_print
    print('[zfa warn] $message');
  }
}

class PluginDiscoveryError implements Exception {
  PluginDiscoveryError(this.message);
  final String message;

  @override
  String toString() => 'PluginDiscoveryError: $message';
}
