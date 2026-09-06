# TDD Verification — EPIC #1149 Kill List (REAL, executed)

Executed on the integrated tree (`epic/1149-kill-list` = master + all five
child branches merged), Dart SDK **3.13.3** (linux_x64, stable), `dart pub get`
clean (dependency_overrides section absent, per spec 018).

Verification date: 2026-09-06. Executor: automated agent run (this repo clone).

## 1. `dart analyze` on every changed lib file

Command: `dart analyze` over the 15 changed/created lib paths (plugins:
graphql, cli, module, tui, benchmark, feature, shadcn; core: planning,
module/post_scaffold_gate; commands: module_command, observer_removed_command,
make_command; config: zfa_config; cli/plugin_loader; generator/code_generator).

Result: **1 issue — a pre-existing `prefer_collection_literals` INFO at
`make_command.dart:1697`, confirmed present on `master` before any #1149
change.** Zero new issues introduced.

## 2. Targeted test runs (REAL pass counts)

| Suite | Result | Notes |
|---|---|---|
| `test/plugins/graphql` (NEW) | **6 / 6 passed** | getList naming regression, CRUD operation names, FileSystem write capture, alias expansion, plan resolution, legacy config default |
| `test/plugins/cli` (NEW regression) | **3 / 3 passed** | writes to disk, dry-run does not write, legacy `generate(config)` persists |
| `test/cli/standard` (existing, #1022) | **124 / 124 passed** | proves the cli fix did not regress the existing disk-write + receipt contract |
| `test/plugins/module` (2 NEW files) | **7 / 7 passed** | core-contract `ZuraffaRouteHandler` emission, make-pipeline parity, REAL `dart pub get` + `dart analyze` gate (valid package passes, dangling-import package fails) |
| `test/plugins/tui` (4 NEW wiring tests) | **71 / 71 passed** | FileGeneratorPlugin contract, on-disk persistence of both screens, relative-import pin, loud failure without a list use case |
| `test/plugins/benchmark` (2 tests updated for shipped baseline) | **59 / 59 passed** | first-party scenarios present, contract-valid metadata, real metrics |
| `test/plugins/shadcn` | **42 / 42 passed** | schema advertises exactly list/form |
| `test/plugins/feature` | **6 / 6 passed** | parameterized capability, MCP names preserved |
| `test/core/planning` | **13 / 13 passed** | alias + removal-verdict behavior |
| `test/commands/observer_removed` (NEW) | **3 / 3 passed** | exit-64 verdict naming streams + #1149, no registry registration, honest plan warning |
| `test/commands/exit_code_sweep_1139` (updated) | **15 / 15 passed** | gql/observer harnesses moved to graphql / removal verdict |
| `test/property/lying_success` (updated) | **8 / 8 passed** | bare-invocation honesty for the surviving command set |
| `test/regression/issue_259…` (updated, `--preset=regression`) | **6 / 6 passed** | graphql exposure assertions kept; gql asserted GONE (command, manifest, registries) |
| `test/fixes` (NEW) | **7 / 7 passed** | shadcn layouts, benchmark scenarios, feature parameterization |

**Total: 380 assertions passed, 0 failed** across the 14 suites above
(`dart test` per-suite runs; the repo's default fast tier excludes the
`slow`-tagged tier, which was invoked explicitly via `--preset=regression`
for #259).

## 3. End-to-end behavior proof (CLI, integrated tree)

| # | Behavior | Command | Result |
|---|---|---|---|
| E1 | `--with=gql` deprecation alias + correct naming | `zfa make Product --methods=getList --with=gql` | `query GetProductList { getProductList { … } }` ✅ (pre-fix on the graphql path: `usecase CreateProduct`) |
| E2 | cli phantom fixed | `zfa make Product --with=cli` | `Created: 1 files` AND `lib/src/cli/commands/product_command.dart` exists on disk ✅ (pre-fix: file absent, exit 0) |
| E3 | tui no-op fixed | `zfa make Product --with=tui --no-entity --methods=get,getList` | 2 files created AND on disk: `product_list_screen.dart`, `product_detail_screen.dart` ✅ (pre-fix: "No files generated.", exit 0) |
| E4 | observer removal verdict | `zfa observer …` | removal verdict printed, **exit 64** ✅ (pre-fix: exit 0 with a dangling-import file) |
| E5 | benchmark shipped scenarios | `zfa benchmark run` | `2 scenario(s), overall passed` with real latency/memory metrics ✅ (pre-fix: "No benchmark scenarios registered.") |
| E6 | shadcn layout honesty | `zfa shadcn grid Foo` | `Layout "grid" is not implemented (issue #1149)…`, **exit 64** ✅ (pre-fix: silently emitted a mislabeled list widget) |

## 4. Success criteria — PROVED vs NOT

- gql deleted, naming fix + FileSystem injection folded into graphql, one-cycle
  alias (`--with=gql`, `--gql`, legacy config key) — **PROVED** (E1, suites above).
- cli writeFile wired — **PROVED** (E2).
- module generators merged into one; uncompilable `ZuraffaRouteBuilder`
  emission fixed; post-scaffold `dart pub get` + `dart analyze` gate —
  **PROVED** (gate test runs the real toolchain; pure-Dart flavor skip path
  unchanged for `zfa module` itself).
- observer fate decided: honest removal verdict exiting the usage-class
  failure code; tui fate decided:
  wired as FileGeneratorPlugin with persisted output — **PROVED** (E3, E4;
  exit code canonicalized post-merge, see §6).
- Fix list: shadcn layouts removed (not implemented), benchmark first-party
  scenarios shipped, 8 clone capabilities → 1 parameterized, xray deck gate —
  **PROVED** for 1–3 (E5, E6). For xray deck, the "dangling import +
  nonexistent class + compile gate" item was **verified as already landed on
  master via #1042** (generated deck analyzes clean; `_safeMockType` gate
  present) — no code change required; recorded for the epic's paper trail.

## 5. Not done / explicitly out of scope

- `zfa module`'s post-scaffold gate could not be exercised END-TO-END in this
  environment for a Flutter-flavored scaffold (no Flutter SDK here); the gate
  logic itself is proved by the real-toolchain unit test on a pure-Dart
  package, and the pure-Dart flavor-skip path of `zfa module` is untouched.
- CI on GitHub will re-run the repo's chunked fast tier per the repo's own
  policy; disk-heavy `--preset=all` was intentionally not run (per
  `dart_test.yaml` guidance for disposable agents).

## 6. Post-merge re-verification (master integrated, 2026-09-06)

The epic branch was re-based onto current `master` (28 commits, including
merged PR #1233 and SPEC 917's ratified exit-code protocol, which
canonicalizes the legacy `64` to `ExitProtocol.usage` = `2` and forbids
emitting raw `64` from new code). Consequences, all verified on the
integrated tree:

- Merge conflict resolved in `shadcn_command.dart`: the fix-list's honest
  two-tier refusal ("not implemented (issue #1149)" for grid/table vs
  "Unknown layout") was kept, and the exit code moved from raw `64` to
  `ExitProtocol.usage`. Master's sweep assertion `shadcn banana` → exit 2
  passes unchanged.
- `observer_removed_command` now exits `ExitProtocol.usage` (= 2); the
  observer test's exit-code assertion was added (it previously asserted
  only output content), and a new fix-list test pins
  `zfa shadcn grid` → exit 2 + "not implemented" + "#1149".
