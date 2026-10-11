# TDD Verification — Spec 1312 receipt preflight abs-vs-rel path mismatch

## Test-first evidence (RED recorded before implementation)

The four new behaviors (tdd/test-list.md B1–B4) were added to
`test/plugins/tdd/services/receipt_preflight_test.dart` and run BEFORE
any lib/ change. Red runs were executed after `rm -rf .dart_tool/test/`
kernel-cache cleanup, per the cloud-agent protocol. Single-file runs
only — never the full suite.

Command:

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/plugins/tdd/services/receipt_preflight_test.dart
```

RED observation: `00:00 +10 -4: Some tests failed.` — exactly the four
new behaviors failed; all 10 pre-existing tests passed:

| Suite / behavior | RED observation |
|---|---|
| B1 absolute audited path inside root, covered | `[missing_receipt] /tmp/zfa_996_preflight_*/lib/tdd/b_001_subject.dart — no receipt covers this audit subject` — the covered subject reported missing |
| B2 audited path outside root | `[missing_receipt] /opt/elsewhere/out_of_root_subject.dart` — out-of-root path reported instead of skipped |
| B3 mixed audited list | 3 findings (both covered/absolute + out-of-root) where exactly 1 (the genuinely uncovered subject) is correct |
| B4 CLI: absolute subject_path in artifacts.json | `zfa tdd verify: receipt preflight — FAIL … missing_receipt … /tmp/zfa_996_verify_*/lib/tdd/b_001_subject.dart` — the issue #1312 repro: gate fails on a covered subject |

The red output pins the root cause verbatim: the finding path printed
the ABSOLUTE registry path while the receipt covered the relative form.

## Green evidence (after implementation)

Fix: `ReceiptPreflight._normalize` relativizes absolute audited paths
against `projectRoot` (returns `null` for paths escaping the root;
idempotent on already-relative paths; backslash canonicalization
preserved); `check` skips `null` subjects. Only
`lib/src/plugins/tdd/services/receipt_preflight.dart` changed in lib/
(scope fence respected — engine, registry writer, proof checker,
audit semantics untouched).

Same command after the fix (kernel cache cleaned before the run):

```
00:00 +14: All tests passed!
```

| Suite | Result |
|---|---|
| test/plugins/tdd/services/receipt_preflight_test.dart (10 pre-existing + 4 new) | 14 passed, 0 failed |

Post-format re-run (after `dart format .`): 14 passed, 0 failed.

## Acceptance-criteria coverage

| SC | Proof |
|---|---|
| SC-1 sanctioned run → preflight passes on the same subjects | B4 CLI test: `artifacts.json` with ABSOLUTE `subject_path` (the exact shape `gen_command.dart` writes: `'$cwd/lib/tdd/...'`) + covering receipt → output contains `receipt preflight: ok`, does not contain `missing_receipt`, audit proceeds (`mutation config`) |
| SC-2 absolute-in-root covered → pass | B1 unit test: `report.ok` true, `gateActive` true, zero findings |
| SC-3 out-of-root → skipped, not missing | B2 unit test: report ok, zero findings for `/opt/elsewhere/...` |
| SC-4 mixed list → only real uncovered subjects produce findings | B3 unit test: exactly 1 `missing_receipt` finding naming the uncovered subject's project-relative path; covered relative + covered absolute + out-of-root produce nothing |
| SC-5 backward compat (relative registries) | Existing CLI test 'green receipt gate lets the audit proceed' and all relative-path unit tests pass UNMODIFIED (10/10) |
| SC-6 gate still fails closed | Existing tests 'missing receipt for an audited subject → GATE FAILURE' (finding path `lib/tdd/b_001_subject.dart`, relative shape preserved) and 'missing receipt … exit 1, no mutation audit' pass UNMODIFIED |
| SC-7 analyze/format | `dart analyze lib/src/plugins/tdd/services/receipt_preflight.dart test/plugins/tdd/services/receipt_preflight_test.dart` → `No issues found!`; `dart format` on both changed files → `0 changed` (idempotent). `dart format .` additionally flagged 3 PRE-EXISTING unformatted fixtures (`corpus/regression/*/u2-flow/u1_test.dart`, `specs/1256-.../tdd/red_repro.dart`) — left untouched: byte-compared regression-corpus/red-repro records, outside #1312 scope |

## Test-strength / mutation evidence

The full mutation engine (`zfa tdd verify`'s MutationAuditor /
mutation-test.xml) was NOT run: the cloud-agent protocol forbids the
full suite (≈6.5 GB kernel cache overflow) and the auditor mutates
scope subjects beyond this fix's single file. Honest compensating
evidence at assertion strength:

- The RED run is a real behavioral red against the REAL gate output
  (missing_receipt fired on covered subjects; captured above).
- The green suite pins BOTH directions: covered-but-absolute passes
  (B1/B3/B4) AND uncovered fails closed with the unchanged finding
  shape (pre-existing failure tests). A mutant that skips the
  membership test entirely fails the fail-closed tests; a mutant that
  drops the relativization fails B1–B4; a mutant that skips ALL
  out-of-root handling fails B2/B3.
- Surviving-mutant check by inspection: `p.relative` escaping
  (`../`-prefix → null) is exercised by B2/B3; the
  already-relative idempotence path is exercised by every pre-existing
  relative-path test.
