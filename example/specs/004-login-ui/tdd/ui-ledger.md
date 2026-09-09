# UI Surface Ledger

| surface | kind | proven by | state |
| --- | --- | --- | --- |
| deal_list | route |  | NOT-DONE |
| ShadInput | affordance |  | NOT-DONE |
| t.auth.signIn | key |  | NOT-DONE |
| t.auth.error | key |  | NOT-DONE |
| t.auth.working | key |  | NOT-DONE |
| t.auth.email | key |  | NOT-DONE |
| t.auth.password | key |  | NOT-DONE |
| t.auth.sessionStarted | key |  | NOT-DONE |

# Platform Coverage Ledger

| slot | surface | kind | proven by | state |
| ---- | ------- | ---- | --------- | ----- |
| mobile | deal_list | route |  | NOT-DONE |
| mobile | ShadInput | affordance |  | NOT-DONE |
| mobile | t.auth.signIn | key |  | NOT-DONE |
| mobile | t.auth.error | key |  | NOT-DONE |
| mobile | t.auth.working | key |  | NOT-DONE |
| mobile | t.auth.email | key |  | NOT-DONE |
| mobile | t.auth.password | key |  | NOT-DONE |
| mobile | t.auth.sessionStarted | key |  | NOT-DONE |
| macos | deal_list | route |  | NOT-DONE |
| macos | ShadInput | affordance |  | NOT-DONE |
| macos | t.auth.signIn | key |  | NOT-DONE |
| macos | t.auth.error | key |  | NOT-DONE |
| macos | t.auth.working | key |  | NOT-DONE |
| macos | t.auth.email | key |  | NOT-DONE |
| macos | t.auth.password | key |  | NOT-DONE |
| macos | t.auth.sessionStarted | key |  | NOT-DONE |

## Platform coverage heatmap

Per-platform kind coverage (issue #1142): every declared platform layout slot is traced independently — an aggregate "100% traced" with a mobile-only prover set is still missing macOS coverage.

| kind | mobile | macos |
| --- | --- | --- |
| route | 0/1 | 0/1 |
| affordance | 0/1 | 0/1 |
| key | 0/6 | 0/6 |
