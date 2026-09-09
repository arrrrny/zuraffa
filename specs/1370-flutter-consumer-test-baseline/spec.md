**Template Version**: `zuraffa-1.0`

# Spec: 1370-flutter-consumer-test-baseline

GitHub issue: arrrrny/zuraffa#1370 (verify-misfire / missing-integration +
spec-drift; follow-up deepening of #1369; EPIC #1012 Phase A / #1008)

## Summary

`zfa tdd init` prescribed `test: ^1.0.0` into Flutter consumers where the
constraint CANNOT resolve: zuraffa's graphql dependency pulls
web_socket_channel ^3.0.1, conflicting with every `test` release
compatible with flutter_test's test_api/matcher pins — the same #1189
conflict class zuraffa itself documented and fixed for its own package.
Result: `flutter pub get` broke in every project init "fixed", and the
engine half of the two-cycle driver was structurally unreachable in
Flutter consumers.

## Locked decisions

1. Option 1 composition: on Flutter hosts the gen side ALREADY emits
   `package:flutter_test/flutter_test.dart` imports (issue #1351;
   flutter_test re-exports the group/test/expect API) — so the BASELINE
   must stop prescribing plain `test` to Flutter projects. The #716
   premise (flutter_test provides no package:test) is superseded by the
   #1351 import policy and the #1189 constraint reality.
2. Pure-Dart projects are unchanged: `test: ^1.25.0` stays prescribed
   (the dart lane needs the runner package).
3. The shipped example/ (Flutter consumer) drops the plain `test` pin
   introduced by the #1369 data fix — superseded by this spec; coverage
   and mutation_test stay (tdd verify consumes them).
4. The #1369 baseline pin is updated to assert the corrected contract
   (no plain `test` in the Flutter consumer).
5. Contract-kind behaviors' `package:test` import in Flutter consumers
   remains a KNOWN limitation of the contract lane (CORE/pure-Dart
   discipline) — recorded, not redesigned here.

## Functional requirements

- **FR-1**: on Flutter projects the patcher prescribes NO plain `test`;
  coverage/mutation_test/flutter_test stay.
- **FR-2**: pure-Dart projects keep `test: ^1.25.0`.
- **FR-3**: the shipped example/ Flutter consumer declares no plain
  `test`.

## Acceptance scenarios

1. Flutter pubspec + patcher.ensure → no `test:` in the added set or the
   written pubspec; coverage/mutation_test added (B1).
2. Pure-Dart pubspec → `test: ^1.25.0` preserved (B2 guard).
3. example/pubspec.yaml → no plain `test` (B3, data pin).

## Success criteria

- **SC-001**: `flutter pub get` in a zuraffa Flutter consumer resolves
  after `zfa tdd init` (no unresolvable test constraint injected) —
  re-proven by CI's flutter-smoke-gate.
- **SC-002**: The writer and package_sdk suites stay green.

## Assumptions

- CI's flutter-smoke-gate is the resolver of record (no Flutter SDK on
  the local agent).
