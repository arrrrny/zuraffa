# 003 - AST-based Append Mode

## Status

Accepted

## Context

Zuraffa supports append mode for extending existing files without overwriting user code. String concatenation risks malformed Dart or duplicated members.

## Decision

Use AST parsing and targeted append strategies to insert methods, fields, and directives. `AppendExecutor` selects a strategy based on the append request type.

## Consequences

- Safer append behavior with duplicate detection
- Preserves user edits
- Requires analyzer-based parsing and more complex logic

## Alternatives Considered

- String concatenation with regex detection
- Full file regeneration with user code markers

## References

- `lib/src/core/ast/append_executor.dart`
- `lib/src/core/ast/strategies/append_strategy.dart`
