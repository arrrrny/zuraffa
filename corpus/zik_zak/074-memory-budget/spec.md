# Especificación: Memory Budget

**Template Version**: `zuraffa-1.0`

## Funktionale Anforderungen

- **FR-001**: El sistema DEBE guardar el estado de Memory Budget.
- **FR-002**: El sistema DEBE restaurar la lista de Profiles.

## Akzeptanzszenarien

1. **Given** un usuario conectado **When** abre Memory Budget **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre Memory Budget **Then** el marcador se muestra.
   **Type**: widget

