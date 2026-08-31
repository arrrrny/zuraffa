import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/dda/plugins/route/route_build_stage.dart';
import 'package:zuraffa/src/feature_flags/feature_flag_config.dart';

/// U7 — RouteBuildStage drops @Route hits owned by disabled features
/// (normalized name match on class name / file path) from the router emit.
void main() {
  late Directory sandbox;

  Directory makeProject() {
    final dir = Directory.systemTemp.createTempSync('zfa_flag_routes_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: flag_route_app
environment:
  sdk: ^3.11.0
dependencies:
  go_router: ^14.0.0
''');
    Directory(p.join(dir.path, 'lib', 'views')).createSync(recursive: true);
    return dir;
  }

  void writeView(String fileName, String source) {
    File(p.join(sandbox.path, 'lib', 'views', fileName)).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

$source
''');
  }

  String routerPath() =>
      p.join(sandbox.path, 'lib', 'src', 'routing', 'zfa_router.g.dart');

  setUp(() {
    sandbox = makeProject();
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test(
    'disabled feature route is dropped, enabled feature route survives',
    () async {
      writeView('pro_analytics_view.dart', '''
@ZfaRoute(path: '/pro-analytics')
class ProAnalyticsView {}
''');
      writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');

      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
        ],
        'flavors': {
          'free': {'pro-analytics': false},
        },
      });
      final freeSet = config.resolve(flavor: 'free');

      final stage = RouteBuildStage(
        projectRoot: sandbox.path,
        featureSet: freeSet,
      );
      final result = await stage.run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains("path: '/home'"), reason: 'free route survives');
      expect(
        code,
        isNot(contains('/pro-analytics')),
        reason: 'disabled feature route must leave no trace (SC-001)',
      );
    },
  );

  test('enabled flavor keeps both routes', () async {
    writeView('pro_analytics_view.dart', '''
@ZfaRoute(path: '/pro-analytics')
class ProAnalyticsView {}
''');
    writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');

    final config = FeatureFlagConfig.fromJson(const {
      'features': [
        {'name': 'pro-analytics', 'enabled': true},
      ],
    });
    final allSet = config.resolve();

    final result = await RouteBuildStage(
      projectRoot: sandbox.path,
      featureSet: allSet,
    ).run();

    expect(result.success, isTrue, reason: result.errors.join('\n'));
    final code = File(routerPath()).readAsStringSync();
    expect(code, contains("path: '/home'"));
    expect(code, contains("path: '/pro-analytics'"));
  });

  test('no feature set passed -> behavior unchanged (no filtering)', () async {
    writeView('pro_analytics_view.dart', '''
@ZfaRoute(path: '/pro-analytics')
class ProAnalyticsView {}
''');

    final result = await RouteBuildStage(projectRoot: sandbox.path).run();

    expect(result.success, isTrue, reason: result.errors.join('\n'));
    expect(
      File(routerPath()).readAsStringSync(),
      contains("path: '/pro-analytics'"),
    );
  });

  test('feature names match only at path-segment boundaries', () {
    const set = ResolvedFeatureSet(enabled: {}, disabled: {'pro'}, gates: {});

    expect(
      RouteBuildStage.isOwnedByDisabledFeature('profile_view.dart', set),
      isFalse,
    );
    expect(
      RouteBuildStage.isOwnedByDisabledFeature('lib/views/pro_view.dart', set),
      isTrue,
    );
  });
}
