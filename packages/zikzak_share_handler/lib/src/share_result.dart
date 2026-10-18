/// Outcome of a share operation.
enum ShareStatus { success, cancelled, error }

class ShareResult {
  const ShareResult.success()
    : status = ShareStatus.success,
      errorMessage = null;
  const ShareResult.cancelled()
    : status = ShareStatus.cancelled,
      errorMessage = null;
  const ShareResult.error(this.errorMessage) : status = ShareStatus.error;

  final ShareStatus status;
  final String? errorMessage;

  bool get isSuccess => status == ShareStatus.success;
  bool get isCancelled => status == ShareStatus.cancelled;
  bool get isError => status == ShareStatus.error;

  ShareResult copyWith({ShareStatus? status, String? errorMessage}) {
    final nextStatus = status ?? this.status;
    switch (nextStatus) {
      case ShareStatus.success:
        return const ShareResult.success();
      case ShareStatus.cancelled:
        return const ShareResult.cancelled();
      case ShareStatus.error:
        return ShareResult.error(errorMessage ?? this.errorMessage);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareResult &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, errorMessage);

  @override
  String toString() =>
      'ShareResult($status${errorMessage == null ? '' : ': $errorMessage'})';
}
