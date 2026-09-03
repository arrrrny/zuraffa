# Contract: CLI routing surface (`zfa tdd plan`, honored by `tdd make`)

## New flag

```
--strict-routing    Refuse undeclared routing intent instead of falling back to
                    keyword classifiers. Exit 1 with a `--> fix:` line naming the
                    spec line and the declaration to add.
```

Default: off (migration window). Project config may set it persistently; the flag
wins over config.

## Provenance output (stdout, per behavior, plan time)

```
   route: A3 -> widget lane (presentation contract: Login page) [declared: type marker, spec line 42]
   route: U2 -> func surface (function contract: Formatter.format -> String) [declared: contract row, spec line 87]
   route: U5 -> unit lane (entity: Product) [declared: key entity row, spec line 23]
   route: U7 -> unit lane + persistence [declared: [persistent] tag, spec line 31]
   route: U9 -> widget lane [fallback: UI-intent keyword 'shows' matched — add `**Type**: widget` to the scenario (spec line 55)]
```

Grammar: `   route: <id> -> <decision> ([detail])? [declared: <source>, spec line <n>]` or
`   route: <id> -> <decision> [fallback: <classifier> matched — <fix hint> (spec line <n>)]`.

The bracketed token is machine-parseable: it starts with exactly `declared:` or
`fallback:`. Provenance is additionally written into the test list's traceability
block (durable artifact).

## Exit codes (unchanged semantics, new strict case)

| Exit | Meaning |
|---|---|
| 0 | plan written; every behavior routed (declared or fallback) |
| 1 | honest refusal: strict-mode undeclared behavior, declaration conflict, dangling reference, malformed declaration — message names the spec line(s), `--> fix:` names the declaration to add |
| 2 | grammar/parse error (existing contract) |

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
