# Spec: Updates Check (epic: commerce)

**Template Version**: `zuraffa-1.0`

## Layer Contracts — epic-level

**Domain**:
- `WalletRepo`: `save(Wallet) -> void`

**Function**:
- `WalletTotal`: `compute(List<Wallet>) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute the Updates Check total via the epic contract.
  traces: `WalletTotal.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance

