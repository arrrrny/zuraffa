# TDD test list — SPEC 1132 / EPIC 1: Machine Contract — The Honesty Sweep

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1132-a1 | test/commands/exit_code_sweep_1132_test.dart | e2e (in-process) | bare `zfa cli` prints the usage line and exits SPEC 917 usage `2` (not 0) | FR-1 / SC-1 | RED → GREEN |
| U-1132-a2 | test/commands/exit_code_sweep_1132_test.dart | e2e (in-process) | bare `zfa benchmark` exits `2`; explicit `--help`/`-h` still exits `0` (help is success) | FR-1 / SC-1 | RED → GREEN |
| U-1132-a3 | test/commands/exit_code_sweep_1132_test.dart | e2e (in-process) | bare `zfa bone` exits `2`; `--help` exits `0`; unknown bone subcommand exits `2` with the usage block | FR-1 / SC-1 | RED → GREEN |
| U-1132-a4 | test/commands/exit_code_sweep_1132_test.dart | e2e (in-process) | bare `zfa migrate` exits `2`; unknown migration target exits `2` (was 0) | FR-1 / SC-1 | RED → GREEN |
| U-1132-a5 | test/commands/exit_code_sweep_1132_test.dart | e2e (in-process) | bare `zfa plugin` exits `2`; `--help` exits `0` | FR-1 / SC-1 | RED → GREEN |
| U-1132-a6 | test/commands/exit_code_sweep_1132_test.dart | e2e (in-process) | `zfa config set` with missing key/value exits usage `2` (was failure `1`); `zfa config <unknown>` exits `2` (was `1`) — runCapturing RETURNS (no hard `exit()`: embedded dispatch survives) | FR-1 / SC-1 | RED(subprocess) → GREEN |
| U-1132-s1 | test/regression/issue_1132_bare_exit_code_fleet_test.dart | regression (subprocess) | subprocess pins: bare `cli`/`benchmark`/`bone`/`config`/`migrate`/`plugin` each exit `2` with usage on stdout; `--help` exits `0` | FR-1 / SC-1 | RED → GREEN |
| E-1132-c1 | test/commands/verdict_envelope_1132_test.dart | e2e (in-process) | `zfa provider verify <Entity> --json` emits a `zuraffa.verdict.v1` envelope (parses via `VerdictEnvelope.fromJson`); verdict `fail` + `exit_class 1` + `subject.kind == 'provider'`; findings carry the fix lines; the old `{"schema":1,...}` shape breaks loudly | FR-2 / SC-2 | RED → GREEN |
| E-1132-c2 | test/commands/verdict_envelope_1132_test.dart | e2e (in-process) | `zfa benchmark list --json` emits the canonical envelope (verdict `pass`, `exit_class 0`, scenario list rides in `details.scenarios`) | FR-2 / SC-2 | RED → GREEN |
| E-1132-c3 | test/commands/verdict_envelope_1132_test.dart | e2e (in-process) | generic capability machine-mode missing-args refusal (`zfa repository method --json={}`) emits the canonical envelope (verdict `error`, `exit_class 2`, one finding per missing arg with the `--> fix:` line) | FR-2 / SC-2 | RED → GREEN |
| E-1132-c4 | test/core/verdict_envelope_emitter_scan_test.dart | scan (existing guard) | `capability_command.dart`, `provider_verify_command.dart`, `benchmark_command.dart` leave `kExcluded` — every `--json` verdict emitter references the core envelope | FR-2 / SC-2 | RED → GREEN |
| R-1132-d1 | test/commands/standalone_receipts_1132_test.dart | e2e (in-process fixture) | `zfa app shell` leaves a `proof.v1` receipt in `.zfa/receipts/` covering the written shell artifacts (main.dart / shell widget / app_router.dart); digest matches disk bytes | FR-3 / SC-3 | RED → GREEN |
| R-1132-d2 | test/commands/standalone_receipts_1132_test.dart | e2e (in-process fixture) | `zfa skin kit` leaves a `proof.v1` receipt covering `skin/skin_contract_auditor.dart` (digest matches disk) | FR-3 / SC-3 | RED → GREEN |
| R-1132-d3 | test/commands/standalone_receipts_1132_test.dart | e2e (in-process fixture) | a skipped `zfa skin kit` (kit exists, no `--force`) writes NO new receipt — nothing changed, nothing proven | FR-3 / SC-3 | RED → GREEN |
| D-1132-e1 | test/commands/openwiki_cli_docs_1132_test.dart | unit (pure) | the command-list parser handles wrapped multi-line command descriptions (fixture `--help` text with continuation lines) and returns every command | FR-4 / SC-4 | RED → GREEN |
| D-1132-e2 | test/commands/openwiki_cli_docs_1132_test.dart | unit (pure) | the committed `docs/openwiki/cli.md` documents every command it claims (header count matches `## zfa <cmd>` entry count; ≥ 50 entries — the fleet floor) | FR-4 / SC-4 | RED → GREEN |
| D-1132-s2 | test/regression/openwiki_cli_docs_fleet_test.dart | regression (subprocess) | drift guard: every command of the LIVE `zfa --help` has a `## \`zfa <cmd>\`` entry in `docs/openwiki/cli.md` (docs cannot drift behind the dispatcher) | FR-4 / SC-4 | RED → GREEN |

## Red evidence (pre-fix, this session)

- Master audit probes (subprocess, `scripts/zfa`): bare `cli`/`benchmark`/
  `bone`/`config`/`migrate`/`plugin` all exit 0 with usage on stdout;
  `zfa migrate <unknown>` exits 0; `zfa bone <unknown>` exits 0.
- Machine-mode probes: `{"schema":1,"ok":false,...}` (capability pre-flight),
  `{"schema":1,...}` (provider verify --json), `{"scenarios":[...]}` (no
  schema; benchmark list --json).
- Receipts audit: `zfa app shell` / `zfa skin kit` exit 0, write artifacts,
  leave `.zfa/receipts/` empty.
- Openwiki regeneration attempt: the tool writes a 12-command doc (parser
  stops at the first wrapped description) — regeneration would clobber the
  59-command committed file.

Verbatim run transcripts are recorded in `tdd/verification.md`.
