import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

/// Configuration for ZFA CLI
///
/// Supports default settings via .zfa.json in project root
class ZfaConfig {
  /// Default entity generation uses Zorphy
  final bool zorphyByDefault;

  /// Default JSON serialization for entities
  final bool jsonByDefault;

  /// Default compareTo generation
  final bool compareByDefault;

  /// Default filter generation for entities
  final bool filterByDefault;

  /// Default output directory for entities
  final String? defaultEntityOutput;

  /// Default GraphQL generation for entity-based operations
  final bool gqlByDefault;

  /// Auto-run build_runner after entity operations and cache generation
  final bool buildByDefault;

  /// Auto-append to existing repositories/datasources by default
  final bool appendByDefault;

  const ZfaConfig({
    this.zorphyByDefault = true,
    this.jsonByDefault = true,
    this.compareByDefault = true,
    this.filterByDefault = false,
    this.defaultEntityOutput,
    this.gqlByDefault = false,
    this.buildByDefault = false,
    this.appendByDefault = false,
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
        zorphyByDefault: json['zorphyByDefault'] ?? true,
        jsonByDefault: json['jsonByDefault'] ?? true,
        compareByDefault: json['compareByDefault'] ?? true,
        filterByDefault: json['filterByDefault'] ?? false,
        defaultEntityOutput: json['defaultEntityOutput'],
        gqlByDefault: json['gqlByDefault'] ?? false,
        buildByDefault: json['buildByDefault'] ?? false,
        appendByDefault: json['appendByDefault'] ?? false,
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
      'zorphyByDefault': config.zorphyByDefault,
      'jsonByDefault': config.jsonByDefault,
      'compareByDefault': config.compareByDefault,
      'filterByDefault': config.filterByDefault,
      'buildByDefault': config.buildByDefault,
      'appendByDefault': config.appendByDefault,
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
