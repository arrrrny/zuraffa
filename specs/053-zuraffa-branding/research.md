# Research: Zuraffa Branding

**Feature**: Zuraffa Branding for Generated Apps
**Status**: No research needed

All technical questions are resolved from the codebase and the existing `setup_command.dart` implementation:

- The `SetupCommand` runs after `flutter create` / `dart create` — we copy into an existing directory structure
- Platform icon paths are well-known (Flutter creates them at predictable locations)
- Asset copying is straightforward `dart:io` file operations — no special tooling needed
- No external research required for this feature
