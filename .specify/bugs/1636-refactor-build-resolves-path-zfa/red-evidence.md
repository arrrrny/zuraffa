# Red Evidence — Bug #1636 (pre-fix, this session)

Command:
`dart test test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart`

Toolchain: Dart 3.13.4 (stable) on linux_x64, working tree at
`fix/1636-refactor-build-resolves-path-zfa` BEFORE the tier-order fix.

```
00:00 +0 -1: ... B1: the cache-exe driver with a zfa on PATH resolves the running
binary, not the PATH install (#864 native-AOT shape) [E]
  Expected: '/tmp/zfa1636_cacheNSSXIE/zfa_exe'
    Actual: '/tmp/zfa1636_pathLAZCWU/zfa'
00:00 +0 -2: ... B2: the cache-exe driver with an unusable script and a zfa on
PATH still resolves the running binary [E]
  Expected: '/tmp/zfa1636_cache2CMNPFE/zfa_exe'
    Actual: '/tmp/zfa1636_path2OUCSPU/zfa'
00:00 +1 -2: B4 passed (dartaotruntime driver keeps the #690 order)
00:00 +2 -2: B5 passed (non-executable PATH candidate skipped)
00:00 +3 -2: Some tests failed.
```

Reading: B1 and B2 reproduce the issue at the tier level — the resolver
returns the PATH install (the `Actual` path is the PATH fixture) while the
driving compiled binary (`Expected`) is what the operator invoked. B3
(`dart run` VM driver → PATH tier), B4 (`dartaotruntime` driver → PATH
tier), and B5 (non-executable PATH candidate skipped) pass pre-fix and pin
the backward-compatibility contracts the fix must preserve.
