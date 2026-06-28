import 'sync_direction.dart';

/// Configuration for sync behavior.
///
/// Passed to [SyncStrategy] constructors to control batching, retry,
/// and backoff parameters. All values have sensible defaults.
class SyncConfig {
  /// Number of records to process per batch during sync.
  /// Prevents overwhelming the remote data source.
  final int batchSize;

  /// Maximum number of retry attempts before marking a record as failed.
  final int maxRetries;

  /// Base delay for exponential backoff (in milliseconds).
  /// Actual delay = min(backoffBaseMs * 2^retryCount, backoffMaxMs).
  final int backoffBaseMs;

  /// Maximum delay for exponential backoff (in milliseconds).
  final int backoffMaxMs;

  /// Sync direction: push-only or bidirectional.
  final SyncDirection direction;

  const SyncConfig({
    this.batchSize = 50,
    this.maxRetries = 5,
    this.backoffBaseMs = 1000,
    this.backoffMaxMs = 60000,
    this.direction = SyncDirection.push,
  });

  /// Calculate the backoff delay for a given retry count.
  ///
  /// Returns the delay in milliseconds.
  /// Formula: min(backoffBaseMs * 2^retryCount, backoffMaxMs)
  int backoffDelayFor(int retryCount) {
    final delay = backoffBaseMs * (1 << retryCount); // 2^retryCount
    return delay > backoffMaxMs ? backoffMaxMs : delay;
  }

  @override
  String toString() =>
      'SyncConfig(batchSize: $batchSize, maxRetries: $maxRetries, '
      'direction: $direction)';
}
