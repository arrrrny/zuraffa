# Test list — 1193-realize-mocked-to-real-swap

| id | kind | behavior | state |
|----|------|----------|-------|
| DRY-1 | unit | `--dry-run` previews the swap (rebinding sites named) and leaves the tree untouched: no realize-state.json, no journal.json, no realize-receipt.json, no differential-receipt.json, no cycle-log.md, byte-identical binding file | done |
| DRY-2 | unit | `--dry-run` and `--diff-only` are mutually exclusive — the misfire is refused with result=runner-error | done |
| DRY-3 | unit | a dry-run that would be refused (missing adapter, no `--scaffold`) exits 1, prints `would refuse:` and names the adapter class | done |
| SCAF-1 | unit | `--scaffold` scaffolds the missing real adapter behind the SAME interface (every method stubbed `UnimplementedError`, stamped hand-delta seam, no `// GENERATED`), records the provenance-ledger hand-delta receipt, and the swap lands | done |
| SCAF-2 | unit | a missing adapter WITHOUT `--scaffold` is still refused (the refusal names `--scaffold`); no file written, no era transition | done |
| JRN-1 | unit | a realized swap appends the unified journal entry (`cycle: meta`, `gate_state: green`, `result: realized`, behaviors listed, schema-valid) and advances `tdd/run-state.json` `mocked → done`; era crosses to REAL | done |
| JRN-2 | unit | only `mocked` behaviors advance — a `pending` behavior stays pending | done |
| RCPT-1 | unit | the swap writes `tdd/realize-receipt.json` (schema `realize-receipt.v1`): ladder MOCKED→REAL, gate outcomes, per-file digests with buckets, generated/mock/hand ratios with `G%/M%/H%` cell | done |
| CERT-1 | unit | a certified mock (#1110 receipt, fresh + all-satisfied) is located and counted `mocks {total: 1, certified: 1}` in the receipt | done |
| CERT-2 | unit | a RED certification (unsatisfied method) blocks the swap with `result=blocked` — no era transition, no journal advance | done |
