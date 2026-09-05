# Test List: 984-tdd-run-empty-separator-parse

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-984-1 | parser skips a bare ` \|` separator line between table sections instead of rejecting it as a malformed row | BUG-984 | GREEN |
| U-984-2 | parser still stops honestly on genuinely malformed rows (FR-011 misfire-stop preserved) | BUG-984 | GREEN |

### `lib/src/plugins/tdd/services/test_list_reader.dart`

 |

| U-984-REG1 | reader regression guard: canonical + deprecated dialects, escaped pipes, section parsing and the repo's own committed lists keep resolving (BUG-984 hard constraint: existing committed test-lists must not abort) | BUG-984.SC-1 | GREEN |
| U-984-REG2 | persistence marker parsing and whitespace normalization keep working (reader suite: spec 833) | BUG-984.SC-1 | GREEN |
| U-984-REG3 | native-loop / ffi kind parsing keeps working (reader suite: spec 835) | BUG-984.SC-1 | GREEN |
| U-984-REG4 | declarative sections (Key entities / External dependencies / Layer contracts) keep parsing without rejection (reader suite: bug 937) | BUG-984.SC-1 | GREEN |
| U-984-REG5 | dependency + layer-contract readers keep working (reader suite: bug 919) | BUG-984.SC-1 | GREEN |
