# Especificación: Adaptive Grid

**Template Version**: `zuraffa-1.0`

## Funktionale Anforderungen

- **FR-001**: El sistema DEBE guardar el estado de Adaptive Grid.
- **FR-002**: El sistema DEBE restaurar la lista de Tickets.

## Akzeptanzszenarien

1. **Given** un usuario conectado **When** abre Adaptive Grid **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre Adaptive Grid **Then** el marcador se muestra.
   **Type**: widget

