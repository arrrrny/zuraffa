import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// A2 / SC-002: `zfa build` route compilation handles 100 annotated Views in
// under 2 seconds (wall clock, syntactic scan path).

void main() {
  test(
    '100 annotated Views compile into one config in under 2 seconds',
    () async {
      final dir = Directory.systemTemp.createTempSync('zfa_route_perf_');
      try {
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: perf_app
environment:
  sdk: ^3.11.0
dependencies:
  go_router: ^14.0.0
''');
        final views = Directory(p.join(dir.path, 'lib', 'views'))
          ..createSync(recursive: true);
        for (var i = 0; i < 100; i++) {
          File(p.join(views.path, 'view_$i.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

@ZfaRoute(path: '/screen$i', deepLinkAware: $i % 2 == 0)
class Screen${i}View {}
''');
        }

        final stage = RouteBuildStage(projectRoot: dir.path);
        final sw = Stopwatch()..start();
        final result = await stage.run();
        sw.stop();

        expect(result.success, isTrue, reason: result.errors.join('\n'));
        expect(result.wroteRouterFile, isTrue);
        final code = File(
          p.join(dir.path, 'lib', 'src', 'routing', 'zfa_router.g.dart'),
        ).readAsStringSync();
        expect(code, contains("path: '/screen0'"));
        expect(code, contains("path: '/screen99'"));
        // SC-002 budget: under 2 seconds for <= 100 Views.
        expect(
          sw.elapsedMilliseconds,
          lessThan(2000),
          reason: 'stage took ${sw.elapsedMilliseconds}ms for 100 Views',
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
