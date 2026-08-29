import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('ZuraffaRouteState', () {
    test('carries location, path, matched location and both param maps', () {
      const state = ZuraffaRouteState(
        location: '/users/7/settings?tab=profile',
        path: '/users/:userId/settings',
        matchedLocation: '/users/7/settings',
        queryParameters: {'tab': 'profile'},
        pathParameters: {'userId': '7'},
      );
      expect(state.location, '/users/7/settings?tab=profile');
      expect(state.path, '/users/:userId/settings');
      expect(state.matchedLocation, '/users/7/settings');
      expect(state.pathParameters['userId'], '7');
      expect(state.queryParameters['tab'], 'profile');
    });
  });

  group('ZuraffaRouteGuard (FR-008, US-5)', () {
    test('implementing guards define canActivate', () async {
      const state = ZuraffaRouteState(
        location: '/secure',
        path: '/secure',
        matchedLocation: '/secure',
        pathParameters: {},
        queryParameters: {},
      );
      expect(await _AllowGuard().canActivate(state), true);
      expect(await _DenyGuard().canActivate(state), false);
    });

    test('US-5 scenario: guard deny -> redirect path, allow -> proceed',
        () async {
      // Mirrors the generated zfaGuardRedirect helper: first denied guard
      // wins; null proceeds.
      const state = ZuraffaRouteState(
        location: '/secure',
        path: '/secure',
        matchedLocation: '/secure',
        pathParameters: {},
        queryParameters: {},
      );

      Future<String?> resolve(List<ZuraffaRouteGuard> guards) async {
        for (final guard in guards) {
          if (!await guard.canActivate(state)) {
            return guard.onRejected(state);
          }
        }
        return null;
      }

      expect(await resolve([_DenyGuard()]), '/sign-in');
      expect(await resolve([_AllowGuard()]), null);
      expect(await resolve([_AllowGuard(), _DenyGuard()]), '/sign-in');
    });

    test('guards may carry per-state rejection logic', () async {
      final guard = _RoleGuard();
      const adminState = ZuraffaRouteState(
        location: '/admin',
        path: '/admin',
        matchedLocation: '/admin',
        pathParameters: {},
        queryParameters: {},
        extra: 'admin',
      );
      const userState = ZuraffaRouteState(
        location: '/admin',
        path: '/admin',
        matchedLocation: '/admin',
        pathParameters: {},
        queryParameters: {},
        extra: 'user',
      );
      expect(await guard.canActivate(adminState), true);
      expect(await guard.canActivate(userState), false);
      expect(guard.onRejected(userState), '/403');
    });
  });
}

class _AllowGuard extends ZuraffaRouteGuard {
  @override
  Future<bool> canActivate(ZuraffaRouteState state) async => true;

  @override
  String onRejected(ZuraffaRouteState state) => '/login';
}

class _DenyGuard extends ZuraffaRouteGuard {
  @override
  Future<bool> canActivate(ZuraffaRouteState state) async => false;

  @override
  String onRejected(ZuraffaRouteState state) => '/sign-in';
}

class _RoleGuard extends ZuraffaRouteGuard {
  @override
  Future<bool> canActivate(ZuraffaRouteState state) async =>
      state.extra == 'admin';

  @override
  String onRejected(ZuraffaRouteState state) => '/403';
}
