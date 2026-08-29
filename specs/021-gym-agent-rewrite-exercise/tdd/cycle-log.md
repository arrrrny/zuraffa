# Cycle Log: GYM Exercise — Agent Rewrite of a Dart Package Using Only zfa

Append only. Newest last. Every entry's `red` block is the evidence that the
assertion existed and failed before the implementation. The graded test
surface is the exercise script itself (`dart run
.gym/exercise-agent-rewrite-zfa-only.dart`); commands below are verbatim
runs from the repo root on branch `021-gym-agent-rewrite-exercise`.

## Baseline

- suite: existing exercise `dart run .gym/exercise-generate-feature.dart` → `EXERCISE PASSED` exit 0; `dart analyze` → 111 issues / 23 pre-existing errors (zikzak_session/ + examples/mcp_demo/, missing git submodule content — identical to the master baseline documented in specs/038 tdd/verification.md §5), exit 3
- commit: `b2af3cb4` (master)
- recorded: cycle 0, before any change

## Cycle 1: U1–U3 setup phase (zfa root, sandbox, fixture staging)

- test: setup-phase assertions in `.gym/exercise-agent-rewrite-zfa-only.dart` (new) — zfa bin discovery, fixture presence, sandbox wipe/create, `__ZURAFFA_ROOT__` normalization, `dart pub get`, manifest load
- red: `dart run .gym/exercise-agent-rewrite-zfa-only.dart` → `EXERCISE FAILED: agent-rewrite-zfa-only — Required fixture missing: …/.gym/fixtures/sample-crud-package/pubspec.yaml — the exercise targets are embedded under .gym/fixtures/ (FR-003).` exit 1 — fixtures did not exist yet, so the staging assertion failed for the right reason
- green: created the four fixture files (`.gym/fixtures/sample-crud-package/{pubspec.yaml, rewrite-manifest.json, lib/legacy_note.dart, lib/legacy_tag.dart}`, `.gym/fixtures/plain-dart-package/{pubspec.yaml, lib/main.dart}`) → `SETUP OK: sandbox staged with 2 manifest entities under …/.gym/.sandbox/exercise-agent-rewrite-zfa-only` (then continued to the intentional LEG A red stub). `git status` after a full run: no tracked file modified — FR-006 isolation holds
- refactor: none needed

## Cycle 2: U4–U5 compatibility detection (zfa doctor markers)

- test: `_detectCompatibility()` + marker/mutual-exclusivity assertions for both legs (new)
- red: none recorded — born green. `zfa doctor` is a pre-existing capability (verified against master in plan.md research), so the assertions passed the first time they ran
- green: `LEG A detection OK: Zuraffa-compatible target confirmed via zfa doctor markers.` + `LEG B detection OK: non-compatible target confirmed via zfa doctor markers — protocol routes to STOP-AND-REPORT.`
- teeth (in lieu of red): the assertions are cross-coupled — leg A requires the compatible markers AND the absence of `Zuraffa package not found` (mutual exclusivity), leg B requires both not-found markers AND that the compatible verdict is false. Pointing either assertion at the wrong fixture fails it; the coupling was exercised implicitly because both fixtures run through the same classifier in one process
- refactor: none needed

## Cycle 3: U6–U9 rewrite leg (entity create → make → build → v5 verification)

- test: canonical v5 verification block in the exercise script (entity file + `@Zorphy` + field getters + codegen parts + repository/datasource/usecase paths per entity, plus step 2–4 exit-code assertions)
- red: protocol invocations temporarily disabled (`if (false)` wrap of steps 2–4; verification intact) → `dart run .gym/exercise-agent-rewrite-zfa-only.dart` → `EXERCISE FAILED: agent-rewrite-zfa-only — LEG A verify: canonical v5 entity file missing for Note — expected …/target/lib/src/domain/entities/note/note.dart (lib/src/domain/entities/note/note.dart).` exit 1 — the exact named-missing-artifact failure the assertions exist to produce (U9's failure shape)
- green: invocations restored → `LEG A step 2 OK: 2 entities created via zfa entity create.` / `LEG A step 3 OK: architecture generated via zfa make (datasource repository usecase).` / `LEG A step 4 OK: zfa build compiled the rewritten package (dart analyze: no errors).` / `LEG A verify OK: all 2 entities match the canonical v5 layout (entities + repositories + datasources + usecases + codegen parts).`
- refactor: extracted `_runZfa` (single choke-point for every zfa invocation — structural enforcement of FR-008) and `_snakeCase`
- note: `Note` carries a `DateTime` field (`createdAt`) — verified during planning research that zorphy codegen + `zfa build` handle it (`dart analyze: no errors`)

## Cycle 4: U10–U12 stop-and-report leg + exit-code grading

- test: report assertions (file exists; `## Package` / `## Verdict` / `## Why it is not compatible` / `## What would make it compatible` sections; verdict text; cited doctor markers; remediation deps) + no-misfire assertions (lib/ pristine, no `lib/src/domain/entities/` tree)
- red: report writer not yet implemented → `dart run .gym/exercise-agent-rewrite-zfa-only.dart` → `EXERCISE FAILED: agent-rewrite-zfa-only — LEG B verify: structured report missing — expected …/plain/NOT-ZURAFFA-COMPATIBLE.md. The stop-and-report protocol must leave a NOT-ZURAFFA-COMPATIBLE.md beside the target.` exit 1
- green: implemented `_stopAndReport()` (the trained behavior made executable: outcome + doctor evidence + remediation, no rewrite command) → `LEG B stop-and-report OK: NOT-ZURAFFA-COMPATIBLE.md written; no rewrite command invoked.` + `LEG B verify OK: stop-and-report protocol observed — structured report present, no rewrite artifacts, lib/ pristine.` + `EXERCISE PASSED: agent-rewrite-zfa-only — compatible target rewritten zfa-only into canonical v5 layout; non-compatible target correctly stopped-and-reported.` exit 0
- refactor: report rendering moved into `_stopAndReport()`; no-misfire enforcement documented as structural (no `_runZfa` call against the plain target anywhere in leg B)
- U12 evidence: exit 0 on the passing run above; exit 1 with `EXERCISE FAILED: agent-rewrite-zfa-only — …` on every red run in this log (fixture missing / v5 file missing / report missing)

## Cycle 5: U13–U14 registry integration + A3 determinism

- test: registry entry shape in `.gym/gym.yaml` + regression run of `generate-feature` + two consecutive clean-sandbox runs of the new exercise
- red: none recorded — the registry file edit is declarative; the "assertion" is the runner consuming the YAML. Validated by parse + regression runs instead (born green)
- green: `python3 -c yaml.safe_load` → exercises `['generate-feature', 'agent-rewrite-zfa-only']`; run 1 exit 0, run 2 exit 0, `ls -R | sort` diff across both runs → identical (A3 determinism: same file set, US4-S2); regression `dart run .gym/exercise-generate-feature.dart` → `EXERCISE PASSED: generate-feature — artifact is real.` exit 0 (U14)
- refactor: none needed
