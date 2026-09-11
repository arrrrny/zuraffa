# Especificación: 069

**Template Version**: `zuraffa-1.0`

## Exigences Fonctionnelles

- **FR-001**: El sistema DEBE guardar el estado de 069.
  traces: Guardado
- **FR-002**: El sistema DEBE restaurar la lista de Notifications.
  traces: Restaurador

## Scénarios d'Acceptation

1. **Given** un usuario conectado **When** abre 069 **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre 069 **Then** el marcador se muestra.
   **Type**: widget

