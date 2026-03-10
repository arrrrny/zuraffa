import 'file_operation.dart';

/// Represents the outcome of a [GenerationTransaction].
///
/// Contains details about applied operations, detected conflicts,
/// and any errors encountered during commit or rollback.
class TransactionResult {
  final bool success;
  final bool dryRun;
  final List<FileOperation> operations;
  final List<String> conflicts;
  final List<String> errors;

  TransactionResult({
    required this.success,
    required this.dryRun,
    required this.operations,
    required this.conflicts,
    required this.errors,
  });
}
