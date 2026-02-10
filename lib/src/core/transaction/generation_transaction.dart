import 'dart:async';

import 'file_operation.dart';
import 'transaction_result.dart';

class GenerationTransaction {
  static final Object _zoneKey = Object();

  final bool dryRun;
  final List<FileOperation> _operations = [];

  GenerationTransaction({required this.dryRun});

  List<FileOperation> get operations => List.unmodifiable(_operations);

  void addOperation(FileOperation operation) {
    _operations.add(operation);
  }

  TransactionResult validate() {
    final conflicts = <String>[];
    final seenPaths = <String>{};

    for (final operation in _operations) {
      if (!seenPaths.add(operation.path)) {
        conflicts.add('Multiple operations for ${operation.path}');
      }
      final conflict = operation.detectConflict();
      if (conflict != null) {
        conflicts.add('${operation.path}: $conflict');
      }
    }

    return TransactionResult(
      success: conflicts.isEmpty,
      dryRun: dryRun,
      operations: operations,
      conflicts: conflicts,
      errors: const [],
    );
  }

  Future<TransactionResult> commit() async {
    if (dryRun) {
      return TransactionResult(
        success: true,
        dryRun: true,
        operations: operations,
        conflicts: const [],
        errors: const [],
      );
    }

    final validation = validate();
    if (!validation.success) {
      return validation;
    }

    final applied = <FileOperation>[];
    try {
      for (final operation in _operations) {
        await operation.apply();
        applied.add(operation);
      }
      return TransactionResult(
        success: true,
        dryRun: false,
        operations: operations,
        conflicts: const [],
        errors: const [],
      );
    } catch (e) {
      for (final operation in applied.reversed) {
        try {
          await operation.rollback();
        } catch (_) {}
      }
      return TransactionResult(
        success: false,
        dryRun: false,
        operations: operations,
        conflicts: const [],
        errors: ['Transaction failed: $e'],
      );
    }
  }

  static GenerationTransaction? get current =>
      Zone.current[_zoneKey] as GenerationTransaction?;

  static Future<T> run<T>(
    GenerationTransaction transaction,
    Future<T> Function() action,
  ) {
    return runZoned(action, zoneValues: {_zoneKey: transaction});
  }
}
