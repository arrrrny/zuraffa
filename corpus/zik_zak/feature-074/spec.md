# Especificación: 074

**Template Version**: `zuraffa-1.0`

## Funktionale Anforderungen

- **FR-001**: El sistema DEBE guardar el estado de 074.
  traces: Guardado
- **FR-002**: El sistema DEBE restaurar la lista de Profiles.
  traces: Restaurador

## Akzeptanzszenarien

1. **Given** un usuario conectado **When** abre 074 **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre 074 **Then** el marcador se muestra.
   **Type**: widget

