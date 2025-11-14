import 'package:test/test.dart';
import 'package:zuraffa/src/build_yaml_generator.dart';

void main() {
  late BuildYamlGenerator generator;

  setUp(() {
    generator = BuildYamlGenerator();
  });

  group('BuildYamlGenerator - Generation', () {
    test('should generate valid build.yaml content', () {
      final content = generator.generateBuildYaml();

      expect(content, contains('targets:'));
      expect(content, contains('\$default:'));
      expect(content, contains('morphy_builder:'));
      expect(content, contains('enabled: true'));
      expect(content, contains('lib/src/domain/entities/*.dart'));
      expect(content, contains('generate_json: true'));
    });

    test('should include source_gen combining_builder', () {
      final content = generator.generateBuildYaml();

      expect(content, contains('source_gen|combining_builder'));
    });

    test('should include global options', () {
      final content = generator.generateBuildYaml();

      expect(content, contains('global_options:'));
      expect(content, contains('morphy_builder:'));
    });
  });

  group('BuildYamlGenerator - Detection', () {
    test('should detect when build.yaml is needed (null content)', () {
      final needsIt = generator.needsBuildYaml(null);
      expect(needsIt, true);
    });

    test('should detect when build.yaml is needed (empty content)', () {
      final needsIt = generator.needsBuildYaml('');
      expect(needsIt, true);
    });

    test('should detect when build.yaml is NOT needed (has morphy_builder)', () {
      const existing = '''
targets:
  \$default:
    builders:
      morphy_builder:
        enabled: true
''';
      final needsIt = generator.needsBuildYaml(existing);
      expect(needsIt, false);
    });

    test('should detect when build.yaml is NOT needed (has entity path)', () {
      const existing = '''
targets:
  \$default:
    builders:
      some_builder:
        generate_for:
          - lib/src/domain/entities/*.dart
''';
      final needsIt = generator.needsBuildYaml(existing);
      expect(needsIt, false);
    });

    test('should detect when build.yaml needs update (missing morphy config)', () {
      const existing = '''
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
''';
      final needsIt = generator.needsBuildYaml(existing);
      expect(needsIt, true);
    });
  });

  group('BuildYamlGenerator - Merging', () {
    test('should merge Morphy config into existing build.yaml', () {
      const existing = '''
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
''';

      final merged = generator.mergeBuildYaml(existing);

      expect(merged, contains('json_serializable'));
      expect(merged, contains('morphy_builder'));
      expect(merged, contains('Added by Zuraffa'));
    });

    test('should not duplicate morphy_builder if already exists', () {
      const existing = '''
targets:
  \$default:
    builders:
      morphy_builder:
        enabled: true
''';

      final merged = generator.mergeBuildYaml(existing);

      // Should return as-is without duplication
      expect(merged, equals(existing));
    });

    test('should preserve existing content when merging', () {
      const existing = '''
# My custom build config
targets:
  \$default:
    builders:
      some_builder:
        options:
          custom: true
''';

      final merged = generator.mergeBuildYaml(existing);

      expect(merged, contains('# My custom build config'));
      expect(merged, contains('some_builder'));
      expect(merged, contains('custom: true'));
      expect(merged, contains('morphy_builder'));
    });
  });

  group('BuildYamlGenerator - Integration', () {
    test('should generate content that is valid YAML structure', () {
      final content = generator.generateBuildYaml();

      // Check for proper YAML indentation
      expect(content, contains('targets:'));
      expect(content, contains('  \$default:'));
      expect(content, contains('    builders:'));
      expect(content, contains('      morphy_builder:'));
      expect(content, contains('        enabled: true'));
    });

    test('should include all necessary Morphy configuration', () {
      final content = generator.generateBuildYaml();

      final requiredKeys = [
        'targets',
        '\$default',
        'builders',
        'morphy_builder',
        'enabled: true',
        'generate_for',
        'lib/src/domain/entities/*.dart',
        'options',
        'generate_json: true',
        'source_gen|combining_builder',
        'global_options',
      ];

      for (final key in requiredKeys) {
        expect(content, contains(key),
            reason: 'build.yaml should contain "$key"');
      }
    });
  });
}
