# Contract: CLI routing surface (`zfa tdd plan`, honored by `tdd make`)

## New flag

```
--strict-routing    Refuse undeclared routing intent instead of falling back to
                    keyword classifiers. Exit 1 with a `--> fix:` line naming the
                    spec line and the declaration to add.
```

Default: off (migration window). Flag-only today — the CLI flag is the only
switch; project-config persistence is reserved (no config surface ships yet).

## Provenance output (stdout, per behavior, plan time)

```
   route: A3 -> widget lane (view generation) [declared: type marker, spec line 42]
   route: U2 -> func surface [declared: contract row: Formatter, spec line 87]
   route: U5 -> unit lane (entity pipeline: Product) [declared: contract row: Product, spec line 23]
   route: U9 -> widget lane [fallback: legacy description classifier matched — add `**Type**: widget` to the scenario]
   route: U8 -> refused [danglingReference: behavior "U8" traces to "Ghost", which names no declared contract row …]
```

Grammar: `   route: <id> -> <lane> ([detail])? [declared: <source>[, spec line <n>]]`,
`   route: <id> -> <lane> [fallback: legacy description classifier matched — <fix hint>]`,
or `   route: <id> -> refused [<code>: <first message line>]`.

The bracketed token is machine-parseable: it starts with exactly `declared:`,
`fallback:`, or `refused:`. Persistence is NOT part of a route line — it renders
as the test-list ` [persistence]` cell mark (durable artifact). Fallback lines
carry no spec line; refused lines quote the failure's first message line.
Provenance is additionally written into the test list's traceability
block (durable artifact).

## Exit codes (unchanged semantics, new strict case)

| Exit | Meaning |
|---|---|
| 0 | plan written; every behavior routed (declared or fallback). A NON-strict plan that hits a declaration conflict, dangling reference, or malformed declaration also exits 0 — the refusal is recorded as a `route: <id> -> refused [<code>: …]` provenance line (stdout + artifact), not an exit code. (Malformed declarations refuse pre-artifact with exit 2 under `zfa tdd plan` since the round-2 gate reorder.) |
| 1 | honest refusal — strict plan (`--strict-routing`), `tdd make`, or `tdd func`: undeclared routing intent, declaration conflict, dangling reference, or malformed declaration. Message names the spec line(s); `--> fix:` names the declaration to add |
| 2 | grammar/parse error (existing contract); also `zfa tdd plan`'s pre-artifact declaration refusal |

## Refusal message shape (strict + invalid declarations)

```
zfa tdd plan: behavior U9 has no routing declaration (strict mode).
   scenario at <spec>:55 carries no `**Type**` marker and traces to no contract row.
   --> fix: add `**Type**: unit` to the scenario, or trace it to a Layer Contracts row.
```

```
zfa tdd plan: behavior A1 has conflicting declarations.
   `**Type**: widget` at <spec>:12 vs trace to entity row `Product` at <spec>:30 (unit lane).
   --> fix: keep exactly one routing declaration for A1.
```

## Compatibility

- Without `--strict-routing`: existing valid specs route byte-identically today
  (fallback window), plus new `route:` lines on stdout and in the artifact.
- `tdd make` consumes the same decisions through the planner; its planning logs the
  provenance source instead of silently keyword-matching.
