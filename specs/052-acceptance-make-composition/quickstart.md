# Quickstart: the real-pipeline phase-2 flip

Feature: 052-acceptance-make-composition | Date: 2026-09-01

Drive a feature whose acceptance behavior is pure prose to all-DONE through
the real `zfa tdd run` pipeline — the flip that was impossible before this
feature.

## Prerequisites

- Dart 3.13+ (`dart --version`), the zuraffa repo checked out.
- A temp target project with the tdd profile + registry (the scenario
  fixtures do this; the manual steps below mirror SC-021).

## Steps

```bash
# 1. Create a temp project with a tdd profile (see
#    test/plugins/tdd/helpers/tdd_fixture.dart for the canonical shape).
#    Give it one acceptance behavior (pure prose) + one unit behavior:
#    test list rows, for example:
#      | A1 | the signup flow creates an account | FR-001 | PENDING |  (## Outer loop:)
#      | U1 | unit behavior backing A1            | FR-001 | PENDING |  (## Inner loop:)

# 2. Pure exec forwarder to the real CLI (SC-017/SC-018 pattern):
cat > fake_bin/zfa <<'EOF'
#!/usr/bin/env bash
exec "<dart>" "<zuraffa-repo>/bin/zfa.dart" "$@"
EOF
chmod +x fake_bin/zfa

# 3. Gen + certify red for both behaviors (real steps):
dart run <zuraffa-repo>/bin/zfa.dart tdd gen A1 --project .
dart run <zuraffa-repo>/bin/zfa.dart tdd verify-red A1 --project .
dart run <zuraffa-repo>/bin/zfa.dart tdd gen U1 --project .
dart run <zuraffa-repo>/bin/zfa.dart tdd verify-red U1 --project .

# 4. Drive the loop (real pipeline end to end):
dart run <zuraffa-repo>/bin/zfa.dart tdd run <feature> --project . --zfa-bin fake_bin/zfa
```

## Expected (after this feature)

```text
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> deferred (phase 2)        # planner refuses prose; no green units yet
[run] U1 gen -> ok
[run] U1 verify-red -> certified
[run] U1 make -> green                      # unit pipeline (entity/CRUD or fixture-backed)
[run] U1 refactor -> deferred (phase 2)     # bug #635: A1 sits RED
[run] A1 make -> green (phase 2)            # THE FLIP: make falls back to compose+build
[run] A1 refactor -> clean (phase 2)
[run] U1 refactor -> clean (phase 2)
run: feature=<feature> result=complete pending=0 red=0 green=0 done=2
```

And in `specs/<feature>/tdd/cycle-log.md`, A1's green entry lists the
captured steps including `zfa tdd compose A1` (SC-002).

## Expected (before this feature — the gap this closes)

The phase-2 re-attempt of A1's make deterministically reported
`unexpressible` again and the run honest-stopped:

```text
[run] A1 make -> unexpressible (phase 2)
run: feature=<feature> result=stopped ... stopped_at=A1:make
```

## Also verify the honest stops survive

- Same fixture, but delete the unit behavior's green evidence before the
  run → phase 2 stops non-zero at `A1:make` with `unexpressible`, units
  green (SC-003).
- A feature whose unexpressible behavior is unit-kind → the run stops at
  that behavior's make in phase 1, never composing (SC-004).
