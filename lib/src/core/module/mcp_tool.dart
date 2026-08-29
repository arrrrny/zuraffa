// ============================================================
// McpTool — runtime MCP tool contract for Zuraffa apps.
//
// A Zuraffa-developed app that wants to expose its features as
// Model Context Protocol (MCP) tools declares one [McpTool] per
// feature (e.g. `fetch`, `printPdf`, `takeScreenshot`). Each tool
// has a stable [name], an AI-facing [description], a JSON-Schema
// [inputSchema] for its arguments, and an async [call] handler
// that returns an [McpToolResult].
//
// Tools are registered with an [McpToolRegistry] (typically via
// [McpServerPlugin.registerDependencies]) and resolved by name
// when a JSON-RPC `tools/call` request arrives over the stdio or
// SSE transport.
//
// This is the RUNTIME tier — pure Dart, no Flutter, no codegen.
// It is distinct from the codegen-side [ZuraffaCapability]
// (lib/src/core/plugin_system/capability.dart) which models the
// CLI/codegen capabilities and returns [ExecutionResult] /
// [EffectReport] for plan-execute flows.
// ============================================================

/// Result returned by an [McpTool.call] invocation.
///
/// Mirrors the MCP `tools/call` response shape: an `isError` flag
/// plus a list of `content` blocks. The current contract emits a
/// single text content block (the most common case); richer tools
/// can override [McpToolResult.toJson] to emit additional content
/// types (image, resource, embedded).
///
/// Large results use the ref-only [artifactRef] pattern: set
/// [artifactRef] (e.g. via [McpToolResult.artifact]) so the wire
/// response carries only a pointer to the body, never the body itself
/// (zuraffa#384, requirement #5).
class McpToolResult {
  /// Whether the call ended in a tool-level error (vs. a transport
  /// error). When `true`, the MCP client surfaces the [text] as an
  /// error to the model.
  final bool isError;

  /// The primary text payload returned to the caller.
  final String text;

  /// Optional structured data forwarded alongside the text content.
  /// Not part of the wire-level MCP `tools/call` response — the
  /// runtime server uses this for in-process tests and richer
  /// debugging output.
  final Map<String, dynamic>? data;

  /// Ref-only pointer to a large result body stored out-of-band (a
  /// file path, content-addressed URI, or object-store key).
  ///
  /// Implements the "artifactRef" ref-only pattern from the MCP runtime
  /// productionization (zuraffa#384, requirement #5). When set, [text]
  /// should be a short summary and the large body MUST NOT be marshaled
  /// through the transport — the client resolves [artifactRef] out-of-band.
  /// The wire response carries only the ref, never the body, so multi-MB
  /// results never cross the JSON-RPC boundary.
  final String? artifactRef;

  const McpToolResult({
    this.isError = false,
    required this.text,
    this.data,
    this.artifactRef,
  });

  /// Convenience constructor for an error result.
  factory McpToolResult.error(
    String message, {
    Map<String, dynamic>? data,
    String? artifactRef,
  }) => McpToolResult(
    isError: true,
    text: message,
    data: data,
    artifactRef: artifactRef,
  );

  /// Convenience constructor for a success result with structured data.
  factory McpToolResult.ok(
    String text, {
    Map<String, dynamic>? data,
    String? artifactRef,
  }) => McpToolResult(text: text, data: data, artifactRef: artifactRef);

  /// Ref-only result: the large body lives at [artifactRef]; [text] is a
  /// short human-readable summary. The wire response carries only the ref.
  factory McpToolResult.artifact(
    String artifactRef, {
    String text = '',
    Map<String, dynamic>? data,
  }) => McpToolResult(text: text, data: data, artifactRef: artifactRef);

  /// Serialises to the MCP `tools/call` result shape:
  ///
  /// ```json
  /// {
  ///   "isError": false,
  ///   "content": [{"type": "text", "text": "..."}],
  ///   "artifactRef": "sha256:ab12.../screenshot.png"
  /// }
  /// ```
  ///
  /// Note: [data] is deliberately NOT serialised — it exists for
  /// in-process runtime and test use only. When [artifactRef] is set, it
  /// IS serialised (the ref, not the body) so the client can fetch the
  /// large result out-of-band. The wire response emits exactly the MCP
  /// 2024-11-05 result fields plus the optional `artifactRef`.
  Map<String, dynamic> toJson() => {
    if (isError) 'isError': true,
    'content': [
      {'type': 'text', 'text': text},
    ],
    if (artifactRef != null) 'artifactRef': artifactRef,
  };

  @override
  String toString() =>
      isError ? 'McpToolResult(error: $text)' : 'McpToolResult($text)';
}

/// A runtime MCP tool exposed by a Zuraffa app.
///
/// Subclass (or anonymously implement) this contract for each
/// app feature you want callable by an AI agent:
///
/// ```dart
/// class FetchUrlTool implements McpTool {
///   @override
///   String get name => 'fetch';
///   @override
///   String get description => 'Fetch the URL and return its body.';
///   @override
///   Map<String, dynamic> get inputSchema => {
///     'type': 'object',
///     'properties': {'url': {'type': 'string', 'description': 'HTTP(S) URL'}},
///     'required': ['url'],
///   };
///   @override
///   Future<McpToolResult> call(Map<String, dynamic> args) async {
///     final url = args['url'] as String;
///     final client = HttpClient();
///     final req = await client.getUrl(Uri.parse(url));
///     final res = await req.close();
///     final body = await res.transform(utf8.decoder).join();
///     return McpToolResult.ok(body);
///   }
/// }
/// ```
///
/// Then register the tool with [McpServerPlugin]:
///
/// ```dart
/// final engine = ZuraffaEngine()
///   ..register(McpServerPlugin(tools: [FetchUrlTool()]));
/// await engine.bootstrap();
/// ```
abstract class McpTool {
  /// Stable, unique tool name (snake_case). Used by the MCP client
  /// to invoke this tool via `tools/call`.
  String get name;

  /// Human/AI-facing description. Should explain what the tool does,
  /// what its arguments mean, and what it returns.
  String get description;

  /// JSON Schema (draft-07 subset) describing the [call] arguments.
  /// The runtime server forwards this verbatim to the MCP client in
  /// the `tools/list` response.
  Map<String, dynamic> get inputSchema;

  /// Invokes the tool with the named [arguments] from a `tools/call`
  /// request. Implementations should validate inputs defensively
  /// (the MCP client is untrusted) and return an [McpToolResult] —
  /// never throw across the JSON-RPC boundary.
  Future<McpToolResult> call(Map<String, dynamic> arguments);
}
