# Assessment — doctor named checks + auto-heal (#793)

## Current state

`DoctorCommand` (lib/src/commands/doctor_command.dart) only reports tooling
versions, pubspec presence strings, zorphy global install, a dead-code scan,
and v5 migration readiness. Its `--fix` flag is consumed exclusively by the
migration section. Every environment failure mode the command-matrix
healthcheck actually hit requires a human to already know the remedy:

1. **Baseline cache** — `RunBaselineCache.read` is fail-safe by design: it
   returns null on missing/corrupt/malformed and the caller silently falls
   back to a live full-suite run (slow, but invisible). Nothing surfaces WHY
   the cache was rejected.
2. **Dev dependencies** — after cloning a generated project, the TDD loop's
   dev-deps (`mocktail`, `coverage`, `mutation_test`) may be absent; the loop
   fails at test time with errors far from the root cause.
3. **Build artifacts** — `zfa build` diagnostics hit partial build_runner
   output (entity source present, sibling `.g.dart`/`.zorphy.dart` missing).
4. **Config** — malformed `.zfa.json` or stale plugin keys go unnoticed
   until a command reads them.
5. **Profile** — a project with `specs/` but no `.specify/memory/tdd-profile.md`
   cannot run the TDD family; the remedy (`zfa tdd init`, idempotent) is
   undocumented at the failure site.

## Design

New pure module `lib/src/commands/doctor_checks.dart`:

- `DoctorCheckResult` — id / status (`pass|fail|fixed|warn|skipped`) / detail /
  `suggestedFix` (exact command) / `fixedItems`. `ok` = pass|fixed|warn|skipped.
- `DoctorChecksRunner.runAll({required bool fix})` — executes the five named
  checks against the project root (defaults to `Directory.current`):
  | id | fails when | --fix |
  |---|---|---|
  | `deps` | TDD project (specs/ or .specify/ present) missing any of mocktail/coverage/mutation_test dev-deps; zuraffa pin major behind CLI → warn | `dart pub add dev:<missing…>` via injected process runner |
  | `artifacts` | entity source under lib/src/domain/entities lacking sibling `.g.dart`/`.zorphy.dart` | `dart run build_runner build --delete-conflicting-outputs`, then re-verify |
  | `baseline-cache` | any specs/*/tdd/run-baseline.json is unreadable, schema-invalid (reason reported), or stale (test/ tree newer than capturedAt) | delete offending cache files (next run re-captures live) |
  | `config` | .zfa.json malformed JSON; unknown plugin keys → warn | suggested-only (`zfa config init`) |
  | `profile` | specs/ present but .specify/memory/tdd-profile.md missing | in-process `InitCommand(TddPlugin())` with `--project <root>` (idempotent) |
- `ZfaProcessRunner` typedef injected so fixes are test-stubbable; real
  default wraps `Process.run` with per-command timeouts.
- `doctorChecksOk(results)` and `encodeDoctorChecksJson(results, …)` exported
  for the command layer.

`DoctorCommand` wiring (backwards-compatible):

- New `--format text|json` (default text). json mode emits exactly ONE JSON
  object `{"schema":"doctor.v1","checks":[…],"ok":<bool>}` and skips the
  tooling/migration prose (migration readiness stays a text-mode concern);
  no other stdout is emitted in this mode.
- Named checks run unless `--migration-only`. `--fix` keeps its existing
  migration meaning and additionally heals the mechanical named checks;
  `--dry-run` previews would-fix lines without applying anything.
- Exit protocol: `exitCode = 0` when every check is ok, `1` when any check
  still fails after the (optional) fix pass. Migration findings do not
  affect the exit code (existing CI behavior preserved).

## Risk / blast radius

- DoctorCommand is a leaf diagnostic command; no generator or TDD pipeline
  code is touched except in-process reuse of the existing idempotent
  `InitCommand`.
- New flag `--format` cannot collide (`doctor` had no format flag).
- Exit code changes from always-0 to 0/1 — this is the requested contract
  (issue AC: "exit code (non-zero if any check remains failed) — CI-able").

## Verification plan

15 behaviors (U1–U15) in test/commands/doctor_checks_test.dart, red first,
then green, then an 8-mutant matrix over doctor_checks.dart + doctor exit
wiring with 0 SURVIVED required, then full `dart analyze` + `dart test`.
