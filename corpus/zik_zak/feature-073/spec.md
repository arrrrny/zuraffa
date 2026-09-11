# Especificación: 073

**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `Guardado`: `guardar(Session) -> void`
- `Restaurador`: `restaurar() -> List<Session>`

## Requisitos Funcionales

- **FR-001**: El sistema DEBE guardar el estado de 073.
  traces: Guardado
- **FR-002**: El sistema DEBE restaurar la lista de Sessions.
  traces: Restaurador

## Escenarios de Aceptación

1. **Given** un usuario conectado **When** abre 073 **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre 073 **Then** el marcador se muestra.
   **Type**: widget

