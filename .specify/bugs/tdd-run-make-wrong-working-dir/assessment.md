# Assessment: tdd-run-make-wrong-working-dir (issue #1267)

- **Assessed on the fix branch**: fix/1267-tdd-run-make-wrong-working-dir
- **Baseline assessed**: d3679e0f (master HEAD at fix time)
- **Provenance**: recovered — the record was not committed in the repo; the
  remediation below comes from the bug assignment brief, the root-cause and
  repro from GitHub issue #1267, and every behavioral claim in the "current
  behavior" probes was REPRODUCED empirically in this sandbox before the fix
  (see `tdd/red_evidence_1267.txt`).

## Root cause (confirmed by code walk + live probes)

The `-C/--directory` flag works as a scoped chdir in `CliRunner._withDirectory`
(lib/src/cli/cli_runner.dart): `Directory.current` is pointed at the target
and restored after dispatch. Every generation command resolves its output
paths (`lib/src/domain/entities/...` and friends) against `Directory.current`.
Without `-C`, `Directory.current` is the raw shell CWD, so:

| Command | Root resolution before the fix | Probed behavior from a rootless CWD |
|---|---|---|
| `zfa entity create` | raw `Directory.current` (entity_command.dart:247,531,563 + relative writers) | refuses early with the dep-check text "No pubspec.yaml found in current directory" (exit 1) — even when a valid project root sits one directory up |
| `zfa make` | `ProjectRoot.find()` — upward walk that silently FALLS BACK to the CWD when no pubspec.yaml exists anywhere upward (make_command.dart:188-193) | **silently SUCCEEDS (exit 0)** and writes `lib/src/domain/usecases/...` into the rootless CWD — the exact scatter the issue reports |
| `zfa build` | `ProjectRoot.safeCurrentPath()` — guarded raw CWD, no walk (build_command.dart:154,176,249,287,329,587) | lying success: `--dry-run` previews 0 entities and exits 0 ("Dry-run completed") with zero project validation |

`zfa tdd run` / `zfa tdd make` resolve their own root via
`ProjectRoot.find(anchorDir: 'specs')` (the #890 fix) and pass it as the
`workingDirectory` of every spawned pipeline step. The spawned
`zfa entity create` / `zfa make` / `zfa build` subprocesses then re-resolve
the root from that CWD — so a make step whose working directory is not the
target project writes generation output into the WRONG project (the filed
failure: "make step fails when entity create targets wrong working
directory").

## Remediation (from the bug brief — auto-detect variant, preferred for ergonomics)

1. When `-C` is NOT provided, search upward from the CWD for the nearest
   `pubspec.yaml`; the first found directory is the project root.
2. If no `pubspec.yaml` exists in any ancestor, emit the clear error:
   `No Flutter project found. Run from inside a project directory or use -C <path>.`
   (no silent fallback to the CWD).
3. Existing `-C <project>` behavior must not change.

## Hard constraints

- Fix ONLY through the generation pipeline; never hand-edit source the
  pipeline owns.
- One PR per bug; closes #1267.
- `tdd/verification.md` generated FRESH from the actual run in the fix
  session — never a stale copy.

## Chosen implementation (minimal, at the single choke point)

The repo's established convention (issues #441, #506, #890, #1096) is to
NEITHER mutate `Directory.current` from inside commands NOR thread a new
projectRoot parameter through every writer. The `-C` flag already provides a
battle-tested scoped-chdir with a cross-isolate lock. The fix therefore lands
in `CliRunner` (the same layer `-C` lives in):

- `ProjectRoot.findOrNull({startPath})` (lib/src/core/project/project_root.dart):
  upward pubspec.yaml walk that returns `null` instead of falling back —
  additive; legacy `find()` semantics untouched.
- `CliRunner._rootBoundGenerationCommands = {entity, make, build}` +
  `_resolveGenerationRoot()`: with no `-C` and a CWD that itself carries no
  pubspec.yaml, walk upward; found → apply the SAME scoped chdir `-C` uses
  (`directory ?? autoRoot` into `_withDirectory`); not found → refuse with the
  canonical message + `--> fix:` line + exit 2 (ExitProtocol.usage).
  Help-only invocations (`--help`/-h/help, issue #764) bypass the gate.
  Explicit `-C` bypasses the gate entirely (constraint 3).

Command-level (not subcommand-level) gating: every `entity` subcommand
shares the same CWD-relative write/read machinery, and read-only subcommands
outside a project were already hard-refused by the entity dep-check, so the
gate preserves (and clarifies) that contract at the runner level.

## Rejected alternatives

- Strict error at `ProjectRoot.find()` itself: breaks the TDD anchor
  semantics (#890) whose roots may legitimately carry no pubspec.yaml.
- Per-command projectRoot threading through writers: wide blast radius across
  pipeline-owned code; violates the minimal-fix constraint.
- Always requiring `-C`: worse ergonomics; the brief prefers auto-detect.

## Known supersession (test-visible)

`zfa entity list` outside a project used to fail with the entity dep-check
text ("No pubspec.yaml found in current directory"). The runner gate now
refuses first with the canonical #1267 message (same non-zero contract).
test/commands/entity_help_test.dart's guard test accepts both messages.
