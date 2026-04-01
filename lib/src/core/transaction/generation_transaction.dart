import 'dart:async';

import '../context/file_system.dart';
import 'file_operation.dart';
import 'transaction_result.dart';

/// Manages atomic file operations during generation.
///
/// Ensures that multiple file changes (writes, deletes, appends) are validated
/// for conflicts and applied together, with rollback support on failure.
class GenerationTransaction {
  static final Object _zoneKey = Object();

  final bool dryRun;
  final bool force;
  final List<FileOperation> _operations = [];

  GenerationTransaction({required this.dryRun, this.force = false});

  List<FileOperation> get operations => List.unmodifiable(_operations);

  void addOperation(FileOperation operation) {
    _operations.add(operation);
  }

  Future<TransactionResult> validate(FileSystem fileSystem) async {
    final conflicts = <String>[];
    final seenPaths = <String>{};

    for (final operation in _operations) {
      if (!seenPaths.add(operation.path)) {
        conflicts.add('Multiple operations for ${operation.path}');
      }
      final conflict = await operation.detectConflict(fileSystem);
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

  Future<TransactionResult> commit(FileSystem fileSystem) async {
    if (dryRun) {
      return TransactionResult(
        success: true,
        dryRun: true,
        operations: operations,
        conflicts: const [],
        errors: const [],
      );
    }

    final validation = await validate(fileSystem);
    if (!validation.success) {
      if (validation.conflicts.isNotEmpty) {
        for (final c in validation.conflicts) {
          print('[conflict] $c');
        }
      }
      return validation;
    }

    final applied = <FileOperation>[];
    try {
      for (final operation in _operations) {
        await operation.apply(fileSystem: fileSystem);
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
          await operation.rollback(fileSystem: fileSystem);
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
