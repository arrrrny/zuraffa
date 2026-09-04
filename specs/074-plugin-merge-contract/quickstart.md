# Quickstart: Plug-In Merge Contract (074)

Land a verified slice with zero hand-edits — and a verdict to prove it.

```bash
# 0. Precondition: a VERIFIED slice (073)
zfa slice verify --project <slice-root>          # exit 0

# 1. Merge: landing + conformance gates + verdict
zfa slice merge --into ~/Developer/zik_zak --project <slice-root> --json
# routes -> pass (barrel regenerated, every path resolves)
# di     -> pass (graph constructs in mock + real flavors)
# views  -> pass (pages compose the host shell)
# feature-suite -> pass (green in-host; baseline-aware)
# exit 0, host committed with the verdict

# If a gate fails:
#   the host rolls back byte-identical, the exit is non-zero,
#   and the verdict names the failed check + offenders + fix.
```

## Sabotage examples (what the gate catches)

- route declaration removed after verify → routes fail → rollback.
- binding module missing a token → di fails naming the token.
- view artifact bypassing the shell convention → views fail naming the file.
- new red introduced → feature-suite fails naming the behavior.

## Idempotence

Re-merge a merged feature: identical bytes, gates re-run, no-op landing.
