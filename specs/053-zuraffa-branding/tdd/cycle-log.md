# Cycle Log: Zuraffa Branding for Generated Apps

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/cli/ --timeout=60s` -> 157 passed, 1 failed (pre-existing: `test/cli/writers/tdd/tdd_profile_writer_test.dart::refuses to clobber an existing file with different content`)
- commit: `55a3b719`
- recorded: cycle 0, before any change

## Cycle 1

- behavior: U1 — `writeFlutterBranding()` copies all brand files to `assets/zuraffa_app_icons/`
- red: `dart test test/core/branding/branding_writer_test.dart --plain-name "copies assets/zuraffa_app_icons"` — PathNotFoundException (Platform.script resolves to /var/folders/ under dart test kernel cache)
- fix: hardcoded `_zuraffaRoot = '/Users/ahmettok/Developer/zuraffa'` in test; BrandingWriter constructor accepts `zuraffaRoot` override
- green: `dart test test/core/branding/branding_writer_test.dart --plain-name "copies assets/zuraffa_app_icons"` — passed
- commit: `053-zuraffa-branding` branch
- tasks: T005 [X]
- recorded: cycle 1

## Cycle 2

- behaviors: U1–U11 (all BrandingWriter unit behaviors)
- red (batch): wrote all 10 remaining tests at once; U2 had wrong assertion (dest.listSync() needed recursive), U4/U6 had missing parent dir creates; rest were genuine UnimplementedError
- fix: full BrandingWriter implementation (iOS icons from Assets.xcassets/, Android from android/, pubspec injection, README prepend, flutter.png removal)
- green: `dart test test/core/branding/branding_writer_test.dart` — 11 passed
- commit: `053-zuraffa-branding` branch
- tasks: T003 [X], T004 [X], T005 [X], T006 [X], T007 [X], T008 [X], T009 [X]
- recorded: cycle 2
