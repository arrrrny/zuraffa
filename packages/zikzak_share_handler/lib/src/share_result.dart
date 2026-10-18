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

  @override
  String toString() =>
      'ShareResult($status${errorMessage == null ? '' : ': $errorMessage'})';
}
