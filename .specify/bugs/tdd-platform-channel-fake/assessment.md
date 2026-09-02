# Bug Assessment: platform-channel test harness — certified fakes for camera, barcode, permissions, notifications, location

- **Slug**: tdd-platform-channel-fake
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/831
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Specs 013 (barcode), 070 (permissions), 072 (location), 059/060 (local+push notifications), 077 (photo upload/camera) sit on platform channels. Pure-function subjects cannot express them; today nothing in the TDD loop provides a certified fake. The TDD loop cannot test camera, barcode, permissions, notifications, or location behaviors. https://github.com/arrrrny/zuraffa/issues/831

## Symptom

Platform-channel behaviors (barcode scanning, permission requests, location services, notifications, photo upload) have no test coverage. Pure-function subjects cannot express platform interactions. No certified fakes exist in the TDD loop. All 15 affected specs lack TDD surface.

## Reproduction

1. Run `zfa tdd gen <id>` for a platform-backed feature (e.g. spec 013 barcode)
2. Generated subject is a pure-function — cannot express platform channel
3. No fake exists to register platform channel handlers
4. Behavior has no test — pure function that always passes or throws UnimplementedError

## Suspected Code Paths

- `zfa tdd gen` — no fake generation for platform channels
- No scenario script infrastructure (`specs/<feature>/tdd/scenarios/*.json`)
- No `zfa tdd fake <channel>` command
- verify-red — no classification for channel-timeouts vs assertion failures

## Root Cause Hypothesis

High confidence: the TDD pipeline was designed for pure-function generation and never integrated platform-channel testing. No certified fakes exist, no scenario scripts are generated, and the loop cannot express camera/barcode/permissions/location/notifications behaviors.

## Proposed Remediation

**Preferred**: (1) `zfa tdd fake <channel>` generates a framework-certified fake: test-side handler via `TestDefaultBinaryMessengerBinding` that replays scenario scripts. (2) `zfa tdd gen` for platform-backed behaviors generates tests that install the fake and assert on observed calls. (3) Scenario scripts live in `specs/<feature>/tdd/scenarios/*.json`, committed as intent (not agent-written). (4) verify-red classification for channel-timeouts vs assertion failures. (5) Cross-platform matrices: same scenario runs on ios/android/macos hosted tests.

**Alternatives** (optional):
- Manual platform testing — doesn't scale; VISION §9 forbids agent-written mocks.

**Files likely to change**:
- New `fake` subcommand for `zfa tdd`
- Scenario script infrastructure
- Test template for platform-backed behaviors
- verify-red classification (channel-timeouts)
- Cross-platform test harness

**Tests to add or update**:
- `--fake` generates correct test-side handler
- Scenario script replays registered handler
- Verify-red classifies channel-timeouts vs assertion failures
- Cross-platform: same scenario on ios/android/macos

## Risks & Considerations

- Scenario scripts must be intent-committed, not agent-written (VISION §9)
- Cross-platform matrix adds combinatorial complexity
- 15 specs affected — significant scope
- Depends on #827 (namespacing) for correct paths

## Open Questions

- [NEEDS CLARIFICATION: What JSON schema for scenario scripts?]
- [NEEDS CLARIFICATION: Which channels are in scope (camera, barcode, permissions, notifications, location)?]