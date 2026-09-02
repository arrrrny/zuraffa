# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- criterion: AC-1
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/a1_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/a1_test.dart --name "create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt."`
- exit: 1
- at: 2026-09-02T09:07:00.603812Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/a1_test.dart
00:00 +0: A1 (AC-1) create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt.
00:00 +0 -1: A1 (AC-1) create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher             expect
  test/tdd/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/a1_test.dart: A1 (AC-1) create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: A1 (green)

- behavior: A1
- kind: green
- criterion: AC-1
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/a1_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/a1_test.dart --name "create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt."`
- exit: 0
- at: 2026-09-02T09:08:52.442353Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/a1_test.dart
00:00 +0: A1 (AC-1) create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart entity create -n Todo
    exit: 0
    purpose: create entity Todo for behavior A1
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd wire A1 --entity Todo
    exit: 0
    purpose: wire subject of behavior A1 to entity Todo
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior A1
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-007
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:09:30.767468Z
- output:
```
preflight: green
re-proof: green
applied: 3 action(s), 1 with file changes.
```
actions:
- action: build
  command: `/home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build`
  exit: 0
  changed: (none)
- action: format
  command: `dart format lib/`
  exit: 0
  changed: lib/src/domain/entities/todo/todo.dart, lib/tdd/a1_subject.dart
- action: fix
  command: `dart fix --apply lib/`
  exit: 0
  changed: (none)

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- criterion: AC-2
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/a2_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/a2_test.dart --name "create entity TodoStats with total, active, completed."`
- exit: 1
- at: 2026-09-02T09:10:06.683538Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/a2_test.dart
00:00 +0: A2 (AC-2) create entity TodoStats with total, active, completed.
00:00 +0 -1: A2 (AC-2) create entity TodoStats with total, active, completed. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher             expect
  test/tdd/a2_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/a2_test.dart: A2 (AC-2) create entity TodoStats with total, active, completed.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: A2 (green)

- behavior: A2
- kind: green
- criterion: AC-2
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/a2_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/a2_test.dart --name "create entity TodoStats with total, active, completed."`
- exit: 0
- at: 2026-09-02T09:11:18.405387Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/a2_test.dart
00:00 +0: A2 (AC-2) create entity TodoStats with total, active, completed.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart entity create -n TodoStats
    exit: 0
    purpose: create entity TodoStats for behavior A2
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd wire A2 --entity TodoStats
    exit: 0
    purpose: wire subject of behavior A2 to entity TodoStats
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior A2
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-007
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:11:54.623061Z
- output:
```
preflight: green
re-proof: green
applied: 3 action(s), 1 with file changes.
```
actions:
- action: build
  command: `/home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build`
  exit: 0
  changed: (none)
- action: format
  command: `dart format lib/`
  exit: 0
  changed: lib/src/domain/entities/todo_stats/todo_stats.dart, lib/tdd/a2_subject.dart
- action: fix
  command: `dart fix --apply lib/`
  exit: 0
  changed: (none)

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- criterion: AC-3
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/a3_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/a3_test.dart --name "the status line formatter returns a non-empty string."`
- exit: 1
- at: 2026-09-02T09:12:28.697445Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/a3_test.dart
00:00 +0: A3 (AC-3) the status line formatter returns a non-empty string.
00:00 +0 -1: A3 (AC-3) the status line formatter returns a non-empty string. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher             expect
  test/tdd/a3_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/a3_test.dart: A3 (AC-3) the status line formatter returns a non-empty string.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: A3 (green)

- behavior: A3
- kind: green
- criterion: AC-3
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/a3_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/a3_test.dart --name "the status line formatter returns a non-empty string."`
- exit: 0
- at: 2026-09-02T09:13:21.802378Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/a3_test.dart
00:00 +0: A3 (AC-3) the status line formatter returns a non-empty string.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd func A3
    exit: 0
    purpose: scaffold the return function for behavior A3 from its description
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior A3
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:13:57.930368Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

