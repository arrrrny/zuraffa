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

## Cycle: A1 (green)

- behavior: A1
- kind: green
- subject-hash: 4b8e4cd3a9711fa46c1cb05e886c5d69e828d73888258fbc73d827bd986a136a
- criterion: AC-1
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart --plain-name "the in-fence `## ` lines do NOT start"`
- exit: 0
- at: 2026-09-10T22:56:19.968679Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart                                                                                                    
00:01 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart                                                                                                    
00:01 +0: A1 (AC-1) A1 — the in-fence `## ` lines do NOT start                                                                                                                                         
00:01 +1: A1 (AC-1) A1 — the in-fence `## ` lines do NOT start                                                                                                                                         
00:01 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: c84ba604ba4be1bd63a1c90e034b1ec5e9afe6ae6b834c923acf6a93608c4bcf
- hash: 327ebb20650510e0da36a5dfe80ffe20ad2cb418fb09ba52aef1d087907465dc

## Cycle: A2 (green)

- behavior: A2
- kind: green
- subject-hash: 37d2da2b3e163f582314448598c262f73c44cc5a91eb6084d1582486676cc553
- criterion: AC-2
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart --plain-name "fence state stays synchronized and no `## ` line inside any"`
- exit: 0
- at: 2026-09-10T22:56:42.021371Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a2_test.dart                                                                                                    
00:00 +0: A2 (AC-2) A2 — fence state stays synchronized and no `## ` line inside any                                                                                                                   
00:00 +1: A2 (AC-2) A2 — fence state stays synchronized and no `## ` line inside any                                                                                                                   
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 071ba346163bdf20917ba78c2d82f45316f73b93a50b0f342610eef59db73fb8
- hash: ef4298f886e5dd7272b874f46fee47b137f2576288ac4c0f073325ea51226cdd

## Cycle: A3 (green)

- behavior: A3
- kind: green
- subject-hash: ee2d0056dd93f069f4bb43b4fc86339ed9e2180346eab0561d9f12f750c91812
- criterion: AC-3
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart --plain-name "the parsed sections are identical to what"`
- exit: 0
- at: 2026-09-10T22:57:04.816545Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a3_test.dart                                                                                                    
00:00 +0: A3 (AC-3) A3 — the parsed sections are identical to what                                                                                                                                     
00:00 +1: A3 (AC-3) A3 — the parsed sections are identical to what                                                                                                                                     
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 64f047f1c81209869b9549e17e1370274f16fc29f75b09149af114ca48b4dacb
- hash: 6d900de7493c0a27413c670d3f81b616d0fc31a2c772137ff5f140b26065aecd

## Cycle: A4 (green)

- behavior: A4
- kind: green
- subject-hash: 32a304bd7e9da4da6b5cdd60e9da066958f0afe16d9c8e1ee365c95d1ebb0a2b
- criterion: AC-4
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart --plain-name "each sections the file through the shared"`
- exit: 0
- at: 2026-09-10T22:57:25.953837Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a4_test.dart                                                                                                    
00:00 +0: A4 (AC-4) A4 — each sections the file through the shared                                                                                                                                     
00:00 +1: A4 (AC-4) A4 — each sections the file through the shared                                                                                                                                     
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 0683dfeae574259c25d06c3f6c7acbd7dfb28a5f5d9cc6965652539c78496f47
- hash: ed9ef73f74c269f4692844d8164eb6021dd69a7746724683a8b07db6526255ca

## Cycle: A5 (green)

