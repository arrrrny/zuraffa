import 'file_operation.dart';

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
