**Template Version**: `zuraffa-1.0`

# Spec: 003

## Summary

The 003 feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| WalletParams | `id: String`, `value: num` | typed params |
| WalletView | `state: WalletState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `WalletRepo`: `save(WalletParams) -> Wallet`, `get(String) -> Wallet?`

**Presentation**:
- `WalletPresenter`: `present(WalletState) -> WalletView`

## Functional Requirements

- **FR-001**: The system MUST save a Wallet when the user commits the 003 form.
  traces: `WalletRepo.save`
- **FR-002**: The system MUST restore the last 003 state on cold start.
  traces: `Hive.put`, `WalletRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 003 **Then** the saved Wallet list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 003 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Wallet **When** the device restarts **Then** the value equals the last write.
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

