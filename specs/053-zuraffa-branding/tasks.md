# Tasks: Zuraffa Branding for Generated Apps

**Input**: Design documents from `/specs/053-zuraffa-branding/`

**Prerequisites**: plan.md, spec.md, quickstart.md

**Note**: Tests are MANDATORY for this feature. All test tasks must be observed failing before their implementation tasks begin. Behavior markers `[A1]`–`[A4]` are acceptance behaviors (outer loop); `[U1]`–`[U17]` are unit behaviors (inner loop).

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the branding module scaffold

- [X] T001 [X] Create directory `lib/src/core/branding/` in the zuraffa repository
- [X] T002 [X] Create `lib/src/core/branding/branding_config.dart` — holds `BrandAssetConfig` class with asset source path (default: `assets/zuraffa_app_icons/`) and platform options, configurable via `.zfa.json`

---

## Phase 2: Foundational (Core BrandingWriter)

**Purpose**: Core branding logic used by both Flutter and Dart CLI paths

- [X] T003 [X] Create `lib/src/core/branding/branding_writer.dart` — define `BrandingWriter` class with:
  - `_copyAssetDirectory()` — copies all files from source to target directory recursively, skip-if-exists for idempotency
  - `_copyIconFiles()` — copies only icon files to platform-specific directories
  - `_updatePubspecAssets()` — adds `assets/zuraffa_app_icons/` to pubspec.yaml flutter assets section if not already present
  - `_updateReadme()` — prepends Zuraffa banner to README.md if not already present
  - `_removeFlutterDefaults()` — deletes any `flutter.png`, `flutter_animated.png` in the target project
- [X] T004 [X] Create `lib/src/core/branding/branding_writer_test.dart` — unit tests for BrandingWriter using a temp directory fixture. **Write tests FIRST, ensure they FAIL before implementation.** Test tasks below carry `[U1]`–`[U11]` behavior markers.

---

## Phase 3: User Story 1 - Flutter Apps Use Zuraffa Branding (Priority: P1)

**Goal**: `zfa setup` and `zfa make` for Flutter apps copy Zuraffa app icons to generated projects

**Independent Test**: Run `zfa setup my_app --flutter` in `/tmp`, verify `my_app/assets/zuraffa_app_icons/` exists, platform icon dirs contain giraffe icons, no Flutter defaults remain

### Tests for User Story 1

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T005 [X] [US1] [U1] Test: `BrandingWriter.writeFlutterBranding()` copies assets/zuraffa_app_icons/ to target project assets/ directory in `test/core/branding/branding_writer_test.dart`
- [X] T006 [X] [US1] [U9] [U11] Test: Flutter branding is idempotent: calling twice produces identical output in `test/core/branding/branding_writer_test.dart`
- [X] T007 [X] [US1] [U4] Test: After Flutter branding, `pubspec.yaml` contains `assets/zuraffa_app_icons/` in flutter assets section in `test/core/branding/branding_writer_test.dart`

### Implementation for User Story 1

