# 004 - Generation Transaction System

## Status

Accepted

## Context

Generation can update multiple files. Partial failures risk inconsistent output. The system needs a way to aggregate file operations for dry-run support and conflict detection.

## Decision

Introduce a generation transaction layer that records file operations and validates conflicts before applying. `FileUtils.writeFile` writes into the transaction when present, otherwise writes to disk directly.

## Consequences

- Dry-run and preview features are consistent
- Conflicting operations can be detected early
- Requires extra layer of coordination in generation logic

## Alternatives Considered

- Direct file writes with no conflict detection
- External transactional filesystem dependency

## References

- `lib/src/core/transaction/generation_transaction.dart`
- `lib/src/core/transaction/file_operation.dart`
- `lib/src/utils/file_utils.dart`
