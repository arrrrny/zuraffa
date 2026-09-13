00:00 +0: loading test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart
00:00 +0: B1: a 3-column row with plain pairs parses all fields (#1486)
00:00 +0 -1: B1: a 3-column row with plain pairs parses all fields (#1486) [E]
  Expected: ['id', 'title', 'isCompleted', 'createdAt']
    Actual: MappedListIterable<EntityField, String>:[]
     Which: at location [0] is MappedListIterable<EntityField, String>:[] which shorter than expected
  plain prose pairs must not be silently dropped
  
  package:matcher                                                                   expect
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart 89:5  main.<fn>
  
00:00 +0 -1: B2: the 2-column table accepts plain pairs (#1486 + #1381)
00:00 +0 -2: B2: the 2-column table accepts plain pairs (#1486 + #1381) [E]
  Expected: ['id', 'username', 'token']
    Actual: MappedListIterable<EntityField, String>:[]
     Which: at location [0] is MappedListIterable<EntityField, String>:[] which shorter than expected
  the 2-col grammar must not lose plain pairs
  
  package:matcher                                                                    expect
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart 107:5  main.<fn>
  
00:00 +0 -2: B3: a mixed cell parses backticked and plain pairs in order
00:00 +0 -3: B3: a mixed cell parses backticked and plain pairs in order [E]
  Expected: ['id', 'token', 'refreshedAt']
    Actual: MappedListIterable<EntityField, String>:['id']
     Which: at location [1] is MappedListIterable<EntityField, String>:['id'] which shorter than expected
  mixed grammar keeps source order
  
  package:matcher                                                                    expect
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart 118:5  main.<fn>
  
00:00 +0 -3: B4: guard — the backticked grammar is unchanged
00:00 +1 -3: B5: generic types with commas survive the plain-pair split
00:00 +1 -4: B5: generic types with commas survive the plain-pair split [E]
  Expected: ['meta', 'rows', 'owner']
    Actual: MappedListIterable<EntityField, String>:[]
     Which: at location [0] is MappedListIterable<EntityField, String>:[] which shorter than expected
  commas nested in <...> are not pair separators
  
  package:matcher                                                                    expect
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart 142:5  main.<fn>
  
00:00 +1 -4: B6: nullable types parse as plain pairs
00:00 +1 -5: B6: nullable types parse as plain pairs [E]
  Expected: ['nickname', 'bio']
    Actual: MappedListIterable<EntityField, String>:[]
     Which: at location [0] is MappedListIterable<EntityField, String>:[] which shorter than expected
  
  package:matcher                                                                    expect
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart 157:5  main.<fn>
  
00:00 +1 -5: B8: guard — bullet prose keeps the strict backticked-only grammar
00:00 +2 -5: Some tests failed.

Failing tests:
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart: B1: a 3-column row with plain pairs parses all fields (#1486)
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart: B2: the 2-column table accepts plain pairs (#1486 + #1381)
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart: B3: a mixed cell parses backticked and plain pairs in order
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart: B5: generic types with commas survive the plain-pair split
  test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart: B6: nullable types parse as plain pairs

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.

Run context: Dart SDK 3.13.3 (stable) linux_x64, branch fix/1486-entity-fields-backtick-parsing, working tree pre-fix (spec_parser.dart untouched).
Result: 2 passed (guards B4/B8), 5 failed (B1/B2/B3/B5/B6) — plain `name: Type` pairs yield SpecEntity.fields == [] exactly as issue #1486 reports.
