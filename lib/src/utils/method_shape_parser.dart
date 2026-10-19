/// Shared parser for per-member method shape tokens of the form
/// `name:params->returns` (issue #1850), with call-wide fallback handled
/// by callers.
class MethodShapeParser {
  static (String, String?, String?) parse(String token) =>
      parseMethodShape(token);

  static (String, String?, String?) parseMethodShape(String token) {
    final colon = token.indexOf(':');
    if (colon == -1) {
      final name = token.trim();
      if (name.isEmpty) {
        throw ArgumentError('method name must not be empty');
      }
      return (name, null, null);
    }
    var name = token.substring(0, colon).trim();
    if (name.isEmpty) {
      throw ArgumentError('method name must not be empty');
    }
    var shape = token.substring(colon + 1).trim();
    if (shape.startsWith("'") && shape.endsWith("'") && shape.length >= 2) {
      shape = shape.substring(1, shape.length - 1).trim();
    } else if (shape.startsWith('"') &&
        shape.endsWith('"') &&
        shape.length >= 2) {
      shape = shape.substring(1, shape.length - 1).trim();
    }
    String? params;
    String? returns;
    final arrow = shape.indexOf('->');
    if (arrow == -1) {
      params = shape.trim().isEmpty ? null : shape.trim();
    } else {
      final left = shape.substring(0, arrow).trim();
      final right = shape.substring(arrow + 2).trim();
      params = left.isEmpty ? null : left;
      returns = right.isEmpty ? null : right;
    }
    return (name, params, returns);
  }
}
