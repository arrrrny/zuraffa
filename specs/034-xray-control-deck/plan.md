# Implementation Plan: X-Ray Control Deck — @XRayMock Decorator & Synthetic Payload Injector

**Branch**: `034-xray-control-deck` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/034-xray-control-deck/spec.md`

## Summary

This feature adds the pure-Dart runtime half of the X-Ray Control Deck (v6 Track 4.3, issue #185). The codegen half (`zfa xray deck` and `zfa xray mock`) already exists — it scans `@XRayMock` annotations and YAML files and generates `<entity>_xray_deck.dart` files plus the `xray_decks.dart` barrel. What's missing is the **runtime data layer**: the in-memory `XRayMockEntry` type, the `XRayMockType` enum with its color coding, and the `XRayControlDeck` registry that the Flutter panel subscribes to and that `registerEntries(List<XRayMockEntry>)` operates on (FR-006).

The deliverable is therefore the **runtime registry + entry data class + type/color enum + shared YAML parser + release-mode strip** for the Control Deck. The Flutter half (panel slide-up animation, button tap → payload injection) lives in `zuraffa_flutter` and is referenced by name but not regenerated here.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`).

**Primary Dependencies**: `args`, `yaml`, `path`, `uuid` (existing). No new dependencies added.

**Storage**: In-memory only — the registry is a process-singleton (`XRayControlDeck.instance`). Mock entries are not persisted (they're regenerated from annotations/YAML on each build).

**Testing**: `package:test` (fast tier — `dart test` excludes `slow` tag). New tests in `test/plugins/xray/` and `test/regression/`.

**Target Platform**: Pure-Dart VM.

**Project Type**: Library + CLI + codegen + MCP server.

**Performance Goals**: `registerEntries` of 20 entries must complete in <5ms (SC-001 budget is 5s including the Flutter UI render, so the data layer must be negligible). Dedup by name+payload is O(n) per batch.

**Constraints**: Zero `package:flutter` imports. Zero X-Ray code in release builds (FR-007 / SC-003) — enforced via the same `bool.fromEnvironment('dart.vm.product')` constant introduced in spec 036.

**Scale/Scope**: ~4 new lib files, ~5 new test files. No codegen changes to existing files in this PR (the codegen already exists; this PR adds the runtime contract that the codegen-generated `register<Entity>XRayDeck()` calls will eventually invoke — but that wiring is intentionally deferred to a follow-up to keep this PR scoped to the runtime data layer).

## Constitution Check

1. **Library-First**: New code lives under `lib/src/plugins/xray/` as standalone files with a barrel export.
2. **CLI Interface**: The existing `zfa xray deck` CLI is unchanged; this PR adds the runtime types the generated code references.
3. **Test-First (NON-NEGOTIABLE)**: Every behavior has a failing test before implementation. Red evidence in `tdd/red/`.
4. **Integration Testing**: Contract tests for `XRayMockEntry.toJson()` so the MCP bridge (Track 4.4) can serialize entries.
5. **Simplicity**: No new dependencies. Pure-Dart data classes + a `Stream`-based registry + a YAML parser helper.

All gates pass at design time.

## Project Structure

### Documentation (this feature)

```text
specs/034-xray-control-deck/
├── spec.md              (input — already exists)
├── plan.md              (this file)
├── tasks.md             (MVP-first task list)
├── checklists/
│   └── requirements.md  (already exists)
└── tdd/
    ├── test-list.md
    ├── red/
    │   ├── 01-mock-type-enum.md
    │   ├── 02-mock-entry-data.md
    │   ├── 03-control-deck-registry.md
    │   ├── 04-yaml-parser.md
    │   └── 05-release-mode-strip.md
    └── verification.md
```

### Source code

```text
lib/src/plugins/xray/
├── xray_deck_barrel_writer.dart     (existing — untouched)
├── xray_mock_scaffolder.dart         (existing — untouched)
├── xray_mock_type.dart               (NEW — enum + color mapping)
├── xray_mock_entry.dart              (NEW — immutable data class)
├── xray_control_deck.dart            (NEW — runtime registry + Stream + release guard)
└── xray_mock_yaml.dart               (NEW — shared YAML parser for {name, payload, type?})
```

### Tests

```text
test/plugins/xray/
├── xray_mock_type_test.dart          (NEW)
├── xray_mock_entry_test.dart         (NEW)
├── xray_control_deck_test.dart       (NEW)
└── xray_mock_yaml_test.dart          (NEW)

test/regression/
└── issue_185_xray_deck_release_strip_test.dart  (NEW — SC-003 regression)
```

## Goals & Strategy

### Primary goal

Add the pure-Dart runtime contract for the Control Deck so that:
- The Flutter side can call `XRayControlDeck.instance.registerEntries([...])` to populate the deck at boot (driven by the codegen-generated `register<Entity>XRayDeck()` calls).
- The Flutter panel can subscribe to `XRayControlDeck.instance.entries` (a `Stream<List<XRayMockEntry>>`) to render the buttons.
- Tap → inject is a single method call: `XRayControlDeck.instance.inject(entryName)` returns the entry's payload (the Flutter side then routes it into the UseCase via the existing DI).
- Release builds strip all of the above.

### Non-goals

- Implementing the Flutter panel (lives in `zuraffa_flutter`).
- Implementing the actual payload injection into the UseCase (the Flutter side routes via DI; the pure-Dart side just returns the payload string).
- Changing the existing `zfa xray deck` / `zfa xray mock` codegen (out of scope — the generated code can adopt the new types in a follow-up PR).
- The `@XRayMock` annotation definition itself (lives in `zuraffa_flutter`).

### Strategy

1. **MVP slice (P1)**: `XRayMockType` enum + `XRayMockEntry` data class + `XRayControlDeck` registry with `registerEntries` + dedup + Stream + release guard. This satisfies FR-006, SC-001, SC-003.
2. **YAML slice (P1)**: Shared `XRayMockYaml.parse(yamlContent)` helper returning `List<XRayMockEntry>`. Used by the codegen in a follow-up PR; tested here in isolation.
3. **Release-strip regression (P2)**: A regression test that asserts `XRayControlDeck.instance.registerEntries` is a no-op in release mode.

### Architecture

The runtime layer is intentionally minimal: immutable data classes (`XRayMockEntry`), a single mutable registry (`XRayControlDeck`), and a YAML parser. The release-mode strip mirrors the design from spec 036: a compile-time constant `bool.fromEnvironment('dart.vm.product')` plus an overridable constructor param for testing.

### Risks

- **Risk**: the Flutter `zuraffa_flutter` package has not yet shipped the `@XRayMock` annotation. **Mitigation**: the runtime layer doesn't reference the annotation class — it only consumes the parsed `XRayMockEntry` records. The codegen can produce these from any source (annotation, YAML, programmatic).
- **Risk**: the existing `zfa xray deck` command has its own inline YAML parser — this PR adds a shared `XRayMockYaml.parse(...)` helper, but doesn't refactor the command to use it (out of scope; would risk regressions in the existing `test/commands/xray_deck_cli_test.dart`).

## Changes

*Reference for tracking — full task list lives in [tasks.md](./tasks.md).*

### Phase 1: Setup
- Create new files under `lib/src/plugins/xray/`.

### Phase 2: Type + Entry (P1)
- Implement `XRayMockType` enum + color mapping.
- Implement `XRayMockEntry` data class.

### Phase 3: Registry (P1)
- Implement `XRayControlDeck` runtime registry + Stream + release guard.

### Phase 4: YAML Parser (P1)
- Implement `XRayMockYaml.parse(yamlContent)` helper.

### Phase 5: Release-strip Regression (P2)
- Add `test/regression/issue_185_xray_deck_release_strip_test.dart`.

### Phase 6: Verify
- Run `dart analyze` (no new errors/warnings).
- Run `dart test` (relevant subset).
- Write `tdd/verification.md`.

## Sketch

### XRayMockType (enum + color)

```dart
enum XRayMockType {
  valid,    // green   0xFF00C853
  error,    // red     0xFFD50000
  unknown;  // neutral 0xFF9E9E9E
  int get color;
  String get label;
  static XRayMockType fromString(String? s);
}
```

### XRayMockEntry (immutable)

```dart
class XRayMockEntry {
  final String name;
  final String payload;
  final XRayMockType type;
  const XRayMockEntry({
    required this.name,
    required this.payload,
    this.type = XRayMockType.unknown,
  });
  Map<String, dynamic> toJson();
  factory XRayMockEntry.fromJson(Map<String, dynamic> json);
  @override
  bool operator ==(Object other);  // by name+payload pair
  @override
  int get hashCode;                // by name+payload pair
}
```

### XRayControlDeck (mutable registry + Stream + release guard)

```dart
class XRayControlDeck {
  static final XRayControlDeck instance = XRayControlDeck();
  final bool _isReleaseMode;
  final Map<String, XRayMockEntry> _entriesByNameAndPayload = {};
  final StreamController<List<XRayMockEntry>> _controller =
      StreamController.broadcast();

  XRayControlDeck({bool? isReleaseMode});

  List<XRayMockEntry> get entries;       // snapshot
  Stream<List<XRayMockEntry>> get changes;

  void registerEntries(List<XRayMockEntry> newEntries);   // dedup by name+payload
  void clear();
  XRayMockEntry? find(String name, String payload);
  String? inject(String name);            // returns payload or null
  Map<String, dynamic> toJson();
}
```

### XRayMockYaml (shared parser)

```dart
class XRayMockYaml {
  static List<XRayMockEntry> parse(String yamlContent);
  static List<XRayMockEntry> parseFile(String path);
}
```

## Deferred / Future Work

- **Codegen wiring**: the existing `zfa xray deck` command can be refactored to emit `XRayControlDeck.instance.registerEntries([...])` calls in the generated `<entity>_xray_deck.dart` file (so the deck populates itself at boot). Deferred to a follow-up PR to keep this PR scoped.
- **Flutter panel**: the sliding Control Deck UI lives in `zuraffa_flutter`.
- **MCP integration**: the MCP bridge will expose `POST /xray/control-deck` to inject a mock from an external agent — wired in Track 4.4 (spec 035).
