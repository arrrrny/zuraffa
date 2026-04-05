# 002 - Code Builder for Generation

## Status

Accepted

## Context

String-based generation is fast to write but hard to keep consistent and safe for refactors. Zuraffa needs consistent formatting, reliable imports, and composable generation across plugins.

## Decision

Use `code_builder` with shared builders and `SpecLibrary` to emit Dart code where possible. This keeps output stable, improves formatting consistency, and supports composable code templates.

## Consequences

- Code generation is more structured and maintainable
- Requires more upfront spec construction than plain strings
- Still allows string-based templates where necessary

## Alternatives Considered

- Pure string templates for all generation
- Custom formatter and AST emitter

## References

- `lib/src/core/builder/shared/spec_library.dart`
- `lib/src/core/builder/code_builder_factory.dart`
