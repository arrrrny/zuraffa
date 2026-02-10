enum PluginLifecycleStage { validate, beforeGenerate, afterGenerate, error }

class ValidationResult {
  final bool isValid;
  final String? message;
  final List<String> reasons;

  const ValidationResult._(this.isValid, this.message, this.reasons);

  factory ValidationResult.success([String? message]) {
    return ValidationResult._(true, message, const []);
  }

  factory ValidationResult.failure(List<String> reasons, [String? message]) {
    return ValidationResult._(false, message, List.unmodifiable(reasons));
  }

  ValidationResult merge(ValidationResult other) {
    final mergedReasons = <String>[...reasons, ...other.reasons];
    final mergedMessage = message ?? other.message;
    if (mergedReasons.isEmpty) {
      return ValidationResult.success(mergedMessage);
    }
    return ValidationResult.failure(mergedReasons, mergedMessage);
  }
}
