# Red evidence — Bug #1664 (pre-fix, this session)

Suite 1 (new, pre-fix): `dart test test/cli/zfa_executable_1664_installed_binary_reuse_test.dart`

```
00:00 +0 -1: Some tests failed.

Failing tests:
  test/cli/zfa_executable_1664_installed_binary_reuse_test.dart: loading test/cli/zfa_executable_1664_installed_binary_reuse_test.dart

  test/cli/zfa_executable_1664_installed_binary_reuse_test.dart:96:42: Error: Member not found: 'ZfaExecutable.currentInstalledBinary'.
  ... (one compile error per probe call site — U-1664-b1 .. b8)
```

The red is a compile-error red because the fix introduces a NEW seam
(`ZfaExecutable.currentInstalledBinary`): the failing suite proves the reuse
probe does not exist, i.e. the child binary resolution has no
installed-binary awareness — the issue's root cause. The wiring guard
(U-1664-b9) rides the same file and is exercised after green.

The behavior-level bug shape (a `.dart` candidate compiled even though a
current installed binary exists) is pinned by U-1664-b1: with the API in
place pre-fix the call would return null (compile as today) instead of the
running binary.
