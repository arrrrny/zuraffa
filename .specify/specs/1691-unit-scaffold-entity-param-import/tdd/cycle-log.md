# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

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

