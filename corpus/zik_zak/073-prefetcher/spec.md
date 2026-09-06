# Especificación: Prefetcher

**Template Version**: `zuraffa-1.0`

## Requisitos Funcionales

- **FR-001**: El sistema DEBE guardar el estado de Prefetcher.
- **FR-002**: El sistema DEBE restaurar la lista de Sessions.

## Escenarios de Aceptación

1. **Given** un usuario conectado **When** abre Prefetcher **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre Prefetcher **Then** el marcador se muestra.
   **Type**: widget

