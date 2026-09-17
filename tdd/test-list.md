# TDD test list — issue #1417 speckit scaffolding regenerable into existing repos (`zfa initialize --speckit`)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1417-b1 | test/commands/initialize_speckit_test.dart | unit | `InitializeCommand.buildParser()` exposes `--speckit` (parse true) | FR-001 | RED → GREEN |
| U-1417-b2 | test/commands/initialize_speckit_test.dart | acceptance | `zfa initialize --speckit --root <sandbox>` emits the four Step-1 helper scripts into `<sandbox>/.specify/scripts/bash/` (exit 0) | FR-001, SC-001 | RED → GREEN |
| U-1417-b3 | test/commands/initialize_speckit_test.dart | acceptance | the emitted `setup-plan.sh` runs for an existing spec branch and exits 0 with the expected JSON keys (the #1417 exit-127 misfire, fixed end-to-end) | FR-001, SC-001 | RED → GREEN |
| U-1417-b4 | test/commands/initialize_speckit_test.dart | unit | idempotent no-clobber: a second `--speckit` run without `--force` leaves existing scaffolding byte-identical and reports skips | FR-003, SC-002 | RED → GREEN |
| U-1417-b5 | test/commands/initialize_speckit_test.dart | unit | `--speckit --force` overwrites existing scripts with the CLI-current content | FR-003 | RED → GREEN |
| U-1417-b6 | test/commands/initialize_speckit_test.dart | unit | a `.gitignore` with a `.specify/*` rule gets the force-include block appended exactly once (idempotent marker, no duplicate on re-run) | FR-004 | RED → GREEN |
| U-1417-b7 | test/commands/initialize_speckit_test.dart | unit | a `.gitignore` without `.specify` rules is left byte-identical | FR-004 | RED → GREEN |
| U-1417-b8 | test/commands/initialize_speckit_test.dart | unit | `--speckit` works in a repo without `pubspec.yaml` and creates none (surgical — no dep wiring, no entity) | FR-005 | RED → GREEN |
| U-1417-b9 | test/commands/initialize_speckit_test.dart | unit | drift guard: every embedded script constant is byte-identical to the framework repo's canonical `.specify/scripts/bash/<name>` | FR-002, SC-003 | GREEN (needs constants) |

Guard pins (pre-existing, unchanged and must stay green):

| id | suite | description |
| -- | ----- | ----------- |
| #393 | test/commands/initialize_dart_inplace_test.dart | the in-place `--dart` bootstrap contract this fix extends — `--speckit` must not disturb it |
| parser pins | test/commands/initialize_dart_inplace_test.dart | `--dart`/`--flutter`/`--deps-only`/`--no-deps` mutual exclusions unchanged |
