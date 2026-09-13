# TDD test list — Bug #1575 fence-blind line-scanners outside the cycle-log

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1575-a1 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | acceptance | an in-fence `## Inner loop:` banner does not re-kind the enclosing section (A2 stays acceptance) | FR-1575, TestListReader._parseRows | GREEN |
| A-1575-a2 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | acceptance | an in-fence `## Key entities` banner does not switch the walk into the declarative section (U2 parses, no silent vanish) | FR-1575, TestListReader._parseRows | GREEN |
| A-1575-a3 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | acceptance | readEntities: an in-fence header does not close the Key entities section (post-fence entity row survives) | FR-1575, TestListReader.readEntities | GREEN |
| A-1575-a4 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | acceptance | readDependencies: an in-fence header does not close the External dependencies section (post-fence dependency row survives) | FR-1575, TestListReader.readDependencies | GREEN |
| A-1575-a5 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | acceptance | readLayerContracts: an in-fence header does not close the Layer contracts section (post-fence contract bullet survives, layer kept) | FR-1575, TestListReader.readLayerContracts | GREEN |
| U-1575-b1 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | unit | a well-formed list without fences parses unchanged (hard constraint: no regression for canonical inputs) | FR-1575, TestListReader._parseRows | GREEN |
| U-1575-b2 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | unit | the committed 004 corpus shape (in-fence `## Baseline (...)` banner) parses identically before and after the fix | FR-1575, TestListReader._parseRows | GREEN |
| U-1575-b3 | test/plugins/tdd/services/test_list_reader_1575_fence_test.dart | unit | a malformed row after a fence reports its honest absolute line number (bug #984 line-naming contract stays byte-identical) | FR-1575, TestListReader._parseDataRow | GREEN |
| U-1575-c1 | test/core/proof_chain_checker_1575_fence_test.dart | unit | an in-fence header does not drop post-fence behavior ids from the coverage audit (B2 gap reported) | FR-1575, _behaviorIdsOf | GREEN |
| U-1575-c2 | test/core/proof_chain_checker_1575_fence_test.dart | unit | a fenced `## Behaviors` example fabricates no phantom audit ids (PHANTOM never reported, declarations stay declarations) | FR-1575, _behaviorIdsOf | GREEN |
| U-1575-c3 | test/core/proof_chain_checker_1575_fence_test.dart | unit | a well-formed behaviors table audits exactly as before (hard constraint: no regression for the coverage check) | FR-1575, _behaviorIdsOf | GREEN |
