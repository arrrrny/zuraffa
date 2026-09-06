# Especificación: Watch Companion

**Template Version**: `zuraffa-1.0`

## Exigences Fonctionnelles

- **FR-001**: El sistema DEBE guardar el estado de Watch Companion.
- **FR-002**: El sistema DEBE restaurar la lista de Notifications.

## Scénarios d'Acceptation

1. **Given** un usuario conectado **When** abre Watch Companion **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre Watch Companion **Then** el marcador se muestra.
   **Type**: widget

