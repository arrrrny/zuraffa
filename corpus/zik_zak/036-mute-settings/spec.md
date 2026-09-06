**Template Version**: `zuraffa-1.0`

# Spec: Mute Settings

## Summary

The Mute Settings feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ReportParams | `id: String`, `value: num` | typed params |
| ReportView | `state: ReportState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `ReportRepo`: `save(ReportParams) -> Report`, `get(String) -> Report?`

**Presentation**:
- `ReportPresenter`: `present(ReportState) -> ReportView`

## Functional Requirements

- **FR-001**: The system MUST save a Report when the user commits the Mute Settings form.
- **FR-002**: The system MUST restore the last Mute Settings state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Mute Settings **Then** the saved Report list renders.
2. **Given** an empty local cache **When** Mute Settings loads **Then** the placeholder renders.
3. **Given** a committed Report **When** the device restarts **Then** the value equals the last write.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1, U2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A1, A2]
    flutter_allowed: true
  - lane: BOTH
    behaviors: [A3]
    flutter_allowed: conditionally
```

