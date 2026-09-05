// Regression tests for the CI reporter drift fix: package:test silently
// switches to its `github` reporter when `GITHUB_ACTIONS=true` (every
// Actions runner), which drops the compact `mm:ss +N:` progress lines the
// TDD transcript machinery parses and injects `::group::`/`::error`
// markers the load-failure classifier reads as CFE noise. Every spawned
// `dart test` / `flutter test` must pin `--reporter compact` so
// transcripts are identical on a laptop and inside Actions.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_reporter_args.dart';

void main() {
  group('withCompactReporter pins the deterministic reporter', () {
    test('dart test gains --reporter compact right after the verb', () {
      expect(
        withCompactReporter([
          'dart',
          'test',
          'test/tdd/demo/a1_test.dart',
          '-n',
          'A1 — demo',
        ]),
        [
          'dart',
          'test',
          '--reporter',
          'compact',
          'test/tdd/demo/a1_test.dart',
          '-n',
          'A1 — demo',
        ],
      );
    });

    test('flutter test gains it too', () {
      final out = withCompactReporter(['flutter', 'test', 'x_test.dart']);
      expect(out.sublist(0, 4), ['flutter', 'test', '--reporter', 'compact']);
    });

    test('an existing --reporter flag wins (not duplicated)', () {
      final tokens = ['dart', 'test', '--reporter', 'expanded', 'a_test.dart'];
      expect(withCompactReporter(tokens), same(tokens));
    });

    test('an existing --reporter= form wins', () {
      final tokens = ['dart', 'test', '--reporter=json', 'a_test.dart'];
      expect(withCompactReporter(tokens), same(tokens));
    });

    test('a -r shorthand wins', () {
      final tokens = ['dart', 'test', '-r', 'json', 'a_test.dart'];
      expect(withCompactReporter(tokens), same(tokens));
    });

    test('flags after a bare -- separator are not inspected', () {
      final out = withCompactReporter([
        'dart',
        'test',
        '--',
        '-r',
        'a_test.dart',
      ]);
      expect(out, [
        'dart',
        'test',
        '--reporter',
        'compact',
        '--',
        '-r',
        'a_test.dart',
      ]);
    });

    test('non-test commands pass through untouched', () {
      final tokens = ['dart', 'analyze', 'lib'];
      expect(withCompactReporter(tokens), same(tokens));
    });

    test('a bare executable passes through untouched', () {
      final tokens = ['dart'];
      expect(withCompactReporter(tokens), same(tokens));
    });

    test('an executable that merely ends in dart still pins', () {
      final out = withCompactReporter([
        '/usr/local/bin/dart',
        'test',
        'a_test.dart',
      ]);
      expect(out[2], '--reporter');
      expect(out[3], 'compact');
    });
  });
}
