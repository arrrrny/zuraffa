# Cycle Log: 1691-unit-scaffold-entity-param-import

Append-only. One entry per TDD cycle (spec 046 / TDD extension v1.1.2).
Every `red` block is the evidence that the behavior's test failed before
the implementation.

This spec's loop has two lanes:

- **Repo lane** (`T-1691` cycles) — the fast-tier regression test
  `test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
  (the bug_1420 harness shape: the real `CliRunner` drives `tdd gen` in a
  temp project, no pub get, no build). It pins the U1–U3 rows of
  `tdd/test-list.md`.
- **Probe lane** (`U4`/`U5`, appendix at the bottom) — the two end-to-end
  behaviors that need a real verification project. They are recorded by the
  probe app's own `zfa tdd run` / `zfa tdd verify` cycles, whose behavior
  ids (`A1`/`U1`) belong to the PROBE feature `001-login`, not to this
  spec's U1–U3.

## Cycle: T-1691 (red) — the regression test against the unfixed writer

- behavior: U1, U2, U3
- kind: red
- classification: assertionFailure — G1/G2 fail on the import claim; G3's
  scalar pin stays green, so the red is exactly the two import claims
- criterion: FR-001, FR-002, FR-003 / SC-1, SC-2, SC-3 (spec.md)
- test: `test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
- setup: `lib/src/plugins/tdd/services/behavior_test_writer.dart` reverted to
  its parent revision `8861d41d` (the pre-fix writer); every other byte is
  this branch (`b1c1d2ff` + the review fixes)
