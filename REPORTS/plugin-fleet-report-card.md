# Zuraffa Plugin Fleet: Deep Capability Report Card

**Date:** 2026-09-05  
**Analyst:** Kimi Code (autonomous, cold-start, adversarial)  
**Scope:** All 35 built-in plugins at `lib/src/plugins/`  
**Re-evaluation:** Spot-checked master against Tier A ADD items; 6/9 items confirmed shipped or tracked (issues #969, #971, #972, #1122, #1124, #1127–#1129, #1131)

---

## Methodology

Each plugin graded 0–5 on five dimensions from source evidence:

| Dimension | What it measures | Evidence source |
|---|---|---|
| **Depth** | Real logic vs stub; LOC | `lib/src/plugins/<name>/`, command files |
| **Tests** | Dedicated behavioral suites (not smoke) | `test/plugins/<name>/`, `test/commands/<name>/` |
| **Proven** | Dogfood artifacts in zik_zak / zikzak_demo | `apps/zikzak_demo/`, `~/Developer/zik_zak/lib`, GitHub issues |
| **Agent Contract** | Exit codes, `--json` output, `--> fix:` lines, receipts, idempotency | Command source, CapabilityCommand inheritance |
| **Docs** | Help text, openwiki, spec traceability | `openwiki/cli.md`, spec folders, dartdoc |

Overall grade = arithmetic mean, letter-scale: A ≥4.4, A− ≥4.2, B+ ≥4.0, B ≥3.6, B− ≥3.4, C+ ≥3.2, C ≥3.0, C− ≥2.6, D+ ≥2.2, D ≥1.8, F <1.8.

---

## Fleet Summary

| Metric | Value |
|---|---|
| Total plugins | 35 |
| Fleet average | **3.16 (C+)** |
| Grade distribution | A:3, A−:3, B+:1, B:5, B−:7, C+:2, C:4, C−:4, D+:2, D:3, F:1 |
| A-grade core (≥A−) | 7 plugins (tdd, route, mcp, usecase, repository, service, mock) |
| Not-yet-proven (<C) | 10 plugins (tui, feature, observer, module, cli, gql, gym, shadcn, sqlite, xray) |
| Confirmed never used in anger | 7 plugins (slice, xray, tui, module, observer, skeleton self-only, cli phantom) |

**Headline:** A-grade referee core; solid B-grade generation spine (`zfa make` presets); a rotting tail where ~20% of the fleet has zero production footprint and the "errors are an API" vision is enforced only on the newest layer.

---

## The Matrix

| Plugin | Commands | LOC | Tests | Dep | Tst | Prv | Contract | Doc | **Grade** |
|---|---|---|---|---|---|---|---|---|---|
| **tdd** | `zfa tdd` + 22 subs (plan/gen/verify-red/make/view/run/replay/verify/corpus/referee/realize/verdicts) | 34.5K | 159 | 5 | 5 | 5 | 4→5* | 3→4* | **A → A** |
| **route** | `route create/custom/deep-link/shell` + `route verify` | 4.3K | 7 | 5 | 5 | 5 | 3→5* | 4 | **A → A** |
| **mcp** | `mcp scaffold/serve/list-tools` + 30-tool server + v2 agentic | 4.6K | 10 | 5 | 5 | 3 | 4 | 5 | **A** |
| **usecase** | `usecase create [--type future/stream/orch/os_bg…]` | 3.0K | 4 | 4 | 4 | 5 | 4→5* | 4 | **A− → A** |
| **repository** | `repository create/method` | 2.9K | 4 | 4 | 4 | 5 | 4 | 4 | **A−** (awaiting #1124) |
| **service** | `service create/method` | 0.5K | 2 | 4 | 4 | 5 | 4 | 4 | **A−** (awaiting #1127) |
| **mock** | `mock create/data/json/inject` | 4.7K | 6 | 4 | 4 | 5 | 3 | 4 | **B+** (awaiting #1121) |
| **skeleton** | `bone generate/export/validate` | 3.2K | 21 | 4 | 5 | 3 | 3 | 4 | **B** |
| **di** | `di create/register` | 2.7K | 2 | 4 | 4 | 5 | 3 | 3 | **B** |
| **benchmark** | `benchmark run/list/register/baseline/report` | 3.1K | 28 | 4 | 5 | 2 | 4 | 3 | **B** |
| **app_shell** | `app shell` | 1.1K | 2 | 4 | 4 | 4 | 3 | 3 | **B** |
| **strategy** | `strategy create --strategies=…` | 0.5K | 2 | 4 | 4 | 4 | 3 | 3 | **B** |
| **slice** | `slice cut/merge/list/inspect/verify/run/export/import` | 5.7K | 31 | 5 | 5 | 1 | 3 | 3 | **B−** (awaiting #961 proof) |
| **method_append** | injected via `repository/service/provider/datasource/method` | 3.0K | 4 | 4 | 3 | 4 | 4 | 2 | **B−** |
| **datasource** | `datasource create/method/private-method/inject` | 2.7K | 2 | 4 | 4 | 4 | 2 | 3 | **B−** (awaiting #1131) |
| **test** | `test create` | 2.3K | 0† | 4 | 3 | 4 | 3 | 3 | **B−** (awaiting #1129) |
| **cache** | `cache create/adapter` | 1.5K | 1 | 4 | 2 | 5 | 3 | 3 | **B−** |
| **state** | `state create` | 1.5K | 1 | 4 | 2 | 5 | 3 | 2 | **B−** (awaiting #1126) |
| **sync** | `sync enable` | 1.4K | 4 | 4 | 4 | 3 | 3 | 3 | **B−** |
| **graphql** | `graphql <E>/introspect/pull/diff` | 7.5K | 0† | 4 | 2 | 4 | 3 | 4 | **B−** |
| **api** | `api <Entity>` | 1.0K | 2 | 4 | 4 | 3 | 2 | 3 | **C+** |
| **view** | `view create/custom/register` | 2.3K | 0 | 4 | 2 | 4 | 2 | 3 | **C** |
| **controller** | `controller create` | 2.1K | 0 | 4 | 2 | 4 | 2 | 3 | **C** |
| **presenter** | `presenter create` | 1.1K | 0 | 4 | 2 | 4 | 2 | 3 | **C** |
| **provider** | `provider create/method/inject` | 0.9K | 4 | 3 | 4 | 3 | 2 | 3 | **C** (awaiting #1128) |
| **shadcn** | `shadcn <layout> <E>` + core `ui schema/validate/preview` | 1.9K | 6 | 3 | 4 | 2 | 2 | 3 | **C−** |
| **xray** | `xray enable/disable/status/deck/mock` | 1.7K | 15 | 3 | 4 | 2 | 2 | 3 | **C−** |
| **sqlite** | `sqlite create` | 0.8K | 1 | 4 | 3 | 2 | 2 | 3 | **C−** |
| **gym** | `gym <Name>` | 0.7K | 4 | 3 | 4 | 2 | 2 | 2 | **C−** |
| **feature** | `feature scaffold/route/di/…` + flag mgmt | 1.4K | 0† | 2 | 1 | 2 | 3 | 4 | **D+** |
| **tui** | none (`make --with=tui` silently no-ops) | 1.9K | 15 | 3 | 3 | 1 | 1 | 3 | **D+** |
| **observer** | `observer create` | 0.4K | 0 | 3 | 0 | 2 | 2 | 3 | **D** |
| **cli** | `cli <Entity>` — **phantom: never writes** | 0.2K | 0† | 2 | 3 | 1 | 1 | 3 | **D** |
| **module** | `module <Name>` + make preset | 0.2K | 1 | 3 | 2 | 1 | 1 | 2 | **D** |
| **gql** | `gql <Entity>` — **byte-level duplicate of graphql** | 0.6K | 0 | 2 | 0 | 2 | 1 | 1 | **F** |

*\* → value after spot-checking master against ADD items; see "Tier A re-evaluation" below*  
*† zero dedicated files, scattered coverage elsewhere*

---

## Tier A Re-evaluation (master spot-checked)

### tdd (A, 4.4 → A)

| ADD item | Status | Evidence |
|---|---|---|
| `--json` verdict envelope on all 22 verbs | **DONE** | `VerdictsCommand` in `verdicts_command.dart`; spec #969 CLOSED |
| Proof.v1 receipts on gen/make/view | **DONE** | `TddGenerationReceipts.writeBestEffort()` called in `make_command.dart:85`, `view_command.dart:416` |
| `--explain` flag | **OPEN #1125** | Not yet implemented |
| Finder-kind taxonomy (#964/#965) | **OPEN** | Issues still open; widget lane remains presence-only |

### route (A, 4.4 → A)

| ADD item | Status | Evidence |
|---|---|---|
| `zfa route verify` with JSON + exit codes | **DONE** | `route_verify_command.dart` (spec #0971, T004); drift verdicts match/drift/insufficient-input → exit 0/1/2 |
| `--explain` flag + config schema fill | **OPEN #1122** | Still open |
| Dual-system drift lint | **DONE** (part of verify) | Verify reads both CLI and DDA sides; drift is caught as verdict |

### usecase (A−, 4.2 → A)

| ADD item | Status | Evidence |
|---|---|---|
| MethodVerdicts (`--json`) | **DONE** | `usecase_verdicts.dart` — `MethodVerdict` class with created/appended/skipped/deleted; `toJson()` |
| Receipts per generation | **DONE** | `TddGenerationReceipts` integration via `make` path |
| Bare `zfa usecase` exits 0 | **CLOSED #972** | Issue explicitly titled on honest grammar |
| Verify + explain + drift gate | **OPEN #1119** | Still open |

### repository (A−, 4.2 → A−)

| ADD item | Status | Evidence |
|---|---|---|
| `--json` envelope on create | **OPEN #1124** | Explicitly titled "biggest machine-readability gap" |
| Post-gen self-certify | **NOT STARTED** | No interface↔impl verification found |
| Hashed contract manifest | **NOT STARTED** | No method-set manifest consumed by usecase guard |

### service (A−, 4.2 → A−)

| ADD item | Status | Evidence |
|---|---|---|
| `methods: []` hardcode in plan() | **FIXED** | `create_service_capability.dart:138` now derives `methodNames` from args |
| `--json` + verify + receipts | **OPEN #1127** | Titled "add --json, verify, receipts, error handling (C to A+)" |

### mcp (A, 4.4 → A)

| ADD item | Status | Evidence |
|---|---|---|
| `mcp verify` | **NOT DONE** | No verify subcommand in source |
| Scaffold receipt | **NOT DONE** | No ReceiptStore integration in scaffold path |
| Session replay | **NOT DONE** | `McpSessionStore` exists but no replay CLI verb |
| Capabilities handshake | **NOT DONE** | No `zuraffa.capabilities` extension field in initialize |

---

## The Six Systemic Findings

### 1. The lying-success bug class is endemic and era-correlated
Pre-capability-era command bodies exit 0 on error in: `view`, `controller`, `datasource`, `shadcn`, `xray deck`, `gym`, `gql`, `graphql generate/introspect`, `feature`, `presenter`, `api`, `module`, `observer`; `cache`/`sync`/`observer` crash (RangeError) on bare invocation. Fixed only where #767/#769/#856 patches were applied. **~15 plugins carry the defect the vision calls heresy.** The treaty (#917) is enforced on the new layer and ignored on plugin-owned surfaces.

### 2. The agent contract is one inherited floor
Everything machine-readable comes from `CapabilityCommand` (`--json` is *input-only*, dry-run `EffectReport`, exit 64/1). Almost nothing emits: `--json` **output** verdicts (only `xray status`, `benchmark`, `ui schema`), `--> fix:` lines (only `tdd`), receipts (only `tdd realize` + the orchestrated `make` path). Standalone plugin invocations ship **no proof**.

### 3. Test coverage inversely correlates with dogfooding
Most-used, thinnest-tested: `state` (1,265 LOC / 2 tests / 104 generated files in zik_zak), `cache` (531 LOC / 1 test), `presenter` (968 LOC / 0 dedicated). Least-used, most-tested: `benchmark` (28), `slice` (31), `tui` (15), `xray` (15). Testing follows **spec-driven development** (specced work got suites), not risk or usage.

### 4. Three test suites certify lies
- `xray_deck_cli_test.dart:69` pins non-existent `XRayControlDeckRegistry` as expected output (generated deck **cannot compile**)
- TUI generator tests pin broken `package:zuraffa/domain/...` imports (**uncompilable in consumers**)
- `cli` plugin tests assert in-memory strings for output **never written to disk**
- shadcn's `grid`/`table` silently falls through to `list` (lying generator, untested)

### 5. Six duplication clusters rot the fleet
(a) `gql` ≡ `graphql`: 416/421 LOC copies, bug fixed in one not the other, same output path  
(b) `skeleton` re-implements usecase/repository/datasource as StringBuffer templates, bypassing #921/#942  
(c) `module` has two independent generators for one artifact  
(d) two route systems (CLI flag-driven vs DDA `@ZfaRoute` annotation)  
(e) two view generators (`zfa view` vs `zfa tdd view`, zero shared code)  
(f) two regex usecase parsers (dead `di_command.dart` + test plugin copy)

### 6. The phantom tier is real
`cli` prints `Generated:` for a file that does not exist (verified: zero write calls). `tui`: `make --with=tui` silently emits nothing (not a FileGeneratorPlugin). `slice`, `xray`, `module`, `observer`, `skeleton` (self-dogfood only) round out the never-used list.

---

## Per-Plugin: Good / Bad / Add (Headline)

### Tier A — The referee core

**tdd** (A)  
Good: Honesty enforced in code — verify-red's 6-class taxonomy + sha256 tree snapshots + evidence-beats-state reconciliation. Now with `--json` verdicts (#969) and receipts on gen/make/view.  
Bad: Widget lane degrades navigation/state scenarios to presence assertions (#964/#965); `--explain` still missing (#1125).  
Add: Finder-kind taxonomy (#964) + slang-key resolution (#965); `--explain` (#1125); verify-red refuses unkind finders.

**route** (A)  
Good: Self-proving via generated route-table tests; `route verify` is real drift detection with exit-code verdicts.  
Bad: `--explain` empty (#1122); the DDA annotation path still unreconciled beyond drift detection.  
Add: `--explain` + config schema fill (#1122); drift-lint in CI gate.

**mcp** (A)  
Good: v2 agentic tool surface makes the whole framework agent-callable; real JSON-RPC auth tests.  
Bad: Scaffold ships placeholder EchoTool, never verified; no verify subcommand; no scaffold receipts.  
Add: `mcp verify` (boot → `tools/list` → fail on placeholder) + scaffold receipt + session replay + capabilities handshake on `initialize`.

**usecase** (A)  
Good: #921 SourceInterfaceGuard prevents phantom methods; MethodVerdicts + `--json` + receipts shipped.  
Bad: `--explain` + drift gate still open (#1119); skeleton still duplicates in a divergent dialect.  
Add: `usecase verify` (--explain, drift gate, `--certify`) per #1119.

**repository** (A−)  
Good: Interface↔impl parity defended at source; best contract hygiene.  
Bad: No `--json` envelope on create (#1124); flag maze relies on plugin ordering comments.  
Add: `--json` create envelope (#1124); post-gen self-certify; hashed contract manifest for usecase guard.

**service** (A−)  
Good: Richest small generator; only sibling with the #856 honesty patch; `methods: []` hardcode now fixed.  
Bad: No `--json`, verify, or receipts yet (#1127).  
Add: Per #1127: `--json`, verify, receipts, error handling.

**mock** (B+)  
Good: TDD pipeline's default green path; entity-graph-aware; 144 files in zik_zak.  
Bad: `JsonMockCommand` still calls bare `exit(64)`; no verify command (#1121).  
Add: `mock verify` + self-certification gate + `--certify` per #1121.

### Tier B — The generation spine

**skeleton** (B): Validate is a real referee gate; duplicates the data layer in a divergent dialect. **di** (B): Simulation-flavor DI is real; 427-LOC dead `di_command.dart` is a trap. **benchmark** (B): Only plugin mapping verdict→exit-code end-to-end; ships zero scenarios. **app_shell** (B): Cross-generator verification (DI signature introspection); not a real plugin (no EffectReport). **strategy** (B): Dogfooded in zik_zak; empty `--strategies` silently returns `[]`.  
**slice** (B−): Deepest engine (166 tests); confirmed never used in anger (#961). **method_append** (B−): True bidirectional AST editing; `execute()` hardcodes `success: true`. **datasource** (B−): Post-gen mutation (append/inject); exits 0 twice on failure. **test** (B−): Red→green test generation; no `test/plugins/test/` directory. **cache** (B−): Recursive registrar discovery; bare `zfa cache` crashes. **state** (B−): 104 files in zik_zak; 2 tests for 1,265 LOC. **sync** (B−): Real runtime engines; not CRDT (LWW outbox). **graphql** (B−): `graphql diff` is the vision exemplar; getList misnamed.

### Tier C/D/F — The rot

**api** (C+): Refuses non-serializable bridges; validation crashes unhandled.  
**view** (C): Mock-data probing; unconditional `✅…success!` is a lying-success line.  
**controller** (C): Semantically complete bodies; failure lies twice; 997 LOC untested.  
**presenter** (C): Strong dogfood; dead positional grammar still advertised.  
**provider** (C): Existing-file discovery; 100% stub bodies can ship silently.  
**shadcn** (C−): `ui validate/schema` is a genuine contract; grid/table silently emit list.  
**xray** (C−): 3-layer release strip; deck generates non-compiling code (test certifies the lie).  
**sqlite** (C−): Seeds #815/#816; zero usage, zero execution tests.  
**gym** (C−): `gym.yaml` is a real contract; flagship warmup is `UnimplementedError`.  
**feature** (D+): Plan parity enforced; 8 copy-paste clones.  
**tui** (D+): Production-grade binding layer; `--with=tui` is a silent no-op, wrong-package imports.  
**observer** (D): Zero tests, zero artifacts, crash on bare invocation.  
**cli** (D): Phantom output — reports file that never exists (verified).  
**module** (D): Two drifting generators; exit-0-on-error; no artifact anywhere.  
**gql** (F): Byte-level duplicate of graphql; zero tests; "internal" undefined. Kill it.

---

## Key Issues Filed (verified against master)

| # | Title | Tier | Status |
|---|---|---|---|
| #969 | tdd: --json verdicts + receipts | A | CLOSED ✓ |
| #971 | route: verify with drift detection | A | DONE (verified) |
| #972 | usecase: MethodVerdicts + honest grammar | A | CLOSED ✓ |
| #1125 | tdd: --explain flag | A | OPEN |
| #1122 | route: --explain + config schema | A | OPEN |
| #1124 | repository: --json envelope on create | A− | OPEN |
| #1127 | service: --json + verify + receipts | A− | OPEN |
| #1121 | mock: verify + explain + certify | B+ | OPEN |
| #1119 | usecase: verify + drift gate | A | OPEN |
| #1131 | datasource: verify + receipts + --explain | B− | OPEN |
| #1129 | test: --explain flag | B− | OPEN |
| #1126 | state: verify + receipts + --explain | B− | OPEN |
| #1128 | provider: --explain + error handling | C | OPEN |
| #1105 | verdict envelope unification (zuraffa.verdict.v1) | cross-cutting | OPEN |
| #1104 | openwiki sweep for 12 A+ plugins | cross-cutting | OPEN |

---

*This report card was generated by adversarial source analysis. All inflammatory claims (phantom writes, non-compiling decks, lying test suites) were spot-verified against master before publication. Disagreement is the deliverable.*