- behavior: A5
- kind: green
- subject-hash: c99efba87b4e863cff413c66fff1bc7d6bd1576d4e1a82ad3a5ec356209a95d8
- criterion: AC-5
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart --plain-name "it yields exactly one entry with the correct behavior id, kind,"`
- exit: 0
- at: 2026-09-10T22:57:47.309707Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a5_test.dart                                                                                                    
00:00 +0: A5 (AC-5) A5 — it yields exactly one entry with the correct behavior id, kind,                                                                                                               
00:00 +1: A5 (AC-5) A5 — it yields exactly one entry with the correct behavior id, kind,                                                                                                               
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 30435d053fc16ccfe6d7002fa66f948a68807f68824a2f5e1b2788bcd1340097
- hash: 16465fa556edb1a1df8e09d8828dcc1e3b9fa7d51aca6ab2283de0176a467b65

## Cycle: A1 (error)

- behavior: A1
- kind: error
- outcome: runner-error
- criterion: AC-1
- test: test/
- command: `dart /Users/arrrrny/Developer/zuraffa/bin/zfa.dart tdd refactor A1 --feature .specify/bugs/cycle-log-phantom-sections --project /Users/arrrrny/Developer/zuraffa --suite-baseline /Users/arrrrny/Developer/zuraffa/.specify/bugs/cycle-log-phantom-sections/tdd/run-baseline.json --timeout 25.0000`
- exit: -1
- at: 2026-09-11T00:19:52.974398Z
- output:
```
Subprocess TIMED OUT after 25m00s and was killed (SIGKILL): `dart /Users/arrrrny/Developer/zuraffa/bin/zfa.dart tdd refactor A1 --feature .specify/bugs/cycle-log-phantom-sections --project /Users/arrrrny/Developer/zuraffa --suite-baseline /Users/arrrrny/Developer/zuraffa/.specify/bugs/cycle-log-phantom-sections/tdd/run-baseline.json --timeout 25.0000` (working directory: /Users/arrrrny/Developer/zuraffa)
   captured output before the kill (tail):
   zfa tdd refactor: preflight suite
   command: dart test
```

- schema: 1
- prev-hash: 327ebb20650510e0da36a5dfe80ffe20ad2cb418fb09ba52aef1d087907465dc
- hash: b392dcedb127c66a0df2965573dec6ecafd2abd9a2de0afa80da2a04b266acac

## Cycle: A1 (error)

- behavior: A1
- kind: error
- outcome: runner-error
- criterion: AC-1
- test: test/
- command: `dart /Users/arrrrny/Developer/zuraffa/bin/zfa.dart tdd refactor A1 --feature .specify/bugs/cycle-log-phantom-sections --project /Users/arrrrny/Developer/zuraffa --suite-baseline /Users/arrrrny/Developer/zuraffa/.specify/bugs/cycle-log-phantom-sections/tdd/run-baseline.json --timeout 90.0000`
- exit: -1
- at: 2026-09-11T05:23:52.995653Z
- output:
```
Subprocess TIMED OUT after 90m00s and was killed (SIGKILL): `dart /Users/arrrrny/Developer/zuraffa/bin/zfa.dart tdd refactor A1 --feature .specify/bugs/cycle-log-phantom-sections --project /Users/arrrrny/Developer/zuraffa --suite-baseline /Users/arrrrny/Developer/zuraffa/.specify/bugs/cycle-log-phantom-sections/tdd/run-baseline.json --timeout 90.0000` (working directory: /Users/arrrrny/Developer/zuraffa)
   captured output before the kill (tail):
        changed: lib/tdd/1444-setup-zuraffa-app/a2_subject.dart, lib/tdd/1444-setup-zuraffa-app/a5_subject.dart, lib/tdd/1444-setup-zuraffa-app/a7_subject.dart
   pass: fix
     command: dart fix --apply lib/
     exit: 0
     changed: lib/src/commands/make_command.dart
zfa tdd refactor: re-proof: full (changed set not fully attributable to registered artifacts — safe fallback)
   command: dart test
   re-proof exit: 1
   infra-level runner failure (exit 1) — clearing the dart test kernel cache and retrying (1/2) [issue #1333]
   infra signature: 11:22 +2918 ~1: test/plugins/tdd/reproof_failure_classifier_test.dart: ... — infra tier (FR-1 / AS-5) the issue #1333 signature: "Cannot retrieve length of file" + dart_test.kernel .dill errno 2
```

- schema: 1
- prev-hash: b392dcedb127c66a0df2965573dec6ecafd2abd9a2de0afa80da2a04b266acac
- hash: c3fdf6b56c2a34c9cf9b008fcf0e4fbedb9385d8f73bd3023a7410b535ae1618

