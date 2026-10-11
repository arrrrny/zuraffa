**Template Version**: `zuraffa-1.0`

# Spec: 006

## Summary

The 006 feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| BookmarkParams | `id: String`, `value: num` | typed params |
| BookmarkView | `state: BookmarkState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `BookmarkRepo`: `save(BookmarkParams) -> Bookmark`, `get(String) -> Bookmark?`

**Presentation**:
- `BookmarkPresenter`: `present(BookmarkState) -> BookmarkView`

## Functional Requirements

- **FR-001**: The system MUST save a Bookmark when the user commits the 006 form.
  traces: `BookmarkRepo.save`
- **FR-002**: The system MUST restore the last 006 state on cold start.
  traces: `Hive.put`, `BookmarkRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 006 **Then** the saved Bookmark list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 006 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Bookmark **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

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

