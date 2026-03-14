import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../utils/file_utils.dart';

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

  /// Auto-run dart format after generation by default
  final bool formatByDefault;

  /// Auto-generate routing files when VPC is enabled
  final bool routeByDefault;

  /// Auto-generate DI files
  final bool diByDefault;

  /// Auto-generate mock datasources
  final bool mockByDefault;

  /// Auto-generate unit tests
  final bool testByDefault;

  const ZfaConfig({
    this.zorphyByDefault = true,
    this.jsonByDefault = true,
    this.compareByDefault = true,
    this.filterByDefault = false,
    this.defaultEntityOutput = 'lib/src',
    this.gqlByDefault = false,
    this.buildByDefault = false,
    this.appendByDefault = false,
    this.formatByDefault = false,
    this.routeByDefault = false,
    this.diByDefault = false,
    this.mockByDefault = false,
    this.testByDefault = false,
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
        defaultEntityOutput: json['defaultEntityOutput'] ?? 'lib/src',
        gqlByDefault: json['gqlByDefault'] ?? false,
        buildByDefault: json['buildByDefault'] ?? false,
        appendByDefault: json['appendByDefault'] ?? false,
        formatByDefault: json['formatByDefault'] ?? false,
        routeByDefault: json['routeByDefault'] ?? false,
        diByDefault: json['diByDefault'] ?? false,
        mockByDefault: json['mockByDefault'] ?? false,
        testByDefault: json['testByDefault'] ?? false,
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
      'formatByDefault': config.formatByDefault,
      'routeByDefault': config.routeByDefault,
      'diByDefault': config.diByDefault,
      'mockByDefault': config.mockByDefault,
      'testByDefault': config.testByDefault,
      if (config.defaultEntityOutput != null)
        'defaultEntityOutput': config.defaultEntityOutput,
    };

    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(configJson);
    await FileUtils.writeFile(configFile.path, content, 'config', force: true);
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
