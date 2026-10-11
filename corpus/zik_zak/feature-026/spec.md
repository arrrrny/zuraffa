**Template Version**: `zuraffa-1.0`

# Spec: 026

## Summary

The 026 feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ProfileParams | `id: String`, `value: num` | typed params |
| ProfileView | `state: ProfileState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `ProfileRepo`: `save(ProfileParams) -> Profile`, `get(String) -> Profile?`

**Presentation**:
- `ProfilePresenter`: `present(ProfileState) -> ProfileView`

## Functional Requirements

- **FR-001**: The system MUST save a Profile when the user commits the 026 form.
  traces: `ProfileRepo.save`
- **FR-002**: The system MUST restore the last 026 state on cold start.
  traces: `Hive.put`, `ProfileRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 026 **Then** the saved Profile list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 026 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Profile **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

