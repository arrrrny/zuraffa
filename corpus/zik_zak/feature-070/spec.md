# Especificación: 070

**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `Guardado`: `guardar(Coupon) -> void`
- `Restaurador`: `restaurar() -> List<Coupon>`

## Requisitos Funcionales

- **FR-001**: El sistema DEBE guardar el estado de 070.
  traces: Guardado
- **FR-002**: El sistema DEBE restaurar la lista de Coupons.
  traces: Restaurador

## Escenarios de Aceptación

1. **Given** un usuario conectado **When** abre 070 **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre 070 **Then** el marcador se muestra.
   **Type**: widget

