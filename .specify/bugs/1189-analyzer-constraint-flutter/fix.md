# Fix report — Issue #1189

Branch: `fix/1189-analyzer-constraint-flutter` (one PR, closes #1189).
TDD mode: driven through the red-green-refactor loop recorded in
`tdd/cycle-log.md` per `tdd_enabled` in bug-config.yml.

## What changed and why

1. **`pubspec.yaml` — `test: any` moved from `dependencies:` to
   `dev_dependencies:`.** This was the DIRECT resolution blocker: against
   flutter_test's SDK pins (test_api 0.7.12, matcher 0.12.20) no
   published `test` version fits the graph (solver proof in
   `red-evidence-flutter-pubget.md`). lib/src only references
   package:test inside string templates that generate consumer test
   files (those consumers declare test in their own dev_dependencies);
   the lib/tdd/** self-hosting subjects resolve against this package's
   dev_dependencies. Rationale documented inline in the pubspec.

2. **`pubspec.yaml` — analyzer widened `^14.3.0` → `">=14.0.0 <15.0.0"`.**
   The report's suggested widening. Kept as a REGULAR dependency on
   purpose: `lib/zuraffa.dart` publicly exports `src/core/ast/*`
   (lib/zuraffa.dart:241–244) and 30 lib/ files hard-import
   package:analyzer, so a dev_dependencies move would break consumer
   compilation. The widened lower bound is verified honest (T5:
   analyzes clean with analyzer pinned 14.0.0).

3. **`analysis_options.yaml` — repo-wide
   `depend_on_referenced_packages: ignore` with rationale.** Moving
   `test` to dev_dependencies made the analyzer flag all ~115 lib/tdd/**
   self-hosting subjects (test fixtures living under lib/ by design).
   Info count restored to the pre-fix baseline of 103 (T6).

4. **`example/pubspec.yaml` — dropped the `meta: ^1.18.3` dependency
   override.** Flutter 3.47.x re-pinned meta to ^1.18.3, exactly the
   condition the issue #891 comment named for removal. example/ now
   resolves with ZERO overrides — the bug's acceptance condition.

5. **`tools/flutter_smoke_gate.sh` (new) + `ci.yaml`
   `flutter_consumer_smoke` job (new).** Three-stage gate: example/
   resolves; a synthesized core+flutter_test app resolves with zero
   overrides; `flutter test` compiles+runs the public surface. CI never
   saw this class of breakage because every job used `--no-example`; the
   gate closes that hole and is proven non-vacuous (T4: exit 1 on the
   pre-fix tree).

6. **`.specify/bugs/1189-analyzer-constraint-flutter/**` — issue record,
   assessment, bug spec, TDD artifacts, red/green evidence logs.**

## Files

- pubspec.yaml
- analysis_options.yaml
- example/pubspec.yaml (+ example/pubspec.lock regenerated)
- tools/flutter_smoke_gate.sh
- .github/workflows/ci.yaml
- .specify/bugs/1189-analyzer-constraint-flutter/**

## Verification

See `tdd/verification.md` for the gate verdict and pass/fail counts.
