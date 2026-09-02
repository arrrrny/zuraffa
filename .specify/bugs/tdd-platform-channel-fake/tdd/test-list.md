# Test list — tdd-platform-channel-fake (#831)

Canonical 4-column rows; ids match the groups in
`test/plugins/tdd/commands/fake_command_test.dart`,
`test/plugins/tdd/commands/gen_command_platform_test.dart`,
`test/plugins/tdd/services/channel_scenario_test.dart`,
`test/plugins/tdd/services/test_list_reader_test.dart` (platform group) and
`test/plugins/tdd/red_classifier_test.dart` (issue #831 group).

## Platform harness (fake command — issue requirements 1 + 3):

| B-001 | `zfa tdd fake <channel> --behavior <id>` writes the committed-intent scenario at specs/<feature>/tdd/scenarios/<snake-id>.json and the certified fake at test/tdd/<feature>/fakes/<snake-id>_fake.dart | FR-831-1 | DONE |
| B-002 | the certified fake is a test-side handler registered via TestDefaultBinaryMessengerBinding that replays the scenario and records every observed call (method, arguments, order); the emitted Dart parses cleanly | FR-831-1 | DONE |
| B-003 | a re-run keeps the committed scenario (intent is never silently overwritten) and regenerates the fake; --force rewrites the starter | FR-831-1 | DONE |
| B-004 | an unknown platform token is refused before any write; a missing --feature is a usage error (intent needs an explicit feature home) | FR-831-1 | DONE |
| B-005 | the machine summary line names channel, feature, behavior, slug, scenario path, fake path, and the platforms matrix | FR-831-1 | DONE |

## Platform harness (scenario schema — issue requirement 3):

| B-006 | the scenario schema parses channel, platforms (closed token set), responses (value XOR error with code+message) and the REQUIRED loud default; every violation is a named schema error | FR-831-3 | DONE |
| B-007 | the scenario round-trips through toJson/fromJson; permission states are plain replayable values (no special-cased machinery) | FR-831-3 | DONE |

## Platform harness (gen platform kind — issue requirement 2):

| B-008 | a `## Platform harness` section header and a `platform` kind cell resolve to BehaviorKind.platform (4-column and gen-legacy dialects); an orphan row under a reset section still rejects | FR-831-2 | DONE |
| B-009 | gen on a platform row WITHOUT a committed scenario refuses honestly before any write, naming `zfa tdd fake <channel> --behavior <id>` as the remedy | FR-831-2 | DONE |
| B-010 | gen on a platform row with scenario + fake emits the platform-harness pair — a test that installs the fake and asserts on the observed calls (arguments recorded, ordering preserved, unscripted methods fail loudly) plus a channel-calling subject stub — not the plain-function pair; emitted Dart parses cleanly | FR-831-2 | DONE |
| B-011 | gen on a platform row keeps the registry + JSON-verdict contract (kind=platform in the verdict) | FR-831-2 | DONE |

## Platform harness (verify-red classification — issue requirement 4):

| B-012 | MissingPluginException, a channel-scoped TimeoutException, and PlatformException(channel-error) WITHOUT an assertion signature classify channel-timeout with a remediation hint naming `zfa tdd fake` | FR-831-4 | DONE |
| B-013 | an assertion signature beats channel text (assertion stays the only certifying red) | FR-831-4 | DONE |
| B-014 | a bare TimeoutException with no channel context stays runner-error (widget taxonomy, #830); a PROCESS-level SIGKILL timeout stays runner-error (bug #742 precedence); a green run is unaffected | FR-831-4 | DONE |

## Platform harness (cross-platform matrix — issue requirement 5):

| B-015 | --platforms records the hosted matrix in the committed scenario (closed token set) and the machine summary; the emitted harness is platform-agnostic Dart so the same scenario runs on every declared platform where feasible | FR-831-5 | DONE |
