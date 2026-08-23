# Changelog

All notable changes to `zuraffa_flutter` are documented here. The framework changelog
lives in the [repository root](https://github.com/arrrrny/zuraffa/blob/master/CHANGELOG.md).

## [6.0.0] - 2026-08-23

### Added

- First standalone release: the Flutter UI layer split out of the `zuraffa` package, which
  is now pure Dart. Depends on hosted `zuraffa: ^6.0.0`.
- **Presentation**: `View`, `ResponsiveView`, `AdaptiveView`, `Presenter`, `Controller`,
  `ControlledWidget`, plus platform layout resolution (`PlatformContext`, `DeviceClass`,
  `PlatformClass`).
- **App shells**: mobile / tablet / desktop / macOS shells with `AppShellResolver`.
- **State widgets**: `SignalBuilder` and `FragmentBuilder` over Zuraffa signal slices,
  with dual-layer (DomainState / ViewState) support.
- **X-Ray**: visual overlay with bounding boxes, control deck, deterministic widget IDs,
  `@XRayMock` payload injection, shake-to-activate, and an MCP bridge server for AI
  inspection of the running UI.
- **Module wiring**: `AppRunner` and route builder helpers for `ZuraffaEngine` plugins.