## Cycle: U1 (red)

- behavior: U1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u1_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u1_test.dart --name "The default priority returns 1 when a todo is created without an explicit priority."`
- exit: 1
- at: 2026-09-02T09:14:32.467595Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u1_test.dart
00:00 +0: U1 (FR-001) The default priority returns 1 when a todo is created without an explicit priority.
00:00 +0 -1: U1 (FR-001) The default priority returns 1 when a todo is created without an explicit priority. [E]
  Expected: <1>
    Actual: UnimplementedError:<UnimplementedError: subject_u1 not implemented>
  
  package:matcher             expect
  test/tdd/u1_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/u1_test.dart: U1 (FR-001) The default priority returns 1 when a todo is created without an explicit priority.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: U1 (green)

- behavior: U1
- kind: green
- criterion: FR-001
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u1_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u1_test.dart --name "The default priority returns 1 when a todo is created without an explicit priority."`
- exit: 0
- at: 2026-09-02T09:15:24.984664Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u1_test.dart
00:00 +0: U1 (FR-001) The default priority returns 1 when a todo is created without an explicit priority.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd func U1
    exit: 0
    purpose: scaffold the return function for behavior U1 from its description
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior U1
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:16:02.976022Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

## Cycle: U2 (red)

- behavior: U2
- kind: red
- classification: assertionFailure
- criterion: FR-002
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u2_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u2_test.dart --name "The maximum title length returns 120 when a title is validated."`
- exit: 1
- at: 2026-09-02T09:17:27.429541Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u2_test.dart
00:00 +0: U2 (FR-002) The maximum title length returns 120 when a title is validated.
00:00 +0 -1: U2 (FR-002) The maximum title length returns 120 when a title is validated. [E]
  Expected: <120>
    Actual: UnimplementedError:<UnimplementedError: subject_u2 not implemented>
  
  package:matcher             expect
  test/tdd/u2_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/u2_test.dart: U2 (FR-002) The maximum title length returns 120 when a title is validated.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: U2 (green)

- behavior: U2
- kind: green
- criterion: FR-002
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u2_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u2_test.dart --name "The maximum title length returns 120 when a title is validated."`
- exit: 0
- at: 2026-09-02T09:18:18.310809Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u2_test.dart
00:00 +0: U2 (FR-002) The maximum title length returns 120 when a title is validated.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd func U2
    exit: 0
    purpose: scaffold the return function for behavior U2 from its description
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior U2
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:18:55.616689Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

## Cycle: U3 (red)

- behavior: U3
- kind: red
- classification: assertionFailure
- criterion: FR-003
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u3_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u3_test.dart --name "The priority label formatter returns a non-empty string for every priority level."`
- exit: 1
- at: 2026-09-02T09:19:30.426479Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u3_test.dart
00:00 +0: U3 (FR-003) The priority label formatter returns a non-empty string for every priority level.
00:00 +0 -1: U3 (FR-003) The priority label formatter returns a non-empty string for every priority level. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u3 not implemented>
  
  package:matcher             expect
  test/tdd/u3_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/u3_test.dart: U3 (FR-003) The priority label formatter returns a non-empty string for every priority level.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: U3 (green)

- behavior: U3
- kind: green
- criterion: FR-003
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u3_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u3_test.dart --name "The priority label formatter returns a non-empty string for every priority level."`
- exit: 0
- at: 2026-09-02T09:20:23.876349Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u3_test.dart
00:00 +0: U3 (FR-003) The priority label formatter returns a non-empty string for every priority level.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd func U3
    exit: 0
    purpose: scaffold the return function for behavior U3 from its description
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior U3
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:21:02.347829Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

## Cycle: U4 (red)

