**Template Version**: `zuraffa-1.0`

# Spec: 027

## Summary

The 027 feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Wallet when the user commits the 027 form.
  traces: `WalletRepo.save`
- **FR-002**: The system MUST restore the last 027 state on cold start.
  traces: `Hive.put`, `WalletRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 027 **Then** the saved Wallet list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 027 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Wallet **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