- [X] T008 [X] [US1] [U1] [U2] [U3] Implement `writeFlutterBranding()` in `lib/src/core/branding/branding_writer.dart` — copies iOS icons to `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, Android icons to `android/app/src/main/res/mipmap-*/`, store images to `assets/`
- [X] T009 [X] [US1] [U5] [U6] Implement `writeDartBranding()` in `lib/src/core/branding/branding_writer.dart` — copies brand assets to `assets/`, updates README
- [X] T010 [X] [US1] [U12] Hook `BrandingWriter` into `lib/src/commands/setup_command.dart` — call `brandingWriter.writeFlutterBranding()` as step 5a after deep-link pre-seed, before TDD baseline; pass `projectRoot`, `dryRun`, `verbose`
- [X] T011 [X] [US1] [U15] Hook `BrandingWriter` into `lib/src/commands/make_command.dart` — call `brandingWriter.writeFlutterBranding()` after entity code generation if project is Flutter and `assets/zuraffa_app_icons/` does not exist; pass `projectRoot`, `dryRun`, `verbose`

---

## Phase 4: User Story 2 - Dart CLI Apps Use Zuraffa Branding (Priority: P1)

**Goal**: `zfa setup` and `zfa make` for Dart CLI packages include Zuraffa brand assets

**Independent Test**: Run `zfa setup my_pkg --dart` in `/tmp`, verify `my_pkg/assets/zuraffa_app_icons/` exists and README contains Zuraffa branding

### Tests for User Story 2

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T012 [X] [US2] [U5] Test: `BrandingWriter.writeDartBranding()` copies brand assets to target `assets/` directory in `test/core/branding/branding_writer_test.dart`
- [X] T013 [X] [US2] [U6] Test: After Dart branding, `README.md` contains "Zuraffa" within first 10 lines in `test/core/branding/branding_writer_test.dart`

### Implementation for User Story 2

- [X] T014 [X] [US2] [U5] [U6] Implement `writeDartBranding()` — copies brand assets to `assets/zuraffa_app_icons/`, prepends Zuraffa banner to README.md (may be combined with T009 if both share implementation)
- [X] T015 [X] [US2] [U13] Hook `BrandingWriter.writeDartBranding()` into `lib/src/commands/setup_command.dart` — in the `--dart` branch, call branding step after wiring dependencies
- [X] T016 [X] [US2] [U16] Hook `BrandingWriter.writeDartBranding()` into `lib/src/commands/make_command.dart` — in Dart CLI path, call branding if `assets/zuraffa_app_icons/` does not exist

---

## Phase 5: User Story 3 - No Flutter Default Icons Remain (Priority: P2)

**Goal**: All default Flutter/Dart logos are removed from generated apps

**Independent Test**: Search generated Flutter project for `flutter.png`, `flutter_animated.png`, `FlutterLogo` — expect zero results

### Tests for User Story 3

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T017 [X] [US3] [U7] Test: `writeFlutterBranding()` removes any `flutter.png` from target project in `test/core/branding/branding_writer_test.dart`
- [X] T018 [X] [US3] [U8] Test: After Flutter branding, searching for "FlutterLogo" in drawable XML files returns zero results in `test/core/branding/branding_writer_test.dart`

### Implementation for User Story 3

- [X] T019 [X] [US3] [U7] [U8] Implement `_removeFlutterDefaults()` in `BrandingWriter` — scan for and delete `flutter.png`, `flutter_animated.png` in `android/app/src/main/res/drawable*/`; also update `android/app/src/main/res/values/ic_launcher_background.xml` to remove FlutterLogo references if present
- [X] T020 [X] [US3] [U7] [U8] Add FlutterLogo removal to `writeFlutterBranding()` — call `_removeFlutterDefaults()` as part of the branding flow

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T021 [X] Run `dart analyze lib/src/core/branding/` and fix any lint warnings
- [X] T022 [X] Run `dart test test/core/branding/` and verify all tests pass
- [X] T023 [X] Run quickstart.md validation scenarios end-to-end (Flutter + Dart CLI setup in temp dirs)
- [X] T024 [X] Update `doc/HOOK_SYSTEM.md` or relevant docs if branding affects command hook ordering

---

## Acceptance Behavior Verification Tasks

- [X] T025 [X] [A1] Acceptance: Run `zfa setup test_flutter_app --flutter` in temp dir and verify `test_flutter_app/assets/zuraffa_app_icons/` exists with giraffe icons
- [X] T026 [X] [A2] Acceptance: Run `zfa setup test_dart_pkg --dart` in temp dir and verify `test_dart_pkg/assets/zuraffa_app_icons/` exists
- [X] T027 [X] [A3] Acceptance: Search generated Flutter app for `flutter.png`, `flutter_animated.png` — expect zero results
- [X] T028 [X] [A4] Acceptance: Verify generated app README contains "Zuraffa" within first 10 lines

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — blocks all user stories
- **User Stories (Phase 3–5)**: All depend on Foundational
- **Polish (Phase 6)**: Depends on all user stories complete
- **Acceptance Verification (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (Flutter Branding)**: Can start after Foundational (T003)
- **US2 (Dart Branding)**: Can start after Foundational (T003), can run in parallel with US1
- **US3 (No Defaults)**: Depends on US1 being partially complete (T008 done), since Flutter defaults are removed as part of Flutter branding

### Within Each User Story

- Tests (T005–T007, T012–T013, T017–T018) written and FAIL first
- Core writer methods (T008–T009) before command hook integration (T010–T011)
- Command integration (T010–T011, T015–T016) after writer methods

### Parallel Opportunities

- T001 and T002: Setup can run in parallel
- T008 and T009: Flutter and Dart writer implementations can run in parallel (same class, different methods)
- T010 and T015: SetupCommand hooks for Flutter and Dart can run in parallel
- T011 and T016: MakeCommand hooks for Flutter and Dart can run in parallel

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 (T001–T002)
2. Complete Phase 2 (T003–T004)
3. Complete Phase 3 (T005–T011) — Flutter branding MVP
4. **STOP and VALIDATE**: Run `zfa setup my_app --flutter` in temp dir, verify branding applied

### Full Delivery

1. Complete Phase 1 + Phase 2
2. Complete Phase 3 (US1) → validate
3. Complete Phase 4 (US2) → validate
4. Complete Phase 5 (US3) → validate
5. Complete Phase 6 (Polish)

---

## Notes

- `BrandingWriter` methods must be idempotent — calling twice on same project produces identical result
- Brand assets source path is resolved relative to the zuraffa repo root (not the generated app)
- All file operations use `dart:io` — no external dependencies
