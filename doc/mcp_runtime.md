# MCP Runtime

Zuraffa apps can expose their features to AI agents as **Model Context Protocol
(MCP)** tools. The runtime tier (`lib/src/core/module/mcp_*.dart`,
`lib/src/mcp/sse_server.dart`) is pure Dart — no Flutter, no codegen — and is the
foundation of ZikZak AI's agent architecture: every device tool and every
raptorr cloud tool serves through it.

## Serve modes

| Mode      | Class              | Transport        | Use when |
|-----------|--------------------|------------------|----------|
| **in-proc** | `LocalMcpHost`  | none (direct call) | The agent runtime lives in the same process (e.g. ZikZak AI's in-process bridge). No socket, no serialization. |
| **stdio**   | `McpStdioServer` | stdin/stdout JSON-RPC | The app is launched *as* an MCP server for a local agent (bin-only app). |
| **SSE**     | `McpSseServer`  | HTTP + Server-Sent Events | A remote agent connects over the network (debugging, cloud tools). Bearer-protected. |

Pick **in-proc** when the caller is colocated (lowest latency, no transport
errors). Pick **stdio** to hand the whole app to a local agent. Pick **SSE**
only when a remote agent must reach the device — and always set `authToken`.

## Defining a tool

```dart
class FetchUrlTool implements McpTool {
  @override String get name => 'fetch';
  @override String get description => 'Fetch the URL and return its body.';
  @override Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {'url': {'type': 'string'}},
    'required': ['url'],
  };
  @override Future<McpToolResult> call(Map<String, dynamic> args) async {
    // ... fetch and return ...
    return McpToolResult.ok(body);
  }
}
```

Register tools with `McpServerPlugin` and let the engine bootstrap them:

```dart
final engine = ZuraffaEngine()
  ..register(McpServerPlugin(tools: myMcpTools));
await engine.bootstrap();
```

## In-process bridge (no transport)

`McpToolRegistry.call` and `LocalMcpHost` provide the transport-free surface —
the server-side half of the in-process bridge. The client half
(`LocalMcpTransport`) lives in `arrrrny/dart_agent_core` (#2) and talks to the
`LocalMcpHost` interface. Once that interface lands, `LocalMcpHost` should
`implements` it so the two halves line up.

```dart
final host = LocalMcpHost(registry);
final result = await host.callTool('fetch', {'url': 'https://example.com'});
```

## Large results: the `artifactRef` ref-only pattern

Never marshal a multi-MB body through a transport. Return a short summary plus
an out-of-band pointer (`artifactRef`) that the client resolves itself:

```dart
return McpToolResult.artifact(
  'sha256:ab12…/screenshot.png', // ref-only; body stays out of band
  text: 'captured screenshot',
);
```

The wire response carries only `'artifactRef'` (not the body). For small
results, `McpToolResult.ok(text, data: {...})` is enough; `data` is for
in-process/debug use and is never serialized.

## SSE hardening

`McpSseServer` enforces:

- **Bearer auth** — set `authToken`; remote clients must present
  `Authorization: Bearer <token>`. Loopback clients are always allowed.
- **Per-token tool allowlists** — pass `toolAllowlist`
  (`{token: {allowedToolNames}}`) so a token can only invoke its listed tools.
  A denied `tools/call` returns a JSON-RPC `-32000` "not permitted" error.
- **Connection limit** — pass `maxConnections`; new SSE streams beyond the cap
  are rejected with HTTP 503.
- **DNS-rebinding protection** — Origin/Host validation in unauthenticated mode.
- **Graceful shutdown** — `stop()` closes SSE streams and stops listening
  without force-dropping in-flight requests.

```dart
final server = McpSseServer(
  registry: registry,
  authToken: 'secret',
  maxConnections: 1000,
  toolAllowlist: {'viewer-token': {'fetch', 'echo'}},
);
await server.start(port: 8372);
```

## Lifecycle

`McpServerPlugin` registers tools during `registerDependencies` and joins the
engine lifecycle via `onInit`. Tools can be registered/unregistered at runtime
through `registry.register(...)` / `registry.unregister(name)` without restart.
