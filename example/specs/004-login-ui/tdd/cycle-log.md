# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: W1 (red)

- behavior: W1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 1
- at: 2026-09-05T04:14:03.485349Z
- output:
```
(… 18 earlier lines …)
  file:///home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart line 43
The test description was:
  W1 — the login view fills every declared platform slot
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: W1 — the login view fills every declared platform slot [E]
  Test failed. See exception logs above.
  The test description was: W1 — the login view fills every declared platform slot
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart: W1 — the login view fills every declared platform slot
```

- schema: 1
- prev-hash: genesis
- hash: b47751e375785efb6cf2a8e7826011a7da4c1d3f123f1c168fcb8c6f0d371c8d

## Cycle: W1 (green)

- behavior: W1
- kind: green
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 0
- at: 2026-09-05T04:14:07.240112Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart
00:00 +0: W1 — the login view fills every declared platform slot
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
skin-event: behavior=W1 slot=android
skin-event: behavior=W1 slot=macos
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b47751e375785efb6cf2a8e7826011a7da4c1d3f123f1c168fcb8c6f0d371c8d
- hash: 8e19a039fff6d034be274bc52432cccb98021ef24115649b59db2ac6a019a46e

## Cycle: W1 (red)

- behavior: W1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 1
- at: 2026-09-05T04:15:48.708613Z
- output:
```
(… 18 earlier lines …)
  file:///home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart line 43
The test description was:
  W1 — the login view fills every declared platform slot
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: W1 — the login view fills every declared platform slot [E]
  Test failed. See exception logs above.
  The test description was: W1 — the login view fills every declared platform slot
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart: W1 — the login view fills every declared platform slot
```

- schema: 1
- prev-hash: 8e19a039fff6d034be274bc52432cccb98021ef24115649b59db2ac6a019a46e
- hash: 260ba94bfdf1cd4640f02112733348c440b24c68b62bc33da8375816ea9a5cac

## Cycle: W1 (green)

- behavior: W1
- kind: green
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 0
- at: 2026-09-05T04:15:52.427665Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart
00:00 +0: W1 — the login view fills every declared platform slot
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
skin-event: behavior=W1 slot=android
skin-event: behavior=W1 slot=macos
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 260ba94bfdf1cd4640f02112733348c440b24c68b62bc33da8375816ea9a5cac
- hash: 77ec2edb84fe92739b358567cbc29f196c905736934216ae3987fd2394a4fbfb

## Cycle: W1 (red)

- behavior: W1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 1
- at: 2026-09-05T05:11:41.279426Z
- output:
```
(… 18 earlier lines …)
  file:///home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart line 42
The test description was:
  W1 — the login view fills every declared platform slot
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: W1 — the login view fills every declared platform slot [E]
  Test failed. See exception logs above.
  The test description was: W1 — the login view fills every declared platform slot
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart: W1 — the login view fills every declared platform slot
```

- schema: 1
- prev-hash: 77ec2edb84fe92739b358567cbc29f196c905736934216ae3987fd2394a4fbfb
- hash: ae57b8705f6b68af3f887a5da560cf9af3127e84b2e55d0cfab65498818cca98

## Cycle: W1 (green)

- behavior: W1
- kind: green
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 0
- at: 2026-09-05T05:11:44.884306Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart
00:00 +0: W1 — the login view fills every declared platform slot
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
skin-event: behavior=W1 slot=android
skin-event: behavior=W1 slot=macos
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: ae57b8705f6b68af3f887a5da560cf9af3127e84b2e55d0cfab65498818cca98
- hash: ff6409ea07057152ce7f00f2911f0ba877fb1c27c30096f2af48702d6f2a2b2b

## Cycle: W1 (red)

- behavior: W1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 1
- at: 2026-09-05T05:14:48.379987Z
- output:
```
(… 18 earlier lines …)
  file:///home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart line 42
The test description was:
  W1 — the login view fills every declared platform slot
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: W1 — the login view fills every declared platform slot [E]
  Test failed. See exception logs above.
  The test description was: W1 — the login view fills every declared platform slot
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart: W1 — the login view fills every declared platform slot
```

- schema: 1
- prev-hash: ff6409ea07057152ce7f00f2911f0ba877fb1c27c30096f2af48702d6f2a2b2b
- hash: 00646d74ef89af177a04c8fdff6126d3f6bd73b91440cdf4832588ada0011f25

## Cycle: W1 (green)

