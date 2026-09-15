# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- subject-hash: cdb0dbed2b26186faf1cd6cd7b1d510e874d90db8d03d3840a083fbfa4e88e17
- criterion: AC-3
- test: test/tdd/zero-route-gorouter-launch/a3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart --plain-name "it carries the same `errorBuilder` / empty-table fallback alongside the observer."`
- exit: 1
- at: 2026-09-15T22:16:08.479285Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:01 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:02 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:03 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:04 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:05 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:06 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:07 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:08 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:09 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:10 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:11 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:12 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:13 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:14 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart                                                                                                    
00:14 +0: A3 (AC-3) A3 — it carries the same `errorBuilder` / empty-table fallback alongside the observer.                                                                                             
00:15 +0 -1: A3 (AC-3) A3 — it carries the same `errorBuilder` / empty-table fallback alongside the observer. [E]                                                                                      
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher                                        expect
  test/tdd/zero-route-gorouter-launch/a3_test.dart 37:7  main.<fn>.<fn>
  

To run this test again: /usr/local/share/flutter/bin/cache/dart-sdk/bin/dart test /Users/arrrrny/Developer/zuraffa/test/tdd/zero-route-gorouter-launch/a3_test.dart -p vm --plain-name 'A3 (AC-3) A3 — it carries the same `errorBuilder` / empty-table fallback alongside the observer.'

00:15 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 69f9d1f51034b2d44b051dd4213d449c042cff132454cbabd28e0c927d815c03

