# TDD Verification — bug #1465 (`zfa setup`/`zfa app shell` hardcode my_app.dart / MyApp)

Hand-authored verification record for the bug-fix branch
`fix/zfa-setup-app-name`. Every number below is from an actually executed
command in this environment (Flutter 3.47.2 stable, zfa v6.2.2 source).
Nothing here is projected or copied from a run that did not happen.

Machine-generated `zfa tdd verify` output (mutation gates) does NOT apply
to this record: `zfa tdd verify --feature` derives its scope from
`specs/<feature>/tdd/artifacts.json`, and this bug dir — like every prior
bug TDD cycle in this repo (#1060, #1182 precedent) — has no registered
artifacts because the fix's surface is the generator itself, exercised
through in-process `CliRunner` runs against temp projects. The audit
follows the extension's fallback contract, stated explicitly under
"Not proved". `zfa tdd run` is additionally not wired for bug dirs (the
run-side gap of #1182) — see cycle-log.

## Red (before the fix) — ACTUAL

Test: `test/commands/setup_app_shell_naming_test.dart`, run against the
base (stashed) state:

```
dart test test/commands/setup_app_shell_naming_test.dart
→ 00:12 +1 -6: Some tests failed.
```

The six REDs reproduce the reported bug exactly (A1×2, A2/A5, A3, A6,
A7): every generated project got `my_app.dart` / `MyApp` regardless of its
name; a legacy `my_app.dart` was regenerated in place with no notice. The
+1 is A4 — the `my_app` back-compat guard, which passes pre-fix by design.

## Green (after the fix) — ACTUAL

```
dart test test/commands/setup_app_shell_naming_test.dart
→ 00:02 +7: All tests passed!
```

All seven behaviors: derived file + class for `zik_zak` and `xyx`
(A1–A3, A5), legacy collapse for `my_app` (A4), legacy-file preservation
byte-for-byte + informational notice (A6), `--xray` wiring under the
derived class name (A7).

## Post-fix end-to-end reproduction — ACTUAL (real command, not dry-run)

```
cd /tmp && rm -rf zfa1465_repro && \
dart run bin/zfa.dart setup zik_zak --no-git    (repo root as zfa source)
→ exit 0; "[8/9] Generating app shell (ZuraffaApp)...
   ✓ lib/src/app/zik_zak.dart"
   ℹ️  lib/main.dart was the flutter-create Hello-World stub — replaced.

grep main.dart  →  import 'package:zik_zak/src/app/zik_zak.dart';
                   runApp(const ZikZakApp());
grep shell      →  class ZikZakApp extends StatelessWidget

cd /private/tmp/zik_zak && flutter analyze
→ "2 issues found. (ran in 63.0s)" exit 0 — zero errors/warnings
  (2 pre-existing infos: type_init_formals on the super-key param,
   depend_on_referenced_packages on the bootstrap DI barrel; both
   unrelated to the naming change)
```

The original symptom (`xyx.dart`/`my_app.dart` mismatch) no longer
reproduces on the exact command from the report.

## Regression coverage — ACTUAL

- `dart analyze lib test` → 0 errors / 0 warnings.
- Fast tier: `setup_command_test.dart`, `test/tdd/1444-setup-zuraffa-app/`,
  `app_shell_pubspec_deps_test.dart`, `package_mode_filter_test.dart`,
  `test/plugins/skeleton/` → green.
- Slow tier (`--preset=all`): `test/plugins/app_shell/`,
  `issue_469` (xray stub), `issue_512` (pure-Dart guard), `issue_181`
  (release-mode strip), `docs_command_consistency` → green.
- 3 failures in `test/commands/app_shell_command_test.dart` were verified
  red on the stashed base commit (coreImport expectations vs the
  flavor-based import shipped earlier) — pre-existing, not introduced.

## Not proved

- The mutation-test gates (spec 044 FR-012..023) did not run: no
  registered per-behavior artifacts exist for a bug-dir feature, and the
  zfa run engine cannot consume bug dirs yet (run-side of #1182). The
  fallback evidence above (true RED → GREEN with behavior-level tracing)
  is the accepted substitute per the extension's fallback contract.
- `zfa setup xyx` was not run against a real `flutter create` (the same
  code path as the verified `zik_zak` run; the `xyx` shape is pinned by
  A3's end-to-end in-process assertion instead).
- The heavyweight whole-folder `dart test test/commands test/cli` chunk
  was aborted at the 30-minute ceiling; every shell-related file in those
  folders was run individually instead.

## Verdict

PASS_WITH_GAPS — the bug is fixed and verified end-to-end including a
real `flutter create`-backed `zfa setup`; the gap is procedural (no
machine mutation audit available for bug-dir features), not behavioral.
