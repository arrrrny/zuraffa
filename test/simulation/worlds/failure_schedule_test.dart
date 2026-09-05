/// Spec 968 — the failure schedule (U4, A9): failure storms fire exactly
/// where the manifest declares.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/worlds/failure_schedule.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';

const flap = WorldStorm(
  name: 'network-flap-push',
  kind: 'network-flap',
  touchpoint: 'RestSync',
  fromCall: 1,
  toCall: 2,
  failure: {'type': 'http', 'status': 503},
  description: 'flap',
);

const authExpiry = WorldStorm(
  name: 'auth-expiry-mid-flow',
  kind: 'auth-expiry',
  touchpoint: 'FirebaseAuth',
  fromCall: 1,
  toCall: 1,
  failure: {'type': 'auth', 'code': 'user-token-expired'},
  description: 'mid-flow',
);

const partial = WorldStorm(
  name: 'partial-write-push',
  kind: 'partial-write',
  touchpoint: 'RestSync',
  fromCall: 4,
  toCall: 4,
  failure: {'type': 'partial'},
  description: 'half-written',
);

void main() {
  group('stormAt (window resolution)', () {
    test('the flap storm fires over its whole call range', () {
      expect(stormAt([flap], 'RestSync', 'push', 1)?.name, 'network-flap-push');
      expect(stormAt([flap], 'RestSync', 'push', 2)?.name, 'network-flap-push');
    });

    test('out-of-window calls pass (the schedule is silent)', () {
      expect(stormAt([flap], 'RestSync', 'push', 3), isNull);
      expect(stormAt([flap], 'RestSync', 'push', 12), isNull);
    });

    test('storms are touchpoint-scoped', () {
      expect(stormAt([flap], 'FirebaseAuth', 'signIn', 1), isNull);
      expect(
        stormAt([authExpiry], 'FirebaseAuth', 'signIn', 1)?.name,
        'auth-expiry-mid-flow',
      );
      expect(stormAt([authExpiry], 'RestSync', 'push', 1), isNull);
    });

    test('later storms win on overlap (ordered schedule semantics)', () {
      final override = WorldStorm(
        name: 'flap-extended',
        kind: 'network-flap',
        touchpoint: 'RestSync',
        fromCall: 2,
        toCall: 4,
        failure: const {'type': 'http', 'status': 500},
        description: 'later refines earlier',
      );
      expect(
        stormAt([flap, override], 'RestSync', 'push', 2)?.name,
        'flap-extended',
      );
      expect(
        stormAt([flap, override], 'RestSync', 'push', 1)?.name,
        'network-flap-push',
      );
    });

    test('firesOn bounds are inclusive', () {
      expect(partial.firesOn(4), isTrue);
      expect(partial.firesOn(3), isFalse);
      expect(partial.firesOn(5), isFalse);
    });

    test('method-scoped storms fire only on their method', () {
      // A signIn-scoped auth storm must not also fail signOut — the
      // mid-flow storm stays surgical.
      final signInScoped = WorldStorm(
        name: 'auth-expiry-mid-flow',
        kind: 'auth-expiry',
        touchpoint: 'FirebaseAuth',
        method: 'signIn',
        fromCall: 1,
        toCall: 1,
        failure: const {'type': 'auth', 'code': 'user-token-expired'},
        description: '',
      );
      expect(
        stormAt([signInScoped], 'FirebaseAuth', 'signIn', 1)?.name,
        'auth-expiry-mid-flow',
      );
      expect(stormAt([signInScoped], 'FirebaseAuth', 'signOut', 1), isNull);
    });

    test('null-method storms cover every method of the touchpoint', () {
      expect(
        stormAt([flap], 'RestSync', 'pull', 1)?.name,
        'network-flap-push',
        reason: 'an unscoped storm shares the window across methods',
      );
    });
  });

  group('StormFailure (classification)', () {
    test('http storms classify with their status', () {
      final failure = StormFailure(
        storm: flap,
        kind: StormFailure.kindOf(flap.failure),
      );
      expect(failure.kind, StormFailureKind.http);
      expect(failure.httpStatus, 503);
      expect(failure.label, 'http-503');
    });

    test('auth storms classify with their code', () {
      final failure = StormFailure(
        storm: authExpiry,
        kind: StormFailure.kindOf(authExpiry.failure),
      );
      expect(failure.kind, StormFailureKind.auth);
      expect(failure.authCode, 'user-token-expired');
      expect(failure.label, 'auth-user-token-expired');
    });

    test('partial-write storms classify', () {
      final failure = StormFailure(
        storm: partial,
        kind: StormFailure.kindOf(partial.failure),
      );
      expect(failure.kind, StormFailureKind.partial);
      expect(failure.label, 'partial-write');
    });

    test('unknown failure payloads fall back to the storm kind', () {
      const odd = WorldStorm(
        name: 'odd',
        kind: 'custom-storm',
        touchpoint: 'X',
        fromCall: 1,
        toCall: 1,
        failure: {'weird': true},
        description: '',
      );
      expect(StormFailure.kindOf(odd.failure), StormFailureKind.unknown);
      expect(
        StormFailure(storm: odd, kind: StormFailureKind.unknown).label,
        'custom-storm',
      );
    });

    test('default http status is 503 and default auth code is expiry', () {
      const bare = WorldStorm(
        name: 'bare',
        kind: 'network-flap',
        touchpoint: 'X',
        fromCall: 1,
        toCall: 1,
        failure: {'type': 'http'},
        description: '',
      );
      const bareAuth = WorldStorm(
        name: 'bareAuth',
        kind: 'auth-expiry',
        touchpoint: 'X',
        fromCall: 1,
        toCall: 1,
        failure: {'type': 'auth'},
        description: '',
      );
      expect(
        StormFailure(
          storm: bare,
          kind: StormFailure.kindOf(bare.failure),
        ).httpStatus,
        503,
      );
      expect(
        StormFailure(
          storm: bareAuth,
          kind: StormFailure.kindOf(bareAuth.failure),
        ).authCode,
        'user-token-expired',
      );
    });
  });
}
