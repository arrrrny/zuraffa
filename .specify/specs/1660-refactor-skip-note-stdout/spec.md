# 1660-refactor-skip-note-stdout

- **Spec ID**: 1660-refactor-skip-note-stdout
- **Created**: 2026-09-17
- **Source**: GitHub issue #1660 (ux: a skipped refactor pass is indistinguishable from an executed one on stdout — print the skip note)
- **Type**: UX fix (P2 — an operator (or an agent measuring the #1624 economics) cannot tell from the transcript whether the heaviest pass ran)
- **Branch**: fix/1660-refactor-skip-note-stdout
- **Related**: #1624 (the build-relevance gate that records the synthetic skip — semantics untouched), #1637 (the config-digest clearance the note carries), #1634 (the static first-build skip — same gate family, same stdout treatment), #1540 (the `[1540]`-tagged stdout evidence precedent), #1653 (the per-pass `duration:` line — the additive stdout-line precedent)

## Problem

`zfa tdd refactor <id>` prints for every pass:

```
   pass: build
     command: /path/.dart_tool/zfa_cli_bin/zfa_exe build
     exit: 0
     changed: (none)
```

That shape is identical whether the pass **executed** (real spawn, exit 0, no
changes) or was **skipped** by the #1624 build-relevance gate (synthetic
action — nothing spawned at all). The skip note (the gate's full
`refactorBuildSkippedNote` text) is captured in the action's `output` but
never surfaced: `refactor_command.dart` prints only `pass/command/exit/changed`
plus the `[1540]`-tagged lines, and the cycle log's refactor entry carries
only the preflight/re-proof block.

Why it matters: the gate's honest-skip evidence — including the #1637
config-digest clearance and the "a DELETED source is invisible to this gate"
caveat — never reaches the human. Reproduced live in this session: the
`pass: build` block in a fixture refactor run was a synthetic skip (no
`duration:` line, zero writes under `.dart_tool/build/`), while stdout made
it indistinguishable from an executed no-op pass.

## Goal

A skipped refactor pass is distinguishable from an executed one on stdout:
the pass line names the skip, the gate's full note is printed, and one note
line is mirrored into the refactor cycle-log entry. Executed-pass output is
byte-identical to before. The #1624 gate's decision semantics and the set of
circumstances under which skips happen are UNTOUCHED.

## Success criteria (measurable)

1. **SC-1 (SKIPPED marker)**: When `action.skipped` is true, the pass loop
   prints the pass header as `   pass: <name> — SKIPPED (build-relevance gate)`
   — a clear, greppable marker that no executed pass ever prints.
2. **SC-2 (note surfaced)**: The gate's full `refactorBuildSkippedNote` text
   is printed on stdout as a `     note: ` line for the skipped action — the
   #1637 config-digest clearance and the deleted-source caveat reach the
   human verbatim.
3. **SC-3 (executed unchanged)**: A pass that executed (spawn or refusal)
   prints exactly the pre-fix shape — plain `   pass: <name>` header, the
   same command/exit/duration/changed lines, no SKIPPED marker, no note
   line. Proved by a guard test that pins the executed shape (real fake-zfa
   spawn asserted via the invocation log).
4. **SC-4 (cycle-log mirror)**: The refactor cycle-log entry's output block
   carries one `note:` line with the gate's note when the registry recorded
   a skip; entries with no skip render byte-identically to before.

## Hard constraints

- Fix ONLY the stdout printing (+ the optional cycle-log mirror). The
  #1624 gate semantics, its fail-toward-RUN direction, and when skips
  happen are not modified — `build_relevance.dart` and
  `refactor_passes.dart` are untouched.
- One PR per spec.
