# Especificación: 072

**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `Guardado`: `guardar(Report) -> void`
- `Restaurador`: `restaurar() -> List<Report>`

## Exigences Fonctionnelles

- **FR-001**: El sistema DEBE guardar el estado de 072.
  traces: Guardado
- **FR-002**: El sistema DEBE restaurar la lista de Reports.
  traces: Restaurador

## Scénarios d'Acceptation

1. **Given** un usuario conectado **When** abre 072 **Then** la lista guarda.
   **Type**: acceptance
2. **Given** un dispositivo sin conexión **When** abre 072 **Then** el marcador se muestra.
   **Type**: widget

