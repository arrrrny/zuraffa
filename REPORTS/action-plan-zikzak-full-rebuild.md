# Action Plan: Zuraffa Capable of Building ZikZak from Scratch — 100% zfa TDD

**Goal:** Make every ZikZak feature (all ~120 specs) generatable via `zfa tdd`, with handwritten UI views fully contracted, tracked, and supporting dual-platform layouts (macOS + mobile iOS/Android).

---

## Track Architecture (5 parallel tracks)

```
Track 1: MACHINE CONTRACT         Track 2: TDD LOOP          Track 3: PRESENTATION
(honesty sweep + unification)     (finder-kind + i18n)        (views + layouts + ledger)
        ↘                              ↓                           ↙
         Track 4: ISOLATION & MERGE           Track 5: SIMULATION
         (slice proof + plug-in contract)     (worlds + replay)
```

---

## Track 1: Machine Contract — The Honesty Sweep

**Goal:** Every plugin tells the truth. Exit codes are correct. `--json` is the universal output contract. Receipts cover every generation path.

### Phase 1.1: Exit-Code Sweep (Week 1)

Fix the ~15 lying command bodies in one pass. Pattern: add `exitCode = 64; return;` to bare-command and failure paths.

**Plugins to fix:** view, controller, datasource, shadcn, xray deck, gym, gql, graphql generate/introspect, feature, presenter, api, module, observer, cache (RangeError), sync (RangeError)

### Phase 1.2: Verdict Envelope Unification (Week 2-3)

Close #1105: one canonical `zuraffa.verdict.v1` envelope. Every plugin's `--json` output conforms to:
```json
{"schema":"verdict.v1","command":"zfa X","result":"ok|error|skipped","exit_class":0,"message":"..."}
```

### Phase 1.3: Receipts Everywhere (Week 3-4)

Extend `.zfa/receipts/` from the orchestrated `make` path to standalone invocations. Every plugin's `execute()` writes a proof.v1 receipt before reporting success.

### Phase 1.4: OpenWiki Fleet Docs (Week 4)

Close #1104: every A+ plugin documented in `openwiki/cli.md` with `--json` envelopes and verify exit codes.

---

## Track 2: TDD Loop — Finder-Kind, i18n, Interaction Semantics

**Goal:** The widget lane knows the difference between "shows", "navigates", "disables", and "hides". Localization keys resolve through a test shell.

### Phase 2.1: Finder-Kind Taxonomy (Week 2-3)

Close #964: scenario verbs map to finder kinds:
- `shows/renders/displays` → `find.text` (presence)
- `hides` → absence assertion
- `navigates` → `GoRouter`/`NavigatorObserver` outcome assertion
- `disables/enables` → `widget.enabled` assertion
- `while/in-flight` → interaction sequence (act → assert intermediate → resolve → assert final)

`verify-red` refuses to certify a finder whose kind doesn't match the scenario verb.

### Phase 2.2: i18n-Keyed Contracts (Week 3-4)

Close #965: spec rows declare `key: auth.signIn` with EN anchor. `zfa tdd view` emits `t.auth.signIn`. Test shell resolves keys via `LocaleTests` pinned to the base locale. Finder-kind taxonomy resolves `key:` literals through the slang system.

### Phase 2.3: Absence + State Assertions (Week 4-5)

Part of #966: `absent:` assertions are first-class in the ledger. Loading state / disabled state expressed as `state:` ledger rows. Interaction sequences traced end-to-end.

---

## Track 3: Presentation — Contracted Views + Adaptive Layouts

**Goal:** `zfa tdd view` generates deterministic, machine-checkable views that support platform layouts. Handwritten view code is tracked by receipt.

### Phase 3.1: Adaptive Layout Contract (Week 3-4)

New spec: `zfa tdd view` declares platform layout slots per spec. Generated skeleton emits `AdaptiveViewState` with per-platform layout stubs (mobile + macOS), each traced independently in the ledger.

### Phase 3.2: View/Controller/Test Plugin Cleanup (Week 2-3)

Merge `zfa view` and `zfa tdd view` (or add `--deterministic` flag). Wire view/controller into the `zfa tdd` receipt chain. Consolidate scattered test coverage into `test/plugins/view/`, `test/plugins/controller/`.

### Phase 3.3: UI Coverage Ledger (XRay Integration) (Week 5-6)

