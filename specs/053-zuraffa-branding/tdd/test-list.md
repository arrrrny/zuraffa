# Test List: Zuraffa Branding for Generated Apps

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point.

| id  | behavior                                                                                          | traces | kind | state   | test |
| --- | ------------------------------------------------------------------------------------------------- | ------ | ---- | ------- | ---- |
| A1  | Flutter app branding: assets/zuraffa_app_icons/ | SC-001 | example | DONE | |
| A2  | Dart CLI branding: assets/zuraffa_app_icons/ | SC-002 | example | DONE | |
| A3  | No flutter.png or flutter_animated.png | SC-003 | example | DONE | |
| A4  | README contains "Zuraffa" in first 10 lines | SC-004 | example | DONE | |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result.

### `lib/src/core/branding/branding_writer.dart`

| id  | behavior                                                                      | traces    | kind | state   | test |
| --- | ----------------------------------------------------------------------------- | --------- | ---- | ------- | ---- |
| U1  | `writeFlutterBranding()` copies all brand files to `assets/zuraffa_app_icons/` | FR-001    | example | DONE | |
| U2  | `writeFlutterBranding()` copies iOS icons to `ios/Runner/Assets.xcassets/`     | FR-002    | example | DONE | |
| U3  | `writeFlutterBranding()` copies Android icons to `android/app/src/main/res/`      | FR-002    | example | DONE | |
| U4  | `writeFlutterBranding()` adds `assets/zuraffa_app_icons/` to `pubspec.yaml`     | FR-001    | example | DONE | |
| U5  | `writeDartBranding()` copies brand assets to `assets/zuraffa_app_icons/`        | FR-003    | example | DONE | |
| U6  | `writeDartBranding()` prepends Zuraffa banner to `README.md`                     | FR-004    | example | DONE | |
| U7  | `writeFlutterBranding()` removes `flutter.png` from the target project           | FR-005    | example | DONE | |
| U8  | `writeFlutterBranding()` removes `flutter_animated.png` from the target project   | FR-005    | example | DONE | |
| U9  | `writeFlutterBranding()` is idempotent: calling twice produces identical output  | FR-006    | example | DONE | |
| U10 | `writeDartBranding()` is idempotent: calling twice produces identical output      | FR-006    | example | DONE | |
| U11 | Branding step is skipped when `assets/zuraffa_app_icons/` already exists         | FR-006    | example | DONE | |

### `lib/src/commands/setup_command.dart`

| id  | behavior                                                                                              | traces | kind | state   | test |
| --- | ----------------------------------------------------------------------------------------------------- | ------ | ---- | ------- | ---- |
| U12 | SetupCommand Flutter branding step | FR-001 | example | DONE | |
| U13 | SetupCommand Dart branding step | FR-003 | example | DONE | |
| U14 | SetupCommand respects --dry-run | FR-006 | example | DONE | |

### `lib/src/commands/make_command.dart`

| id  | behavior                                                                                       | traces | kind | state   | test |
| --- | ---------------------------------------------------------------------------------------------- | ------ | ---- | ------- | ---- |
| U15 | MakeCommand applies Flutter branding | FR-001 | example | DONE | |
| U16 | MakeCommand applies Dart branding | FR-003 | example | DONE | |
| U17 | MakeCommand skips branding if assets exists | FR-006 | example | DONE | |

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
