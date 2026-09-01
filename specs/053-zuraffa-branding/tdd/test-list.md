# Test List: Zuraffa Branding for Generated Apps

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point.

| id  | behavior                                                                                          | traces | kind | state   | test |
| --- | ------------------------------------------------------------------------------------------------- | ------ | ---- | ------- | ---- |
| A1  | A Flutter app created by `zfa setup` contains Zuraffa giraffe icons in `assets/zuraffa_app_icons/` | SC-001 | example | PENDING | |
| A2  | A Dart CLI package created by `zfa setup` contains Zuraffa brand assets in `assets/`                | SC-002 | example | PENDING | |
| A3  | A generated Flutter app contains no `flutter.png` or `flutter_animated.png` files                    | SC-003 | example | PENDING | |
| A4  | A generated app's README contains "Zuraffa" within the first 10 lines                             | SC-004 | example | PENDING | |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result.

### `lib/src/core/branding/branding_writer.dart`

| id  | behavior                                                                      | traces    | kind | state   | test |
| --- | ----------------------------------------------------------------------------- | --------- | ---- | ------- | ---- |
| U1  | `writeFlutterBranding()` copies all brand files to `assets/zuraffa_app_icons/` | FR-001    | example | DONE | |
| U2  | `writeFlutterBranding()` copies iOS icons to `ios/Runner/Assets.xcassets/`     | FR-002    | example | PENDING | |
| U3  | `writeFlutterBranding()` copies Android icons to `android/app/src/main/res/`      | FR-002    | example | PENDING | |
| U4  | `writeFlutterBranding()` adds `assets/zuraffa_app_icons/` to `pubspec.yaml`     | FR-001    | example | PENDING | |
| U5  | `writeDartBranding()` copies brand assets to `assets/zuraffa_app_icons/`        | FR-003    | example | PENDING | |
| U6  | `writeDartBranding()` prepends Zuraffa banner to `README.md`                     | FR-004    | example | PENDING | |
| U7  | `writeFlutterBranding()` removes `flutter.png` from the target project           | FR-005    | example | PENDING | |
| U8  | `writeFlutterBranding()` removes `flutter_animated.png` from the target project   | FR-005    | example | PENDING | |
| U9  | `writeFlutterBranding()` is idempotent: calling twice produces identical output  | FR-006    | example | PENDING | |
| U10 | `writeDartBranding()` is idempotent: calling twice produces identical output      | FR-006    | example | PENDING | |
| U11 | Branding step is skipped when `assets/zuraffa_app_icons/` already exists         | FR-006    | example | PENDING | |

### `lib/src/commands/setup_command.dart`

| id  | behavior                                                                                              | traces | kind | state   | test |
| --- | ----------------------------------------------------------------------------------------------------- | ------ | ---- | ------- | ---- |
| U12 | `SetupCommand` runs the Flutter branding step after deep-link pre-seed, before TDD baseline           | FR-001 | example | PENDING | |
| U13 | `SetupCommand` runs the Dart branding step after dependency wiring, before TDD baseline              | FR-003 | example | PENDING | |
| U14 | `SetupCommand` branding step respects `--dry-run` flag: no files written                             | FR-006 | example | PENDING | |

### `lib/src/commands/make_command.dart`

| id  | behavior                                                                                       | traces | kind | state   | test |
| --- | ---------------------------------------------------------------------------------------------- | ------ | ---- | ------- | ---- |
| U15 | `MakeCommand` applies Flutter branding if `assets/zuraffa_app_icons/` is absent                | FR-001 | example | PENDING | |
| U16 | `MakeCommand` applies Dart branding if `assets/zuraffa_app_icons/` is absent                   | FR-003 | example | PENDING | |
| U17 | `MakeCommand` skips branding if `assets/zuraffa_app_icons/` already exists                      | FR-006 | example | PENDING | |

## Invariants and edge cases still to place

- `SetupCommand` branding step must not fail if the source brand asset directory is missing; it should warn and continue (graceful degradation for CI environments where assets may not be checked out)
- Brand asset paths are relative to the zuraffa repository root, not the generated app

## Out of scope

- App Store / Play Store screenshot generation: separate workflow, not part of `zfa setup`
- Runtime branding switching: branding is baked in at project creation time only
- Non-Flutter Dart web apps: Dart web scaffolding not in scope for this feature

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time, so this
file is readable on its own:

- Single test: `dart test <file> --plain-name "<name>"`
- Full suite: `dart test`
- Static analysis: `dart analyze`
- Feature scope suite: `dart test test/core/branding/ test/commands/`
