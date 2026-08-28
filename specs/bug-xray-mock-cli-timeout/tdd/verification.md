# Verification — issue #531

## Verdict

FIXED. `test/commands/xray_mock_cli_test.dart` passes within the 2-minute group
timeout, and the per-spawn `dart` compile cost is eliminated.

## How to verify

1. **Direct (green proof):**
   ```
   dart test test/commands/xray_mock_cli_test.dart
   ```
   Expected: all tests pass (the AOT exe is built once in `setUpAll`).

2. **Cost measurement (reproduces the regression if reverted):**
   - Before the fix, `time dart bin/zfa.dart xray mock <entity> --root <dir>`
     is ~20–25s cold. Six such spawns ≈ 144s > the 120s group budget → timeout.
   - After the fix, `runZfaSource` runs the precompiled AOT exe
     (`zfaExePath`); a spawn is ~0.02s, so the group completes in seconds.
   - Mutant check: delete the AOT-exe path (force `zfaExePath = null` / fall
     back to `dart bin/zfa.dart`) and the group again blows the 2-minute
     timeout — proving the precompile is the decisive fix.

3. **No regressions for registry-consuming commands:** `make`/`manifest`/`apply`
   are NOT in the plugin-free set, so their registry is still built. A
   `dart test test/commands/make_command_test.dart` run still passes (it drives
   `make` through the normal CLI path).

4. **Analyzer:** `dart analyze lib/src/cli test/helpers` → no issues.

## Notes / limitations

- The 2-minute timeout and the `--source` assertion were deliberately left
  untouched.
- The AOT exe is built in `setUpAll` (bounded at 100s with a source fallback)
  under `.dart_tool/zfa_cli_bin/zfa_exe`; it is reused when the source is
  unchanged and is git-ignored. On platforms/environments where
  `dart compile exe` is unavailable, the helper transparently falls back to
  `dart bin/zfa.dart`.