- behavior: W1
- kind: green
- criterion: FR-001
- test: test/presentation/pages/login/login_view_test.dart
- command: `flutter test test/presentation/pages/login/login_view_test.dart --plain-name "the login view fills every declared platform slot"`
- exit: 0
- at: 2026-09-05T05:14:52.044880Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/example/test/presentation/pages/login/login_view_test.dart
00:00 +0: W1 — the login view fills every declared platform slot
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
skin-event: behavior=W1 slot=android
skin-event: behavior=W1 slot=macos
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 00646d74ef89af177a04c8fdff6126d3f6bd73b91440cdf4832588ada0011f25
- hash: b97546b5824b6489ef52d8a7f60cad8ebcc87f3d02d8c00efbd7385f8293d12d

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- subject-hash: 27a3496766ad97ae8ce3aea3e13ba340f8d1eff264b76551331aedb61e43bedf
- criterion: AC-3
- test: test/tdd/004-login-ui/a3_test.dart
- command: `flutter test test/tdd/004-login-ui/a3_test.dart --plain-name "the app shows 'Sign in'"`
- exit: 1
- at: 2026-09-06T11:06:42.470080Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a3_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a3_test.dart                                                                                                                
00:01 +0: A3 (AC-3) A3 — the app shows 'Sign in'                                                                                                                                                       
00:02 +0: A3 (AC-3) A3 — the app shows 'Sign in'                                                                                                                                                       
00:02 +0: A3 (AC-3) A3 — the app shows 'Sign in'                                                                                                                                                       
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Sign in": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file://test/tdd/004-login-ui/a3_test.dart:67:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file://test/tdd/004-login-ui/a3_test.dart line 67
The test description was:
  A3 — the app shows 'Sign in'
════════════════════════════════════════════════════════════════════════════════════════════════════

00:02 +0 -1: A3 (AC-3) A3 — the app shows 'Sign in' [E]                                                                                                                                                
  Test failed. See exception logs above.
  The test description was: A3 — the app shows 'Sign in'
  

To run this test again: /home/z/flutter/bin/cache/dart-sdk/bin/dart test test/tdd/004-login-ui/a3_test.dart -p vm --plain-name 'A3 (AC-3) A3 — the app shows '\''Sign in'\'''

00:02 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 8d6e2b0e159780d631d99eed2d3cc5082ebd570272fb0e704adca579b9fc3552

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: assertionFailure
- subject-hash: aaf547ebe635b551abbd23ffaff5ea20211274d380ab561fee396ef441e52a90
- criterion: AC-4
- test: test/tdd/004-login-ui/a4_test.dart
- command: `flutter test test/tdd/004-login-ui/a4_test.dart --plain-name "the app navigates to the route 'deal_list'"`
- exit: 1
- at: 2026-09-06T11:06:45.543635Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a4_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a4_test.dart                                                                                                                
00:01 +0: A4 (AC-4) A4 — the app navigates to the route 'deal_list'                                                                                                                                    
00:02 +0: A4 (AC-4) A4 — the app navigates to the route 'deal_list'                                                                                                                                    
00:02 +0: A4 (AC-4) A4 — the app navigates to the route 'deal_list'                                                                                                                                    
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: contains 'deal_list'
  Actual: ['/']
   Which: does not contain 'deal_list'
the scenario asserts navigation to route deal_list; a rendered string is not a navigation

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file://test/tdd/004-login-ui/a4_test.dart:67:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file://test/tdd/004-login-ui/a4_test.dart line 67
The test description was:
  A4 — the app navigates to the route 'deal_list'
════════════════════════════════════════════════════════════════════════════════════════════════════

00:02 +0 -1: A4 (AC-4) A4 — the app navigates to the route 'deal_list' [E]                                                                                                                             
  Test failed. See exception logs above.
  The test description was: A4 — the app navigates to the route 'deal_list'
  

To run this test again: /home/z/flutter/bin/cache/dart-sdk/bin/dart test test/tdd/004-login-ui/a4_test.dart -p vm --plain-name 'A4 (AC-4) A4 — the app navigates to the route '\''deal_list'\'''

00:02 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 6f09b19250db474e32ab8db446a64e1c107fe16337553e92f01a2f7522c5cd72

## Cycle: A6 (red)

- behavior: A6
- kind: red
- classification: assertionFailure
- subject-hash: 899a6959a59abd6940c89169981cc33d1f1bbd1fb515a76900f4646fdde811d5
- criterion: AC-6
- test: test/tdd/004-login-ui/a6_test.dart
- command: `flutter test test/tdd/004-login-ui/a6_test.dart --plain-name "the 'Sign in' button is disabled"`
- exit: 1
- at: 2026-09-06T11:06:48.858800Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a6_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a6_test.dart                                                                                                                
00:01 +0: A6 (AC-6) A6 — the 'Sign in' button is disabled                                                                                                                                              
00:02 +0: A6 (AC-6) A6 — the 'Sign in' button is disabled                                                                                                                                              
00:02 +0: A6 (AC-6) A6 — the 'Sign in' button is disabled                                                                                                                                              
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _AncestorWidgetFinder:<Found 0 widgets with type "ElevatedButton" that are ancestors of
widgets with text "Sign in": []>
   Which: means none were found but one was expected
