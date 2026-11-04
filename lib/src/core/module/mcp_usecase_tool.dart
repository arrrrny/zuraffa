// ============================================================
// McpUseCaseTool — declarative MCP registration for app usecases.
//
// The server-side registration seam of the zuraffa_mcp plugin
// (issue #2046): instead of hand-writing an [McpTool] subclass per
// feature, app code registers its existing `UseCase<T, Params>`
// instances with a name, a description, and an explicit
// readonly/mutating classification (the Vendure MCP plugin
// conventions, raptorr#380 — the fleet's MCP surfaces feel the
// same).
//
// Schemas come from the Zorphy seam: Zorphy entities/params already
// generate `fromJson`/`toJson`, so the adapter takes the params
// decoder (typically a tear-off like `GreetParams.fromJson`) and an
// [McpSchema] declaration of the same shape; the result side is
// round-tripped through the value's `toJson` when it has one.
//
// Security posture (issue #2046): nothing is auto-exposed. A tool
// only exists because app code registered it here, and mutating
// tools are the ones you did NOT mark `readonly: true`.
// ============================================================

import 'dart:convert';

import '../../domain/usecase.dart';
import 'mcp_tool.dart';

export 'mcp_tool.dart' show McpReadonlyAwareTool;

/// Minimal JSON-Schema (draft-07 subset) builder for MCP tool inputs.
///
/// The same declaration the params decoder consumes: keep the schema
/// and the `fromJson` factory in sync — the schema is what the MCP
/// client sees, the decoder is what actually runs.
abstract final class McpSchema {
  /// An object schema with [properties] and [required] keys.
  static Map<String, dynamic> object({
    Map<String, dynamic> properties = const {},
    List<String> required = const [],
    String? description,
  }) => {
    'type': 'object',
    'description': ?description,
    'properties': Map<String, dynamic>.of(properties),
    if (required.isNotEmpty) 'required': List<String>.of(required),
  };

  /// A string schema, optionally constrained to [enumValues].
  static Map<String, dynamic> string({
    String? description,
    List<String> enumValues = const [],
  }) => {
    'type': 'string',
    'description': ?description,
    if (enumValues.isNotEmpty) 'enum': List<String>.of(enumValues),
  };

  /// An integer schema.
  static Map<String, dynamic> integer({String? description}) => {
    'type': 'integer',
    'description': ?description,
  };

  /// A number schema.
  static Map<String, dynamic> number({String? description}) => {
    'type': 'number',
    'description': ?description,
  };

  /// A boolean schema.
  static Map<String, dynamic> boolean({String? description}) => {
    'type': 'boolean',
    'description': ?description,
  };

  /// An array schema over [items].
  static Map<String, dynamic> array({
    required Map<String, dynamic> items,
    String? description,
  }) => {
    'type': 'array',
    'description': ?description,
    'items': Map<String, dynamic>.of(items),
  };
}

/// An [McpTool] that adapts a Zuraffa `UseCase<T, Params>` for the
/// app's MCP surface (issue #2046).
///
/// ```dart
/// final engine = ZuraffaEngine()
///   ..register(
///     McpServerPlugin(
///       tools: [
///         McpUseCaseTool<Greeting, GreetParams>(
///           useCase: di.get<GreetUseCase>(),
///           name: 'greet',
///           description: 'Greets the named user.',
///           readonly: true, // reads only — omit for mutating tools
///           inputSchema: McpSchema.object(
///             properties: {'name': McpSchema.string()},
///             required: ['name'],
///           ),
///           decode: GreetParams.fromJson, // the Zorphy seam
///         ),
///       ],
///     ),
///   );
/// ```
///
/// `tools/call` decodes the JSON-RPC arguments through [decode],
/// runs the usecase, and folds the [Result]: a [Success] is encoded
/// through the value's `toJson` (when present) into the response
/// text; a [Failure] becomes an `isError` tool result carrying the
/// failure message.
class McpUseCaseTool<T extends Object?, P extends Object?>
    implements McpTool, McpReadonlyAwareTool {
  /// The app usecase this tool drives.
  final UseCase<T, P> useCase;

  @override
  final String name;

  @override
  final String description;

  @override
  final bool readonly;

  @override
  final Map<String, dynamic> inputSchema;

  /// Decodes the `tools/call` arguments into the usecase's params —
  /// typically a Zorphy-generated `Params.fromJson` tear-off.
  final P Function(Map<String, dynamic> arguments) decode;

  /// Encodes the success value into the tool result payload. When
  /// `null` (default), a `toJson` method is used when the value has
  /// one, falling back to `toString`.
  final Object? Function(T value)? encode;

  McpUseCaseTool({
    required this.useCase,
    required this.name,
    required this.description,
    this.readonly = false,
    this.inputSchema = const {'type': 'object', 'properties': {}},
    required this.decode,
    this.encode,
  });

  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    final P params;
    try {
      params = decode(arguments);
    } catch (e) {
      // The MCP client is untrusted: a malformed payload is a
      // tool-level error, never an exception across the boundary.
      return McpToolResult.error('Invalid arguments for tool "$name": $e');
    }
    try {
      final result = await useCase(params);
      return await result.fold((value) {
        final encoded = encode != null ? encode!(value) : _defaultEncode(value);
        if (encoded is Map<String, dynamic>) {
          return McpToolResult.ok(jsonEncode(encoded), data: encoded);
        }
        return McpToolResult.ok(encoded?.toString() ?? '');
      }, (failure) => McpToolResult.error(failure.toString()));
    } catch (e) {
      // UseCase.call already wraps execute failures in AppFailure; this
      // guards adapter-level surprises (e.g. a throwing custom encode).
      return McpToolResult.error(e.toString());
    }
  }

  /// Default result encoding: `toJson` when the value has one (the
  /// Zorphy seam), else `toString`.
  Object? _defaultEncode(T value) {
    try {
      final json = (value as dynamic).toJson();
      if (json is Map<String, dynamic>) return json;
    } on NoSuchMethodError {
      // No toJson — fall through to toString.
    }
    return value.toString();
  }
}
