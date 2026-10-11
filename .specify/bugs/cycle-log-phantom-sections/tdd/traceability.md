# Traceability: cycle-log-phantom-sections

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:869a19d9b99547be97e8b6bc411ab7c927d25a8e090a2794b78c694e532c48c2
statements: 5
automated: 5
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 20 | 1. **Given** a cycle-log whose red entry's fenced `- output:` block contains | A1 | automated |
| AC-2 | 25 | 2. **Given** captured output containing backtick fence markers (including | A2 | automated |
| AC-3 | 29 | 3. **Given** a cycle-log with no `## ` inside captured output, **When** it is | A3 | automated |
| AC-4 | 33 | 4. **Given** all 9 reader call sites (cycle_evidence ×2, verify_red, make ×2, | A4 | automated |
| AC-5 | 37 | 5. **Given** a red entry whose captured output contains `## Cycle: BOGUS | A5 | automated |

