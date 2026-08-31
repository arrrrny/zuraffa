# Quickstart: `zfa tdd corpus` — validation scenarios

## Prerequisites

- Zuraffa repo at project root with `dart pub get` done.
- Corpus imported via `zfa tdd corpus run` requires a manifest at
  `.zfa/manifests/corpus-manifest.json` (from `zfa corpus import`).

## Scenario 1: 3-feature fixture — run, stop, resume

**Setup**: Create a fixture with three features:
- `001-ready` — all behaviors pass (mock zfa bin returns success).
- `002-gap` — `make` step returns `unexpressible` (simulates a zuraffa gap).
- `003-not-ready` — marked not-ready in manifest.

**Commands**:
```bash
# First run: drives 001 to done, stops on 002, skips 003
zfa tdd corpus run --project /path/to/fixture
# Expected: exit 1, 001 done, 002 stopped, gap ledger has 1 entry

# Re-run after "fixing" the gap (update mock to succeed):
zfa tdd corpus run --project /path/to/fixture
# Expected: resumes at 002, drives it to done, exit 0
```

**Verification**:
- `zfa tdd corpus status --project /path/to/fixture` shows `done=2 stopped=0 pending=0 not_ready=1`
- Gap ledger has 2 entries: one for the stop, one for the resolution
- `001` was NOT re-driven (0 duplicate invocations)

## Scenario 2: Verify gate outcomes

**Setup**: Fixture with features exercising each gate value.

**Commands**:
```bash
zfa tdd corpus run --project /path/to/gate-fixture
```

**Expected outcomes per gate**:
| Gate | Corpus behavior |
|------|-----------------|
| PASS | feature marked done |
| FAIL_SURVIVED | stop + ledger entry |
| FAIL_TIMEOUT | stop + ledger entry |
| PREFLIGHT_RED | stop + ledger entry |
| NOT_ASSESSED | stop + ledger entry (reason: "mutation tool unavailable") |
| Waived | feature marked waived with recorded reason |

## Scenario 3: Provenance audit

**Setup**: A corpus-driven app with `lib/` files from cycle logs and one
manually-declared carve-out.

**Commands**:
```bash
zfa tdd corpus audit --project /path/to/app
# Expected: exit 0, 100% attribution

# Plant an unattributed file:
touch lib/src/unattributed.dart
zfa tdd corpus audit --project /path/to/app
# Expected: exit 1, names lib/src/unattributed.dart as UNATTRIBUTED
```

## Scenario 4: Status at a glance

**Commands**:
```bash
zfa tdd corpus status --project /path/to/app
```

**Expected output** (partial):
```text
corpus status: 001-app done (gate=PASS)
corpus status: 002-broken stopped (gate=FAIL_SURVIVED) — 1 unresolved gap
corpus status: 003-manual waived (reason="manual UI per carve-out")
corpus status: 004-pending pending
corpus status: done=1 stopped=1 waived=1 pending=1 not_ready=0 dropped=0 total=4 gaps=1 unresolved=1 resume=002-broken
```

Exit 1 (incomplete).

## Scenario 5: Concurrent run refusal

**Commands** (in two terminals):
```bash
# Terminal 1: start a long corpus run
zfa tdd corpus run --project /path/to/app &

# Terminal 2: attempt a second run
zfa tdd corpus run --project /path/to/app
# Expected: exit 4, message about concurrent run
```
