import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

/// Configuration for ZFA CLI
///
/// Supports default settings via .zfa.json in project root
class ZfaConfig {
  /// Default entity generation uses Zorphy
  final bool useZorphyByDefault;

  /// Default JSON serialization for entities
  final bool jsonByDefault;

  /// Default compareTo generation
  final bool compareByDefault;

  /// Default output directory for entities
  final String? defaultEntityOutput;

  /// Default GraphQL generation for entity-based operations
  final bool generateGql;

  const ZfaConfig({
    this.useZorphyByDefault = true,
    this.jsonByDefault = true,
    this.compareByDefault = true,
    this.defaultEntityOutput,
    this.generateGql = false,
  });

  /// Load configuration from .zfa.json in project root
  static ZfaConfig? load({String? projectRoot}) {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    if (!configFile.existsSync()) {
      return null;
    }

    try {
      final content = configFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      return ZfaConfig(
        useZorphyByDefault: json['useZorphyByDefault'] ?? true,
        jsonByDefault: json['jsonByDefault'] ?? true,
        compareByDefault: json['compareByDefault'] ?? true,
        defaultEntityOutput: json['defaultEntityOutput'],
        generateGql: json['generateGql'] ?? false,
      );
    } catch (e) {
      // Return defaults if config is invalid
      return const ZfaConfig();
    }
  }

  /// Save configuration to .zfa.json
  static Future<void> save(ZfaConfig config, {String? projectRoot}) async {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    final configJson = {
      'useZorphyByDefault': config.useZorphyByDefault,
      'jsonByDefault': config.jsonByDefault,
      'compareByDefault': config.compareByDefault,
      if (config.defaultEntityOutput != null)
        'defaultEntityOutput': config.defaultEntityOutput,
    };

    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(configJson);
    await configFile.writeAsString(content);
  }

  /// Create a config file template in project root
  static Future<void> init({String? projectRoot}) async {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    if (configFile.existsSync()) {
      print('ℹ️  Configuration file already exists: ${configFile.path}');
      return;
    }

    const defaultConfig = ZfaConfig();
    await save(defaultConfig, projectRoot: root);
    print('✅ Created configuration file: ${configFile.path}');
    print('   You can customize defaults in .zfa.json');
  }
}