the scenario asserts the t.auth.signIn control exists

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file://test/tdd/004-login-ui/a6_test.dart:69:9)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file://test/tdd/004-login-ui/a6_test.dart line 69
The test description was:
  A6 — the 'Sign in' button is disabled
════════════════════════════════════════════════════════════════════════════════════════════════════

00:02 +0 -1: A6 (AC-6) A6 — the 'Sign in' button is disabled [E]                                                                                                                                       
  Test failed. See exception logs above.
  The test description was: A6 — the 'Sign in' button is disabled
  

To run this test again: /home/z/flutter/bin/cache/dart-sdk/bin/dart test test/tdd/004-login-ui/a6_test.dart -p vm --plain-name 'A6 (AC-6) A6 — the '\''Sign in'\'' button is disabled'

00:02 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: c484fac518969ae4f837d788e8e8cd7cda1b39f6baab4845a90715801b9480fb

## Cycle: A7 (red)

- behavior: A7
- kind: red
- classification: assertionFailure
- subject-hash: b564c2d9bb2829813773a641c70731031799d3b5b39a0cadc37a973455bcc3ee
- criterion: AC-7
- test: test/tdd/004-login-ui/a7_test.dart
- command: `flutter test test/tdd/004-login-ui/a7_test.dart --plain-name "the app shows 'Signing in…' and then the app navigates to the route 'deal_list'"`
- exit: 1
- at: 2026-09-06T11:06:56.876450Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a7_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a7_test.dart                                                                                                                
00:01 +0: A7 (AC-7) A7 — the app shows 'Signing in…' and then the app navigates to the route 'deal_list'                                                                                               
00:02 +0: A7 (AC-7) A7 — the app shows 'Signing in…' and then the app navigates to the route 'deal_list'                                                                                               
00:02 +0: A7 (AC-7) A7 — the app shows 'Signing in…' and then the app navigates to the route 'deal_list'                                                                                               
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Signing in…": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file://test/tdd/004-login-ui/a7_test.dart:74:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file://test/tdd/004-login-ui/a7_test.dart line 74
The test description was:
  A7 — the app shows 'Signing in…' and then the app navigates to the route 'deal_list'
════════════════════════════════════════════════════════════════════════════════════════════════════

00:02 +0 -1: A7 (AC-7) A7 — the app shows 'Signing in…' and then the app navigates to the route 'deal_list' [E]                                                                                        
  Test failed. See exception logs above.
  The test description was: A7 — the app shows 'Signing in…' and then the app navigates to the route 'deal_list'
  

To run this test again: /home/z/flutter/bin/cache/dart-sdk/bin/dart test test/tdd/004-login-ui/a7_test.dart -p vm --plain-name 'A7 (AC-7) A7 — the app shows '\''Signing in…'\'' and then the app navigates to the route '\''deal_list'\'''

00:02 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 997fec97e979df3486bcfcaa7fbb238625b6cdc01fde927cf8ec9544c36748f2

## Cycle: A3 (green)

- behavior: A3
- kind: green
- subject-hash: 7009f5ead2dbc5cd9c334a0bdcc114207f617475110c5d8305db92736337505b
- criterion: AC-3
- test: test/tdd/004-login-ui/a3_test.dart
- command: `flutter test test/tdd/004-login-ui/a3_test.dart --plain-name "the app shows 'Sign in'"`
- exit: 0
- at: 2026-09-06T11:15:55.707698Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a3_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a3_test.dart                                                                                                                
00:02 +0: loading test/tdd/004-login-ui/a3_test.dart                                                                                                                
00:03 +0: loading test/tdd/004-login-ui/a3_test.dart                                                                                                                
00:03 +0: A3 (AC-3) A3 — the app shows 'Sign in'                                                                                                                                                       
00:03 +1: A3 (AC-3) A3 — the app shows 'Sign in'                                                                                                                                                       
00:03 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 8d6e2b0e159780d631d99eed2d3cc5082ebd570272fb0e704adca579b9fc3552
- hash: 17e3db98dddd89a001e1117fb8adcd75671bd240cba73fe4ac3b3c78c34d9191

## Cycle: A4 (green)

