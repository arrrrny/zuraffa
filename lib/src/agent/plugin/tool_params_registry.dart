/// Registry that lets host apps teach generated MCP tool wrappers how to
/// turn a raw JSON wire map into the typed params class their usecase
/// expects (zuraffa#2061).
///
/// Generated wrappers receive tool arguments as `Map<String, dynamic>`.
/// UseCases whose params are a typed class (e.g. a zfa value class) crash
/// on a raw pass-through, because `UseCase.call(params)` is typed. Hosts
/// register a `fromWire` factory per params type; the emitted wrapper
/// consults [coerce] before falling back to passing the raw map through.
library;

/// Builds a typed params object from the raw wire map of tool arguments.
typedef ToolParamsFromWire = Object Function(Map<String, dynamic> wire);

class ToolParamsRegistry {
  ToolParamsRegistry._();

  /// Per-params-type factories, keyed by the params class name as it
  /// appears in `UseCase<Output, Params>` (the wrapper's paramsType).
  static final Map<String, ToolParamsFromWire> fromWire = {};

  /// Returns the coerced params object for [paramsType], or `null` when no
  /// factory is registered (callers should then pass the raw map through).
  static Object? coerce(String paramsType, Map<String, dynamic> wire) {
    final factory = fromWire[paramsType];
    if (factory == null) return null;
    return factory(wire);
  }
}
