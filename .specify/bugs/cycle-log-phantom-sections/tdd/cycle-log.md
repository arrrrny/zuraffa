# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- subject-hash: 488b208dac1fdc520a267c0d3c319b08a38679a14203c15ef2438be45d30f93c
- criterion: AC-1
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart --plain-name "the in-fence `## ` lines do NOT start"`
- exit: 1
- at: 2026-09-10T22:30:09.993629Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart                                                                                                    
00:01 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart                                                                                                    
00:01 +0: A1 (AC-1) A1 — the in-fence `## ` lines do NOT start                                                                                                                                         
00:01 +0 -1: A1 (AC-1) A1 — the in-fence `## ` lines do NOT start [E]                                                                                                                                  
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                        expect
  test/tdd/cycle-log-phantom-sections/a1_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart -p vm --plain-name 'A1 (AC-1) A1 — the in-fence `## ` lines do NOT start'

00:01 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 88f3a5c3f0a5ab2af003d6327e51680c89466918f74324a73b8e172f234c50a2

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- subject-hash: 1896c459fc1516ee00f0278e3f3d15011d65084900b7109355832596ddda7cfc
- criterion: AC-2
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart --plain-name "fence state stays synchronized and no `## ` line inside any"`
- exit: 1
- at: 2026-09-10T22:31:32.570288Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart                                                                                                    
00:00 +0: A2 (AC-2) A2 — fence state stays synchronized and no `## ` line inside any                                                                                                                   
00:00 +0 -1: A2 (AC-2) A2 — fence state stays synchronized and no `## ` line inside any [E]                                                                                                            
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher                                        expect
  test/tdd/cycle-log-phantom-sections/a2_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart -p vm --plain-name 'A2 (AC-2) A2 — fence state stays synchronized and no `## ` line inside any'

00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 071ba346163bdf20917ba78c2d82f45316f73b93a50b0f342610eef59db73fb8

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- subject-hash: 024469b50bcddc75d0a281fc0e110ff4f2b8e3943fe166352cde7b0e59587d93
- criterion: AC-3
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart --plain-name "the parsed sections are identical to what"`
- exit: 1
- at: 2026-09-10T22:32:51.595829Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart                                                                                                    
00:00 +0: A3 (AC-3) A3 — the parsed sections are identical to what                                                                                                                                     
00:00 +0 -1: A3 (AC-3) A3 — the parsed sections are identical to what [E]                                                                                                                              
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher                                        expect
  test/tdd/cycle-log-phantom-sections/a3_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart -p vm --plain-name 'A3 (AC-3) A3 — the parsed sections are identical to what'

00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 64f047f1c81209869b9549e17e1370274f16fc29f75b09149af114ca48b4dacb

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: assertionFailure
- subject-hash: 969e3f38a3658df233062d40cba8f0b8a30af69d6ca16d2b484be1c55a53fde5
- criterion: AC-4
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart --plain-name "each sections the file through the shared"`
- exit: 1
- at: 2026-09-10T22:34:14.474767Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart                                                                                                    
00:00 +0: A4 (AC-4) A4 — each sections the file through the shared                                                                                                                                     
00:00 +0 -1: A4 (AC-4) A4 — each sections the file through the shared [E]                                                                                                                              
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a4 not implemented>
  
  package:matcher                                        expect
  test/tdd/cycle-log-phantom-sections/a4_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart -p vm --plain-name 'A4 (AC-4) A4 — each sections the file through the shared'

00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 0683dfeae574259c25d06c3f6c7acbd7dfb28a5f5d9cc6965652539c78496f47

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- subject-hash: e03102a8ed1fd738255d37f8eed1eb97cf3a580a500a3450be66fe7f6239fd48
- criterion: AC-5
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart --plain-name "it yields exactly one entry with the correct behavior id, kind,"`
- exit: 1
- at: 2026-09-10T22:35:25.225339Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart                                                                                                    
00:00 +0: A5 (AC-5) A5 — it yields exactly one entry with the correct behavior id, kind,                                                                                                               
00:00 +0 -1: A5 (AC-5) A5 — it yields exactly one entry with the correct behavior id, kind, [E]                                                                                                        
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a5 not implemented>
  
  package:matcher                                        expect
  test/tdd/cycle-log-phantom-sections/a5_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart -p vm --plain-name 'A5 (AC-5) A5 — it yields exactly one entry with the correct behavior id, kind,'

00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 30435d053fc16ccfe6d7002fa66f948a68807f68824a2f5e1b2788bcd1340097

## Cycle: A1 (error)

- behavior: A1
- kind: error
- outcome: unexpressible
- criterion: AC-1
- test: test/
- command: `dart /Users/arrrrny/Developer/zuraffa/bin/zfa.dart tdd make A1 --feature .specify/bugs/cycle-log-phantom-sections --project /Users/arrrrny/Developer/zuraffa --suite-baseline /Users/arrrrny/Developer/zuraffa/.specify/bugs/cycle-log-phantom-sections/tdd/run-baseline.json --timeout 25.0000`
- exit: 1
- at: 2026-09-10T22:36:10.940326Z
- output:
```
zfa tdd make: behavior A1
   feature: cycle-log-phantom-sections
   test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart
   suite baseline: cached (2026-09-10T22:29:16.141061Z) — 713 pre-existing failure(s) (issue #741)
   composition fallback disengaged: no green unit subjects to compose against: behavior "A1" needs at least one unit-kind behavior with green cycle-log evidence or an entity-wired subject artifact (the `wiredEntityAnchor` implementation anchor `zfa tdd wire` emits — issue #923: a wired unit subject is a valid composition anchor even while its behavior is still a stub). Wire a unit subject with `zfa tdd wire <id> --entity <Name>` or take a unit behavior green before composing against it.
zfa tdd make: cannot plan a generation for behavior "A1". behavior "A1" requires an implementation the zuraffa generation pipeline cannot express: no generator surface maps the behavior description "the in-fence `## ` lines do NOT start" to a `zfa entity create` / `zfa make` / `zfa build` invocation. File a zuraffa gap per the STOP-ON-ROADBLOCK policy.
make: behavior=A1 outcome=unexpressible feature=cycle-log-phantom-sections
```

- schema: 1
- prev-hash: 88f3a5c3f0a5ab2af003d6327e51680c89466918f74324a73b8e172f234c50a2
- hash: c84ba604ba4be1bd63a1c90e034b1ec5e9afe6ae6b834c923acf6a93608c4bcf