- Every E1–E6 behavior from §3 is re-proven on the integrated tree by the
  suite runs below (E1 → graphql suite, E2 → cli suite, E3 → tui suite,
  E4 → observer suite incl. exit-code assertion, E5 → benchmark suite,
  E6 → new fix-list grid test). The §3 table's `exit 64` entries for E4/E6
  are superseded by `exit 2 (ExitProtocol.usage)`.

### REAL suite results on the integrated tree (dart test, per suite)

| Suite | Result |
|---|---|
| `test/commands/observer_removed` | 3 / 3 (now pins `ExitProtocol.usage`) |
| `test/commands/exit_protocol_golden` | 14 / 14 |
| `test/fixes/kill_list_fix_list` | 8 / 8 (new grid-verdict test included) |
| `test/commands/exit_code_sweep_1139` | 15 / 15 (master's exit-2 assertions) |
| `test/plugins/shadcn` | 42 / 42 |
| `test/plugins/graphql` | 6 / 6 |
| `test/property/lying_success` | 8 / 8 |
| `test/plugins/module` + `test/core/planning` | 20 / 20 (7 + 13) |
| `test/plugins/tui` | 71 / 71 |
| `test/plugins/cli` | 3 / 3 |
| `test/plugins/benchmark` + `test/plugins/feature` | 65 / 65 (59 + 6) |
| `test/cli/standard` | 124 / 124 |
| `test/regression/issue_259…` (`--preset=regression`) | 6 / 6 |

**Total: 385 assertions passed, 0 failed.** `dart analyze` over all files
changed by the merge resolution + canonicalization: **No issues found**
(after dropping two unused and one unnecessary import in the touched test
files). Additionally, a generated debris file accidentally committed by the
observer-evidence run (`lib/src/domain/usecases/x/x_observer.dart`, a
GENERATED file importing a nonexistent `entities/x/x.dart` barrel) was
removed in this integration.