- behavior: U4
- kind: red
- classification: assertionFailure
- criterion: FR-004
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u4_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u4_test.dart --name "The overdue tag collector returns a list of tag names."`
- exit: 1
- at: 2026-09-02T09:21:37.535453Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u4_test.dart
00:00 +0: U4 (FR-004) The overdue tag collector returns a list of tag names.
00:00 +0 -1: U4 (FR-004) The overdue tag collector returns a list of tag names. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u4 not implemented>
  
  package:matcher             expect
  test/tdd/u4_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/u4_test.dart: U4 (FR-004) The overdue tag collector returns a list of tag names.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: U4 (green)

- behavior: U4
- kind: green
- criterion: FR-004
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u4_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u4_test.dart --name "The overdue tag collector returns a list of tag names."`
- exit: 0
- at: 2026-09-02T09:22:29.522262Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u4_test.dart
00:00 +0: U4 (FR-004) The overdue tag collector returns a list of tag names.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd func U4
    exit: 0
    purpose: scaffold the return function for behavior U4 from its description
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior U4
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:23:08.036299Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

## Cycle: U5 (red)

- behavior: U5
- kind: red
- classification: assertionFailure
- criterion: FR-005
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u5_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u5_test.dart --name "The completion ratio compute returns 0 when the todo list is empty."`
- exit: 1
- at: 2026-09-02T09:23:42.822957Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u5_test.dart
00:00 +0: U5 (FR-005) The completion ratio compute returns 0 when the todo list is empty.
00:00 +0 -1: U5 (FR-005) The completion ratio compute returns 0 when the todo list is empty. [E]
  Expected: <0>
    Actual: UnimplementedError:<UnimplementedError: subject_u5 not implemented>
  
  package:matcher             expect
  test/tdd/u5_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/u5_test.dart: U5 (FR-005) The completion ratio compute returns 0 when the todo list is empty.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: U5 (green)

- behavior: U5
- kind: green
- criterion: FR-005
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u5_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u5_test.dart --name "The completion ratio compute returns 0 when the todo list is empty."`
- exit: 0
- at: 2026-09-02T09:24:35.204849Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u5_test.dart
00:00 +0: U5 (FR-005) The completion ratio compute returns 0 when the todo list is empty.
00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd func U5
    exit: 0
    purpose: scaffold the compute function for behavior U5 from its description
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build generated code for behavior U5
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:25:13.129229Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

## Cycle: U6 (red)

- behavior: U6
- kind: red
- classification: assertionFailure
- criterion: FR-006
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u6_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u6_test.dart --name "The persistence flag returns true when the journal is clean."`
- exit: 1
- at: 2026-09-02T09:25:46.542129Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u6_test.dart
00:00 +0: U6 (FR-006) The persistence flag returns true when the journal is clean.
00:00 +0 -1: U6 (FR-006) The persistence flag returns true when the journal is clean. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u6 not implemented>
  
  package:matcher             expect
  test/tdd/u6_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/z/my-project/workspace/todo_tdd/test/tdd/u6_test.dart: U6 (FR-006) The persistence flag returns true when the journal is clean.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

## Cycle: U6 (green)

- behavior: U6
- kind: green
- criterion: FR-006
- test: /home/z/my-project/workspace/todo_tdd/./test/tdd/u6_test.dart
- command: `dart test /home/z/my-project/workspace/todo_tdd/./test/tdd/u6_test.dart --name "The persistence flag returns true when the journal is clean."`
- exit: 0
- at: 2026-09-02T09:27:25.015425Z
- output:
```
00:00 +0: loading /home/z/my-project/workspace/todo_tdd/test/tdd/u6_test.dart
00:00 +0: U6 (FR-006) The persistence flag returns true when the journal is clean.
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

## Cycle: 001-todo-app-refactor (refactor)

- behavior: 001-todo-app-refactor
- kind: refactor
- criterion: FR-008
- test: test/
- command: `dart test`
- exit: 0
- at: 2026-09-02T09:28:02.576625Z
- no-op: true
- output:
```
preflight: green
re-proof: green
applied: 0 actions.
```

