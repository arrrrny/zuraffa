# Quickstart: validating `zfa tdd corpus` (spec 051-corpus-harness)

Runnable validation scenarios. The full behavior matrix lives in the test
suite (`test/plugins/tdd/…corpus…`, `test/plugins/tdd/scenarios/
sc_020_corpus_harness_e2e_test.dart`); this guide proves the loop manually
with the same scripted-fake technique.

## Prerequisites

- Dart 3.13+ on PATH; this repo checked out; `dart pub get` run.
- A scratch "app" directory with a corpus manifest — the fixtures below
  build it with shell.

## 1. Drive a 3-feature fixture corpus (US1 — drive, stop, resume)

```sh
APP=$(mktemp -d)/app && mkdir -p "$APP/.zfa/manifests" "$APP/specs"
# manifest: f1 ready, f2 ready (will gap), f3 not-ready
cat > "$APP/.zfa/manifests/corpus-manifest.json" <<'JSON'
{"features": [
  {"name": "f1-good",  "ready": true,  "reason": ""},
  {"name": "f2-gap",   "ready": true,  "reason": ""},
  {"name": "f3-later", "ready": false, "reason": "no acceptance scenarios"}
], "sourceCorpus": "/corpus", "importedAt": "2026-08-31T00:00:00Z"}
JSON
for f in f1-good f2-gap f3-later; do mkdir -p "$APP/specs/$f/tdd"; done
```

Script a fake zfa that completes f1 (run exit 0, verify `gate=pass`),
stops f2 (`result=stopped stopped_at=B-002:make`), never sees f3:

```sh
mkdir -p "$APP/fake" && cat > "$APP/fake/zfa" <<'SH'
#!/bin/sh
case "$*" in
  *"run f1-good"*)        echo "run: feature=f1-good result=complete pending=0 red=0 green=1 done=1"; exit 0;;
  *"verify --feature f1-good"*) echo "mutation: gate=pass killed=2 survived=0 timed_out=0 mutation_was_run=true"; exit 0;;
  *"run f2-gap"*)         echo "run: feature=f2-gap result=stopped pending=0 red=1 green=0 done=0 stopped_at=B-002:make"; exit 1;;
esac
exit 2
SH
chmod +x "$APP/fake/zfa"
```

```sh
dart bin/zfa.dart tdd corpus run --project "$APP" --zfa-bin "$APP/fake/zfa"
echo "exit=$?"                       # 1 (STOP-ON-ROADBLOCK)
cat "$APP/.zfa/corpus/gap-ledger.json"   # gap-001: f2-gap, B-002, run, stopped
cat "$APP/.zfa/corpus/progress.json"     # f1 done+gated, f2 stopped, f3 untouched
```

Fix the gap (re-script f2's run/verify to succeed) and re-run:

```sh
# "Fix" the gap: replace the fake with success defaults.
cat > "$APP/fake/zfa" <<'SH'
#!/bin/sh
case "$*" in
  tdd\ run*)    echo "run: feature=default result=complete pending=0 red=0 green=1 done=1"; exit 0;;
  tdd\ verify*) echo "mutation: gate=pass killed=1 survived=0 timed_out=0 mutation_was_run=true"; exit 0;;
esac
exit 2
SH
chmod +x "$APP/fake/zfa"
dart bin/zfa.dart tdd corpus run --project "$APP" --zfa-bin "$APP/fake/zfa"
echo "exit=$?"                       # 1 — incomplete: f3 not-ready (honest)
```

Expected: f1 never re-spawned across the resume; ledger gained a
resolution entry, gap-001 untouched (append-only); f3 still reported
not-ready and never spawned; final line
`corpus: features=3 done=2 waived=0 stopped=0 not_ready=1 pending=0 … result=incomplete`
with exit 1 (the not-ready feature blocks completion honestly — fix its
spec or re-import to mark it ready, then exit 0).

## 2. Gate matrix + waiver (US2)

Re-point the fake's verify at each gate label
(`fail_survived`, `fail_timeout`, `preflight_red`, `not_assessed`):
each stops the corpus non-zero with a ledger entry naming the label
(NOT_ASSESSED included — surfaced, never absorbed). Then record a waiver
and re-run:

```sh
cat > "$APP/.zfa/corpus/waivers.json" <<'JSON'
[{"feature": "f2-gap", "gate": "not_assessed",
  "reason": "mutation tool unavailable on CI image; suite guard green",
  "actor": "maintainer", "at": "2026-08-31T01:00:00Z"}]
JSON
```

Expected with the fake reporting `gate=not_assessed`: f2 → `waived`,
the waiver (reason + actor + at) visible in progress and the final
report; a waiver for a DIFFERENT gate does not absorb a failure.

## 3. Provenance audit (US3)

```sh
mkdir -p "$APP/lib" "$APP/.zfa/provenance" "$APP/.zfa/manifests"
echo 'class A {}' > "$APP/lib/generated.dart"      # covered by artifacts.json below
echo 'class M {}' > "$APP/lib/manual_ui.dart"      # carve-out
echo 'class X {}' > "$APP/lib/mystery.dart"        # unattributed -> fail
cat > "$APP/specs/f1-good/tdd/artifacts.json" <<'JSON'
{"feature": "f1-good", "records": [
  {"behavior_id": "B-001", "feature": "f1-good", "source_criterion": "FR-001",
   "test_path": "test/b_001_test.dart", "subject_path": "lib/generated.dart",
   "runnable_test_name": "t", "test_ownership": "created",
   "subject_ownership": "created", "created_at": "2026-08-31T00:00:00Z"}]}
JSON
cat > "$APP/.zfa/manifests/corpus-carveout.json" <<'JSON'
{"carveouts": [{"path": "lib/manual_ui.dart", "reason": "manual UI (epic 045 carve-out)"}]}
JSON
cat > "$APP/.zfa/provenance/setup.json" <<'JSON'
{"command": "zfa setup demo --specs /corpus", "at": "2026-08-31T00:00:00Z",
 "files": ["lib/main.dart"]}
JSON
echo 'void main() {}' > "$APP/lib/main.dart"

dart bin/zfa.dart tdd corpus audit --project "$APP"; echo "exit=$?"   # 1, names lib/mystery.dart
rm "$APP/lib/mystery.dart"
dart bin/zfa.dart tdd corpus audit --project "$APP"; echo "exit=$?"   # 0 (100%)
cat "$APP/.zfa/corpus/audit-report.json"
```

Removing `lib/manual_ui.dart`'s carve-out entry flips it to unattributed
(the manifest is the only exemption path — US3.AC3).

## 4. Status + concurrency (US5, FR-010)

```sh
dart bin/zfa.dart tdd corpus status --project "$APP"; echo "exit=$?"
# exit 0 iff all manifest features done|waived; prints resume_at while incomplete
```

Start a second `corpus run` while one is in flight (a fake that sleeps):
the second refuses with `result=concurrent-run`, exit 4, no state
corruption.

## 5. Real repo checks

```sh
dart analyze && tools/run_tests_chunked.sh   # 0 issues; corpus tests pass
dart format --set-exit-if-changed lib test   # no diff
```
