import 'package:test/test.dart';
import 'package:zuraffa/src/routing/route_params.dart';

void main() {
  group('ZfaRouteParams typed parse helpers', () {
    test('stringParam parses values and falls back', () {
      expect(ZfaRouteParams.stringParam({'q': 'dart'}, 'q'), 'dart');
      expect(
        ZfaRouteParams.stringParam({'q': 'dart'}, 'q', fallback: 'x'),
        'dart',
      );
      expect(ZfaRouteParams.stringParam({}, 'q'), '');
      expect(ZfaRouteParams.stringParam({}, 'q', fallback: 'none'), 'none');
      expect(ZfaRouteParams.stringParam({'q': ''}, 'q', fallback: 'none'), '');
    });

    test('intParam parses ints and falls back', () {
      expect(ZfaRouteParams.intParam({'id': '42'}, 'id'), 42);
      expect(ZfaRouteParams.intParam({'id': '-7'}, 'id'), -7);
      expect(ZfaRouteParams.intParam({}, 'id'), 0);
      expect(ZfaRouteParams.intParam({'id': 'not-a-number'}, 'id'), 0);
      expect(
        ZfaRouteParams.intParam({'id': 'not-a-number'}, 'id', fallback: -1),
        -1,
      );
    });

    test('doubleParam parses doubles and falls back', () {
      expect(ZfaRouteParams.doubleParam({'r': '2.5'}, 'r'), 2.5);
      expect(ZfaRouteParams.doubleParam({'r': '3'}, 'r'), 3.0);
      expect(ZfaRouteParams.doubleParam({}, 'r'), 0.0);
      expect(ZfaRouteParams.doubleParam({'r': 'x'}, 'r', fallback: 1.5), 1.5);
    });

    test('boolParam parses true/false and falls back', () {
      expect(ZfaRouteParams.boolParam({'f': 'true'}, 'f'), true);
      expect(ZfaRouteParams.boolParam({'f': 'false'}, 'f'), false);
      expect(ZfaRouteParams.boolParam({}, 'f'), false);
      expect(ZfaRouteParams.boolParam({}, 'f', fallback: true), true);
      expect(ZfaRouteParams.boolParam({'f': 'yes'}, 'f'), false);
    });
  });

  group('ZfaRouteParams holder (controller init access)', () {
    tearDown(ZfaRouteParams.reset);

    test('bind + currentAs returns the bound instance typed', () {
      final params = _FakeParams(
        pathParameters: const {'id': '42'},
        queryParameters: const {'tab': 'profile'},
      );
      ZfaRouteParams.bind(params);
      expect(ZfaRouteParams.currentAs<_FakeParams>(), same(params));
      expect(
        ZfaRouteParams.currentAs<_FakeParams>().pathParameters['id'],
        '42',
      );
      expect(
        ZfaRouteParams.currentAs<_FakeParams>().queryParameters['tab'],
        'profile',
      );
    });

    test('currentAs throws StateError when nothing is bound', () {
      ZfaRouteParams.reset();
      expect(
        () => ZfaRouteParams.currentAs<_FakeParams>(),
        throwsA(isA<StateError>()),
      );
    });

    test('currentAs throws when bound to a different type', () {
      ZfaRouteParams.bind(const ZfaRouteParams());
      expect(
        () => ZfaRouteParams.currentAs<_FakeParams>(),
        throwsA(isA<StateError>()),
      );
    });

    test('US-2 scenario: /items/42 -> controller receives id=42 (int)', () {
      // Simulates what the generated ProductsRouteParams.fromMaps does at
      // navigation time.
      final typedId = ZfaRouteParams.intParam({'id': '42'}, 'id');
      expect(typedId, 42);
    });

    test('US-2 scenario: /users/7/settings?tab=profile -> both params', () {
      final path = {'userId': '7'};
      final query = {'tab': 'profile'};
      expect(ZfaRouteParams.stringParam(path, 'userId'), '7');
      expect(ZfaRouteParams.stringParam(query, 'tab'), 'profile');
    });
  });
}

class _FakeParams extends ZfaRouteParams {
  const _FakeParams({super.pathParameters, super.queryParameters});
}
