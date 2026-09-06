**Template Version**: `zuraffa-1.0`

# Spec: Photos Upload

## Summary

The Photos Upload feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| NotificationParams | `id: String`, `value: num` | typed params |
| NotificationView | `state: NotificationState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `NotificationRepo`: `save(NotificationParams) -> Notification`, `get(String) -> Notification?`

**Presentation**:
- `NotificationPresenter`: `present(NotificationState) -> NotificationView`

## Functional Requirements

- **FR-001**: The system MUST save a Notification when the user commits the Photos Upload form.
  traces: `NotificationRepo.save`
- **FR-002**: The system MUST restore the last Photos Upload state on cold start.
  traces: `Hive.put`, `NotificationRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Photos Upload **Then** the saved Notification list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Photos Upload loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Notification **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

