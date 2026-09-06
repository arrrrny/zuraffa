**Template Version**: `zuraffa-1.0`

# Spec: Report Content

## Summary

The Report Content feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Bookmark when the user commits the Report Content form.
- **FR-002**: The system MUST restore the last Report Content state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Report Content **Then** the saved Bookmark list renders.
2. **Given** an empty local cache **When** Report Content loads **Then** the placeholder renders.
3. **Given** a committed Bookmark **When** the device restarts **Then** the value equals the last write.

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