- behavior: A4
- kind: green
- subject-hash: cf610e35cf6a6e1aeaa5b6a7b1cd0746280c0b692e4677c4e727c35b428538bb
- criterion: AC-4
- test: test/tdd/004-login-ui/a4_test.dart
- command: `flutter test test/tdd/004-login-ui/a4_test.dart --plain-name "the app navigates to the route 'deal_list'"`
- exit: 0
- at: 2026-09-06T11:16:06.867455Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a4_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a4_test.dart                                                                                                                
00:01 +0: A4 (AC-4) A4 — the app navigates to the route 'deal_list'                                                                                                                                    
00:02 +0: A4 (AC-4) A4 — the app navigates to the route 'deal_list'                                                                                                                                    
00:02 +1: A4 (AC-4) A4 — the app navigates to the route 'deal_list'                                                                                                                                    
00:02 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 6f09b19250db474e32ab8db446a64e1c107fe16337553e92f01a2f7522c5cd72
- hash: 55a67ffb5b63c93d27faa8b702c1b635afc634ef2090e912c13bd9c6942a5080

## Cycle: A6 (green)

- behavior: A6
- kind: green
- subject-hash: 5a6b2c653d885a64ca2a56f90c0673407d9daf0777066c4e85d0986b38910e6b
- criterion: AC-6
- test: test/tdd/004-login-ui/a6_test.dart
- command: `flutter test test/tdd/004-login-ui/a6_test.dart --plain-name "the 'Sign in' button is disabled"`
- exit: 0
- at: 2026-09-06T11:16:10.296010Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a6_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a6_test.dart                                                                                                                
00:02 +0: loading test/tdd/004-login-ui/a6_test.dart                                                                                                                
00:02 +0: A6 (AC-6) A6 — the 'Sign in' button is disabled                                                                                                                                              
00:02 +1: A6 (AC-6) A6 — the 'Sign in' button is disabled                                                                                                                                              
00:02 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: c484fac518969ae4f837d788e8e8cd7cda1b39f6baab4845a90715801b9480fb
- hash: beafdd386540ece0c8728398034f344670366c2efcfb898f5cc279fe0d453e59

## Cycle: A7 (green)

- behavior: A7
- kind: green
- subject-hash: b60c2f3f7abc86f6db69e985992431815c2290a7b5c38a6dc419a8eb82e4240a
- criterion: AC-7
- test: test/tdd/004-login-ui/a7_test.dart
- command: `flutter test test/tdd/004-login-ui/a7_test.dart --plain-name "while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'"`
- exit: 0
- at: 2026-09-06T11:16:13.475074Z
- output:
```
00:00 +0: loading test/tdd/004-login-ui/a7_test.dart                                                                                                                
00:01 +0: loading test/tdd/004-login-ui/a7_test.dart                                                                                                                
00:01 +0: A7 (AC-7) A7 — while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'                                                        
00:02 +0: A7 (AC-7) A7 — while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'                                                        
00:02 +1: A7 (AC-7) A7 — while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'                                                        
00:02 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 997fec97e979df3486bcfcaa7fbb238625b6cdc01fde927cf8ec9544c36748f2
- hash: 2e1b0f203fdd28ac32f62e9720b7f621a00a90e1b4a31da492ddb9ee384e43af

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- evidence: A5 (AC-5) A5 — the 'Sign in failed' banner is not shown
- subject-hash: 07d86a8963f372eafb8028e5d6ff140d2e4fd0d1bde2de338afa8703fe0f4056
- criterion: AC-5
- test: test/tdd/004-login-ui/a5_test.dart
- command: `flutter test /Users/ahmettok/Developer/zuraffa/example/test/tdd/004-login-ui/a5_test.dart --plain-name "the 'Sign in failed' banner is not shown"`
- exit: 1
- at: 2026-09-06T13:21:34.806982Z
- output:
```
00:00 +0: loading /Users/ahmettok/Developer/zuraffa/example/test/tdd/004-login-ui/a5_test.dart
00:00 +0: A5 (AC-5) A5 — the 'Sign in failed' banner is not shown
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Sign in": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file:///Users/ahmettok/Developer/zuraffa/example/test/tdd/004-login-ui/a5_test.dart:72:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmettok/Developer/zuraffa/example/test/tdd/004-login-ui/a5_test.dart line 72
The test description was:
  A5 — the 'Sign in failed' banner is not shown
════════════════════════════════════════════════════════════════════════════════════════════════════
00:02 +0 -1: A5 (AC-5) A5 — the 'Sign in failed' banner is not shown [E]
  Test failed. See exception logs above.
  The test description was: A5 — the 'Sign in failed' banner is not shown
  
00:02 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmettok/Developer/zuraffa/example/test/tdd/004-login-ui/a5_test.dart: A5 (AC-5) A5 — the 'Sign in failed' banner is not shown
```

- schema: 1
- prev-hash: genesis
- hash: 03251892e400f59bfea3bd2ae2770d68ee6cfda141e424e7879e0b278249d30f