Close #963: typed ledger rows (presence/absence/navigation/state/sequence). Untraced kinds block merge. XRay overlay shows live coverage.

### Phase 3.4: shadcn Vocabulary as Contract (Week 4)

Feed the UI node registry (`zfa ui schema`) into `zfa tdd plan` — widget references in specs are validated against the vocabulary. grid/table either implemented or removed from advertised layouts.

---

## Track 4: Isolation & Merge — The Slice-First Pipeline

**Goal:** Any agent builds a feature in a sandbox with the full loop; no whole-app runs; pluggable into zik_zak with zero hand-edits.

### Phase 4.1: Prove slice on a real feature (Week 3-5)

Close #961: cut the login feature from zik_zak using `zfa slice cut`, develop in isolation, merge back. Proof that cut→develop→verify→merge works end-to-end. Add `slice verify --json` receipts.

### Phase 4.2: Dependency-Table Mocks (Week 2-4)

Close #960: FirebaseAuth, Hive, Vendure mock touchpoints generated from declared contract tables. Proved with a real feature (not just login, which declares no dependencies).

### Phase 4.3: Plug-in Merge Contract (Week 5-7)

Close #962: merge lands a feature in zik_zak with zero hand-edits. Conformance gate checks: route registration, DI binding, asset presence, localization keys. Depends on Track 1 (receipts) and Track 3 (i18n).

### Phase 4.4: Compact Feature Isolation (Week 6-8)

Per-feature compile: `zfa tdd run` doesn't need to compile the whole app. DI rebind (#913) is already the right pattern; verify it scales to 120 features with shared DI registry and route table.

---

## Track 5: Simulation & Replay — The Certified Worlds

**Goal:** Features are developed against simulated reality, not raw mocks. Every TDD cycle is reproducible.

### Phase 5.1: Simulation World Manifests (Week 4-6)

Close #968: `zfa simulate init checkout-flow` generates a world manifest (touchpoints, latency model, failure schedule, seed). `zfa simulate run` executes against the world with deterministic replay. Receipts record the world hash.

### Phase 5.2: Spec-Mutation Arena (Week 6-8)

Close #967: `zfa spec fuzz <feature>` applies spec mutations, re-runs behaviors. Survived mutants are proven spec weaknesses. Kill rate = the coverage metric that presence-counts can't fake.

### Phase 5.3: Session Replay (Week 5-7)

MCP session replay: `zfa mcp replay <session>` re-executes agent tool-call sequences as certified scenarios. Composes with xray's deck replay for interactive debugging flows.

### Phase 5.4: Chaos Testing for Background Features (Week 7-9)

`zfa sync simulate --scenario offline-flap` drives the sync strategy with scripted failing remote, asserts retry/backoff/tombstone invariants. Extends to OCR, payments, any temporal behavior.

---

## Cross-Cutting Actions (shared across tracks)

### Month 1: Fleet Health
- Kill `gql` (fold into graphql), kill `cli` phantom, decide `observer` fate
- Sweep duplicate generators (module's two paths, skeleton's StringBuffer dialect)
- Fix `xray deck` non-compiling codegen + dishonest test

### Month 2: Contract Enforcement
- Unify verdict envelope (#1105)
- `zfa manifest --verify` catches CLI schema drift
- CI gate: no commit lands with exit-0-on-error in any command

### Month 3: Documentation Alignment
- Openwiki sweep (#1104) — every A+ plugin documented
- AGENTS.md v5 contract updated with receipt and verdict expectations
- `openwiki/architecture.md` updated to reflect all 7 A-grade plugins

---

## Summary: What Success Looks Like

By month 6, an agent can:

```bash
zfa tdd init 042-user-profile
zfa tdd plan 042-user-profile        # structured JSON behaviors
zfa tdd gen A1                       # honest red, viewer-kind-aware
zfa tdd make                         # green with receipts
zfa tdd verify                       # mutation audit
zfa route verify                     # drift detection across CLI + DDA
zfa slice cut 042-user-profile       # isolated sandbox
zfa slice verify --json              # receipt
zfa simulate run user-profile-world  # simulated reality
zfa proof check                      # all receipts valid
```

And the ledger shows every screen's text, every navigation, every loading state, every absence assertion — across iOS, Android, and macOS layouts — traced to a green behavior with a machine-readable receipt.

That's not a code generator. That's a proof machine.

---

*"The dream here is bigger and quieter: Zuraffa's superpower isn't generating code. It's generating proof."*
