# Contract: `zfa tdd corpus` (spec 051-corpus-harness)

The machine contract for the corpus harness, in the house style of the
loop commands (049 `run`, 044 `verify`): every invocation prints a
`<verb>: key=value …` summary line as its final line, exits with a
documented code, and consumes upstream artifacts only through their
documented formats.

## Registration

`zfa tdd corpus` registers under the `tdd` plugin:

```text
zfa tdd corpus run    [--project <dir>] [--zfa-bin <path>]
zfa tdd corpus status [--project <dir>]
zfa tdd corpus audit  [--project <dir>]
```

`--project` (alias `--project-root`) resolves the driven app's root,
defaulting to the current working directory. `--zfa-bin` overrides the
entrypoint used to spawn `zfa tdd run` / `zfa tdd verify` per feature
(scripted-fake hook, identical semantics to `zfa tdd run`'s flag).

## `corpus run`

Drives every `ready` manifest feature, in manifest order, through
`zfa tdd run <feature>` then `zfa tdd verify --feature <feature>`; skips
`done`/`waived` features (resume), skips and reports `not-ready` features
(never spawned), persists progress after every feature, appends gap-ledger
entries on every stop, and stops the whole run at the first feature-level
roadblock (STOP-ON-ROADBLOCK).

Per-feature evaluation:

| verify gate | progress effect | run effect |
|-------------|-----------------|------------|
| `pass` | `done` (gate recorded) | continue |
| `fail_survived` / `fail_timeout` / `preflight_red` | `stopped` | stop non-zero + ledger |
| `not_assessed` | `stopped` | stop non-zero + ledger (reason surfaced) |
| any gate == recorded waiver for that feature | `waived` (waiver recorded) | continue |
| `run` exit != 0 (`stopped`, `runner-error`, `corrupt-state`, `concurrent-run`) | `stopped` | stop non-zero + ledger (run's `stopped_at` recorded) |

Summary line (always the final line):

```text
corpus: features=<n> done=<n> waived=<n> stopped=<n> not_ready=<n> pending=<n> dropped=<n> gaps=<n> result=<r>[ stopped_at=<feature>]
```

- `result` ∈ `complete | stopped | runner-error | corrupt-state |
  concurrent-run | no-manifest`
- `stopped_at` present whenever `result=stopped` (the feature name)

Exit codes:

| Code | Meaning |
|------|---------|
| 0 | every manifest feature `done` or `waived` |
| 1 | `stopped` — a roadblock stopped the corpus; ledger names it |
| 2 | `runner-error` — spawn/tooling failure (misfire-stop, FR-011); also the `no-manifest` result (the run cannot start; the message names the manifest path) |
| 3 | `corrupt-state` — progress/ledger/manifest JSON invalid (recovery path printed) |
| 4 | `concurrent-run` — a live foreign pid holds the in-flight marker |

Progress lines during the run (human): `[corpus] <feature> run -> <run
result>`, `[corpus] <feature> verify -> <gate>`, `[corpus] <feature> ->
done|waived|stopped…`.

## `corpus status`

Read-only: manifest + progress + ledger + waivers, no driving, no writes.

```text
corpus: features=<n> done=<n> waived=<n> stopped=<n> not_ready=<n> pending=<n> dropped=<n> gaps=<n> result=<complete|incomplete|corrupt-state|no-manifest>[ resume_at=<feature>]
```

Exit 0 exactly when every manifest feature is `done` or `waived`;
1 (incomplete), 3 (corrupt-state), 2 (`no-manifest` names the missing
manifest — a usage-level runner error). The report lists per-feature
state, the resume point (first non-done/waived feature), gate outcomes,
ledger totals (found / filed / merged / blocking), and every unresolved
blocking gap by feature.

## `corpus audit`

Walks `<project>/lib/` recursively; attributes each regular file via
priority: artifact registries (`specs/*/tdd/artifacts.json` →
`subject_path`), cycle-log refactor `changed:` lists, setup/import
provenance (`.zfa/provenance/*.json`), carve-out manifest
(`.zfa/manifests/corpus-carveout.json`). Writes
`.zfa/corpus/audit-report.json` (per-file attribution source, carve-out
list, counts) and prints:

```text
audit: files=<n> attributed=<n> carveout=<n> unattributed=<n> result=<pass|fail>
```

Exit 0 = 100% attribution; exit 1 = fail (every unattributed file named
in the report and on stderr); exit 2 = runner-error (e.g. no `lib/`
directory at all).

## Upstream formats consumed (read-only)

- `.zfa/manifests/corpus-manifest.json` — #627's contract
  (`features[{name, ready, reason}]`, order preserved)
- `zfa tdd run` machine line: `run: feature=<f> result=<r> pending=<n>
  red=<n> green=<n> done=<n>[ stopped_at=<behavior>:<step>]`, exit
  0/1/2/3/4
- `zfa tdd verify` machine line: `mutation: gate=<label> killed=<n>
  survived=<n> timed_out=<n> mutation_was_run=<b>`, exit non-zero unless
  `pass`
- `specs/*/tdd/artifacts.json` — `{feature, records: [{subject_path, …}]}`
- `specs/*/tdd/cycle-log.md` — refactor entries' `actions:` blocks
  (`changed: <files>`)
- `.zfa/provenance/*.json` — `{command, at?, files: [...]}` (single
  record or array)
- `.zfa/corpus/waivers.json` — `[{feature, gate, reason, actor, at}]`
- `.zfa/manifests/corpus-carveout.json` — `{carveouts: [{path, reason}]}`

Path normalization: recorded paths may be absolute or project-relative;
the audit compares POSIX-style project-relative paths.
