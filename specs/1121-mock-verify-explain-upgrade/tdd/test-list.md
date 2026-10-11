# TDD test list — SPEC 1121 (mock verify + explain)

Behavior → failing-test-first mapping. Every row's test was run RED before its
implementation, then GREEN after (evidence in `tdd/verification.md`).

| # | Behavior | Test (RED first) |
|---|---|---|
| 1 | `zfa mock verify <Entity>` exits 0 on a conforming on-disk mock, prints a conformance line naming the interface class and registry id, and writes nothing (read-only) | `test/plugins/mock/mock_verify_test.dart` › A1 |
| 2 | `zfa mock verify <Entity>` exits 1 with `--> fix:` lines naming the drifted member(s) + interface when the mock misses an interface member; analyze errors exit 1 too | `mock_verify_test.dart` › A2 |
| 3 | `zfa mock verify <Entity>` refuses honestly when no mock exists: exit 1, `missing_file` finding, fix names `zfa mock create <Entity> --certify` | `mock_verify_test.dart` › A3 |
| 4 | `zfa mock verify <Entity> --json` emits the canonical `zuraffa.verdict.v1` envelope (pass: verdict/exit_class 0/subject mock/empty findings; fail: verdict/exit_class 1/findings + drifts populated) | `mock_verify_test.dart` › A4 |
| 5 | `zfa mock explain <Entity>` reports per-method coverage + certification status (`certified`/`uncertified`/`missing`), skipped and invented lists, and the registry id | `mock_verify_test.dart` › A5 |
| 6 | `zfa mock explain <Entity>` reports the `MockData.forMethod` selector (#1034): declared + discriminator type, and the `forMethod(params.<field>)` bindings found on disk | `mock_verify_test.dart` › A5 |
| 7 | `zfa mock explain <Entity> --json` carries the full structured report under the envelope's `details.explain` | `mock_verify_test.dart` › A6 |
| 8 | Usage errors exit 2 with `--> fix:` lines (no entity: verify; no entity: explain) | `mock_verify_test.dart` › A2/A5 usage assertions |
