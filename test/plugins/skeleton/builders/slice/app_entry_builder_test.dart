/// Tests for AppEntryBuilder (042 working slice, --flutter mode).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U28: pubspec minimal: environment + flutter SDK deps only
///   042-U29: main.dart builds the DI container and runs the app
library;

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/slice/app_entry_builder.dart';

void main() {
  group('AppEntryBuilder (042)', () {
    final builder = AppEntryBuilder();

    test(
      '042-U28: pubspec is minimal — environment + flutter SDK deps only',
      () {
        final pubspec = builder.buildPubspec('profile-feature');
        final parsed = loadYaml(pubspec) as Map;

        expect(parsed['name'], equals('profile_feature_bone'));
        expect(parsed['publish_to'], equals('none'));

        final environment = parsed['environment'] as Map;
        expect(environment.containsKey('sdk'), isTrue);
        expect(environment.containsKey('flutter'), isTrue);

        final dependencies = parsed['dependencies'] as Map;
        expect(dependencies.keys, equals(['flutter']));
        expect(dependencies['flutter'], equals({'sdk': 'flutter'}));

        final devDependencies = parsed['dev_dependencies'] as Map;
        expect(devDependencies.keys, equals(['flutter_test']));
        expect(
          devDependencies['flutter_test'],
          equals({'sdk': 'flutter'}),
        );
      },
    );

    test('042-U28: pubspec name strips digit prefixes from the slug', () {
      final pubspec = builder.buildPubspec('042-bone-working-slice');
      final parsed = loadYaml(pubspec) as Map;
      expect(parsed['name'], equals('bone_working_slice_bone'));
    });

    test(
      '042-U29: main.dart builds the DI container and launches the page',
      () {
        final main = builder.buildMainDart('profile-feature');
        expect(main, contains("import 'package:flutter/material.dart'"));
        expect(main, contains("import '../di/injection.dart'"));
        expect(
          main,
          contains("import '../presentation/profile_feature_page.dart'"),
        );
        expect(main, contains('void main()'));
        expect(main, contains('ProfileFeatureServices.create()'));
        expect(main, contains('runApp('));
        expect(main, contains('MaterialApp'));
        expect(main, contains('ProfileFeaturePage'));
      },
    );
  });
}