- command: `dart test test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
- exit: 1
- at: 2026-09-17 (review-fix session)
- output:
```text
00:00 +0: U-1691-G1: entity param + entity return — the paired test imports the param entity AND the return entity (the #1691 repro compiles) [E]
  Expected: contains 'import \'package:fixture_app/src/domain/entities/login_params/login_params.dart\';'
    Actual: '// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).\n'
              ... (the generated test body, quoted below) ...
     Which: does not contain 'import \'package:fixture_app/src/domain/entities/login_params/login_params.dart\';'
00:01 +1 -2: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart: U-1691-G1: entity param + entity return — the paired test imports the param entity AND the return entity (the #1691 repro compiles)
  test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart: U-1691-G2: entity param + scalar return — the param entity is imported (the latent scalar-return compile-error case)
```
- the generated test body the failure dumps — the #1691 shape exactly: the
  lifted param type renders in the `_argN()` helper, the param import is
  missing, the return import is present:
```dart
import 'package:test/test.dart';
import 'package:fixture_app/src/domain/entities/user_session/user_session.dart';

import 'package:fixture_app/tdd/1691-repro/u1_subject.dart' as subject;

void main() {
  group('U1 (FR-001, AuthRepo.login)', () {
    test('U1 — System MUST authenticate the submitted credentials', () {
      LoginParams _arg0() => throw UnimplementedError('provide a representative argument for subject_u1 (declared param 0: LoginParams)');
      final result = (() {
        try {
          return subject.subject_u1(_arg0());
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isA<UserSession>());
    });
  });
}
```
- reading: the red is the intended one — `LoginParams _arg0()` names the
  SPEC 1489-lifted type while only `user_session` is imported, exactly the
  `verify-red -> compile-error` the fix removes. No parser/loading noise:
  the file compiles and the failure lands on the assertion.

## Cycle: T-1691 (green) — the branch under review

- behavior: U1, U2, U3
- kind: green
- classification: pass
- criterion: FR-001, FR-002, FR-003 / SC-1, SC-2, SC-3 (spec.md)
- command: `dart test test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart test/plugins/tdd/commands/bug_1420_entity_row_gen_test.dart test/plugins/tdd/commands/bug_1513_contract_writers_threading_test.dart test/plugins/tdd/services/unit_contract_shape_1489_test.dart test/plugins/tdd/services/subject_provenance_1565_test.dart`
- exit: 0
- at: 2026-09-17 (review-fix session)
- output:
```text
00:10 +41: All tests passed!
```
- per-suite: spec_1691 3/3 · bug_1420 3/3 · bug_1513 3/3 ·
  unit_contract_shape_1489 20/20 · subject_provenance_1565 12/12.
- gates on the touched files (`dart analyze`, `dart format
  --output=none --set-exit-if-changed`): `No issues found!`, 0 changed.

## Probe lane — the login_probe end-to-end cycles (U4, U5)

The entries below are the probe app's OWN cycle log, kept verbatim. They were
produced by `zfa tdd run 001-login` / `zfa tdd verify --feature 001-login`
inside the verification project (`login_probe`, a Flutter probe app at
`/home/z/my-project/probe/login_probe` in the verification sandbox) with the
FIXED zuraffa source tree — i.e. the feature whose red/green/mutation evidence
covers this spec's U4 and U5 rows. The behavior ids (`A1`, `U1`) and the
`001-login` test paths are the PROBE project's, not this repo's.

The load-bearing entry is `U1 (red)`: `Expected: <Instance of 'UserSession'>`
versus `Actual: UnimplementedError: provide a representative argument for
subject_u1 (declared param 0: LoginParams)` with `classification:
assertionFailure` — the lifted `LoginParams` param type COMPILED and the
failure landed on the assertion, exactly the transition SC-1 asks for (the
pristine tree classifies this same step `compile-error`).

<!-- verbatim probe-app cycle log follows -->

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- subject-hash: 829d3a731fa1da1580f0bd146ec8d5a51ecb373810eaa018a7bc1413598dbd60
- criterion: AC-1
- test: test/tdd/001-login/a1_test.dart
- command: `flutter test /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart --plain-name "`AuthRepo.login` returns an established session."`
- exit: 1
- at: 2026-09-17T19:25:47.049807Z
- output:
```
00:00 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart                                                                                                                 
00:01 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart                                                                                                                 
00:02 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart                                                                                                                 
00:03 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart                                                                                                                 
00:03 +0: A1 (AC-1) A1 — `AuthRepo.login` returns an established session.                                                                                                                              
00:03 +0 -1: A1 (AC-1) A1 — `AuthRepo.login` returns an established session. [E]                                                                                                                       
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tdd/001-login/a1_test.dart 37:7                main.<fn>.<fn>
  

To run this test again: /home/z/flutter/bin/cache/dart-sdk/bin/dart test /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart -p vm --plain-name 'A1 (AC-1) A1 — `AuthRepo.login` returns an established session.'

00:03 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 846ebf380a9ae1718ec766432196a412a7818d940da47c7446cf5637d1688ae6

## Cycle: U1 (red)

- behavior: U1
- kind: red
- classification: assertionFailure
- subject-hash: 979a47dc4c991b80e48fc158e0af4536a792af988cb6addc10122f268a513fd2
- criterion: FR-001, AuthRepo.login
- test: test/tdd/001-login/u1_test.dart
- command: `flutter test /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart --plain-name "The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session."`
- exit: 1
- at: 2026-09-17T19:30:38.723969Z
- output:
```
00:00 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart                                                                                                                 
00:01 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart                                                                                                                 
00:01 +0: U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session.                                     
00:01 +0 -1: U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session. [E]                              
  Expected: <Instance of 'UserSession'>
    Actual: UnimplementedError:<UnimplementedError: provide a representative argument for subject_u1 (declared param 0: LoginParams)>
     Which: is not an instance of 'UserSession'
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tdd/001-login/u1_test.dart 33:7                main.<fn>.<fn>
  

To run this test again: /home/z/flutter/bin/cache/dart-sdk/bin/dart test /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart -p vm --plain-name 'U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session.'

00:01 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 1ff387e0b913f9b71f42ed37ed59c9ac8f12b9884191aaa8e289810366416424

## Cycle: A1 (green)

- behavior: A1
- kind: green
- subject-hash: b843d5fbf4fd8a4acec4103a58e3aff3ab6a0e7dc3ab17d83140849a2460ad21
- criterion: AC-1
- test: test/tdd/001-login/a1_test.dart
- command: `flutter test /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart --plain-name "`AuthRepo.login` returns an established session."`
- exit: 0
- at: 2026-09-17T20:19:34.992003Z
- output:
```
00:00 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart                                                                                                                 
00:01 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/a1_test.dart                                                                                                                 
00:01 +0: A1 (AC-1) A1 — `AuthRepo.login` returns an established session.                                                                                                                              
00:01 +1: A1 (AC-1) A1 — `AuthRepo.login` returns an established session.                                                                                                                              
00:01 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 846ebf380a9ae1718ec766432196a412a7818d940da47c7446cf5637d1688ae6
- hash: d732764ae80768f4b3829eeb462782321cbd2026d78114b8ed6774fdb2803ca1

## Cycle: U1 (green)

- behavior: U1
- kind: green
- subject-hash: 600b738d54843f055491d0c19c96346301337fde5cfd4a4c96965831ff7abb8e
- criterion: FR-001, AuthRepo.login
- test: test/tdd/001-login/u1_test.dart
- command: `flutter test /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart --plain-name "The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session."`
- exit: 0
- at: 2026-09-17T20:20:04.978344Z
- output:
```
00:00 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart                                                                                                                 
00:01 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart                                                                                                                 
00:01 +0: U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session.                                     
00:01 +1: U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session.                                     
00:01 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 1ff387e0b913f9b71f42ed37ed59c9ac8f12b9884191aaa8e289810366416424
- hash: 71e8901d7f868568403bfd8af9a0fbda0e78a5dd7f445731875428f491f3edbf

## Cycle: U1 (green)

- behavior: U1
- kind: green
- subject-hash: 600b738d54843f055491d0c19c96346301337fde5cfd4a4c96965831ff7abb8e
- criterion: FR-001, AuthRepo.login
- test: test/tdd/001-login/u1_test.dart
- command: `flutter test /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart --plain-name "The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session."`
- exit: 0
- at: 2026-09-17T20:33:38.422175Z
- output:
```
00:00 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart                                                                                                                 
00:01 +0: loading /home/z/my-project/probe/login_probe/test/tdd/001-login/u1_test.dart                                                                                                                 
00:01 +0: U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session.                                     
00:01 +1: U1 (FR-001, AuthRepo.login) U1 — The app MUST authenticate the submitted credentials and establish a session via `AuthRepo.login` returning the session.                                     
00:01 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 71e8901d7f868568403bfd8af9a0fbda0e78a5dd7f445731875428f491f3edbf
- hash: ae662466b847601002ed06f2e37770a3050f35757fba68554fe0e397f8fa0aee
