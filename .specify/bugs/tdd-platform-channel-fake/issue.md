# Bug Issue: [TDD-120] Platform-channel test harness — certified fakes for camera, barcode, permissions, notifications, location

- **Slug**: tdd-platform-channel-fake
- **Fetched**: 2026-09-02
- **Issue**: 831
- **URL**: https://github.com/arrrrny/zuraffa/issues/831
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Specs 013 (barcode), 070 (permissions), 072 (location), 059/060 (local+push notifications), 077 (photo upload/camera) sit on platform channels. Pure-function subjects cannot express them; today nothing in the TDD loop provides a certified fake.

Required (system fix — VISION §9 simulation worlds):
1. `zfa tdd fake <channel>` generates a framework-certified fake for a platform channel: a test-side handler registered via `TestDefaultBinaryMessengerBinding` that replays a scenario script (JSON: responses, errors, permission states).
2. `zfa tdd gen` for platform-backed behaviors generates tests that install the fake and assert on the observed calls (arguments recorded, ordering).
3. Fakes are NOT agent-written mocks (no grading your own homework): scenario scripts live in `specs/<feature>/tdd/scenarios/*.json`, committed as intent.
4. verify-red classification for channel-timeouts vs assertion failures.
5. Cross-platform matrices: same scenario runs on ios/android/macos hosted tests where feasible.

## Comments

None.