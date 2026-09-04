# Contract: Slice Merge Landing

## Invocation

```text
zfa slice merge --into <host> [--project <slice-root>] [--force]
```

## Precondition (gate)

A CURRENT passing verify verdict for the sandbox (073 contract).
Missing or failing verdict → refuse, exit non-zero, name the check and
`--> fix: zfa slice verify` (or the failing offenders).

## Landing

1. Feature artifacts, journal, and registry land in the host at their
   canonical paths (existing merger; conflict detector reports
   overwrites — `--force` required to overwrite non-generated files).
2. Post-landing: the HOST suite runs (baseline-aware per #741/#953:
   pre-existing reds tolerated, NEW reds reported in the outcome).
3. Machine summary (final stdout line):

```text
slice-merge: feature=<f> host=<path> artifacts=<n> host-suite=<green|red|skipped> new-failures=<count> outcome=<landed|refused>
```

4. Host suite red with new failures → the landing reports the offending
   behaviors and names `--> fix:` (full conformance-gate + rollback is
   feature 074's scope).

## Idempotence

Re-merging a landed slice with unchanged artifacts is a no-op landing
(same bytes) and re-runs the host suite outcome.

## Refusals

- verdict absent/failing → exit 2 (`--> fix: zfa slice verify`).
- conflict without `--force` → exit 3 naming the conflicting files.
- host path not a zfa project → exit 4 naming the missing marker.
