# Plan: 1009-realize-mock-firestore-differential

- **Spec ID**: 1009-realize-mock-firestore-differential
- **Created**: 2026-09-05

## Architecture

```
┌────────────────┐  zfa tdd realize-mock <Entity>   ┌──────────────────────┐
│  TIER 1        │  --against=firestore             │  TIER 2              │
│  mock era      │                                  │  Tier2MockProvider   │
│                │   contract test (registered)     │  (Firestore-shaped)  │
│  mockOutput    │   ── must be GREEN first ──▶     │                      │
│  (oracle) or   │                                  │  FakeFirebaseFirestore│
│  tier-1 driver │   per method: compare            │  typed REST values   │
│                │   ◀────── fixtures ──────────▶   │  per-case seed       │
└────────────────┘                                  └──────────────────────┘
        │                                                      │
        └──── receipt realize.<Entity>.firestore.receipt.json ─┘
             (proof.v1 envelope + per-method diff) + cycle-log
             era MOCKED, kind realize-mock
```

The command is a **certification**, not a crossing: nothing in the target
tree is mutated (the only writes are the receipt and the cycle-log entry),
the Tier-2 swap lives for the duration of the run, and the era stays
MOCKED. `zfa tdd realize` (#913) remains the only sanctioned MOCKED → REAL
crossing.

## Phases

### Phase 1: the Firestore-shaped fake store
- `lib/src/plugins/tdd/services/tier2_firestore/fake_firebase_firestore.dart`
- In-memory `FirebaseFirestore` surface: `collection(name).doc(id)` with
  `get` / `set` / `delete`; collection `get()` lists documents in
  document-id order (deterministic — a differential gate needs stability).
- Typed-value codec matching the REST wire shape the skeleton's Firebase
  data source reads/writes: `integerValue` / `doubleValue` /
  `stringValue` / `booleanValue` / `mapValue` / `arrayValue` /
  `nullValue`. Ints stay ints, doubles stay doubles — type fidelity is
  the gate's teeth. Unsupported types throw (fail-closed).

### Phase 2: the Tier-2 adapter
- `lib/src/plugins/tdd/services/tier2_firestore/tier2_mock_provider.dart`
- Same invocation surface as the Tier-1 mock driver contract: method name
  + args in, result JSON out. Entity-qualified names
  (`getLoginById` / `getAllLogins` / `saveLogin` / `deleteLogin`) and
  generic ones (`getById` / `getAll` / `save` / `delete` / `exists`) hit
  the same routes.
- `seed(records)` clears + loads the collection (per-case deterministic
  state); a method outside the CRUD surface is a `Tier2MockMethodError`
  naming the method (never a guess).

### Phase 3: the differential receipt
- `lib/src/plugins/tdd/services/realize_mock_receipt.dart`
- `realize.<Entity>.firestore.receipt.json` under `.zfa/receipts/`
  (stable name = latest state per (entity, against) pair).
- Double-shaped document: top-level `methods`
  (`{method, tier1_result, tier2_result, diff}`), `verdict`, plus the
  `proof.v1` envelope keys (`schema` / `command` / `target` / `repro` /
  `at` / `generator_version` / `input` / `files: []`) — parseable and
  counted by `zfa proof check` with zero findings.

### Phase 4: the command
- `lib/src/plugins/tdd/commands/realize_mock_command.dart`, registered in
  `TddCommand` after `RealizeCommand` (additive — realize untouched).
- Flow: validate (`--against` allow-list) → resolve entity through the
  registries → run the Tier-1 contract test (injectable suite runner;
  production `dart test`) → load fixtures (fail-closed on empty/malformed)
  → per case: Tier-1 oracle (recorded `mockOutput`, else the tier-1
  driver protocol) vs a fresh seeded Tier2MockProvider → JSON-equality
  diff → receipt + era-tagged cycle-log entry (era MOCKED, kind
  realize-mock) → machine summary line; exit 0 iff every `diff == none`.
- Fail-closed classes: `usage-error` (args), `blocked` (preconditions),
  `tier1-red` (broken baseline), `runner-error` (driver/fixture faults).

### Phase 5: verification
- Acceptance tests driving the public CLI surface in-process (the realize
  command test pattern): SC-1 certified, SC-2 divergent method named,
  SC-3 proof-check integration, plus precondition/mode coverage.
- End-to-end production proof: real CLI, real `dart test` subprocess,
  real receipt, `zfa proof check` parse, deliberate wrong-type divergence
  → exit 1.
- `/speckit.tdd.verify` → `tdd/verification.md` with real session
  evidence (engine detection, mutation sampling, full-suite counts).

## Risks / mitigations

- **Oracle ambiguity**: the Tier-1 side needs a source of truth — the
  recorded `mockOutput` (the #832 fixture commitment) is primary; the
  project-owned tier-1 driver protocol is the fallback when a fixture
  records none. Both documented on the receipt's input block.
- **Dart num equality hides int/double drift**: `42 == 42.0` is true in
  Dart — the comparison runs on the JSON encoding (`'42'` vs `'42.0'`),
  and the fake Firestore's typed codec keeps the values distinct at the
  storage layer.
- **Receipt vs proof check**: a foreign JSON in `.zfa/receipts/` could
  break or pollute `zfa proof check` — the receipt is a well-formed
  `proof.v1` document with `files: []` (counted, zero findings), verified
  by test and by the end-to-end run.
