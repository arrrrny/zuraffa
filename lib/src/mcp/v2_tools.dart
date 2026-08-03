// MCP Server 2.0 — New tool definitions and handlers.
//
// This file provides the v2.0 capability tools that get registered
// alongside the existing v5 tools in the MCP server.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zuraffa/src/mcp/auth.dart';
import 'package:zuraffa/src/mcp/capabilities/arch_capability.dart';
import 'package:zuraffa/src/mcp/capabilities/code_capability.dart';
import 'package:zuraffa/src/mcp/capabilities/test_capability.dart';
import 'package:zuraffa/src/mcp/capabilities/xray_capability.dart';
import 'package:zuraffa/src/mcp/file_watcher.dart';
import 'package:zuraffa/src/mcp/session_store.dart';

// ------------------------------------------------------------------
// Tool definitions
// ------------------------------------------------------------------

/// Returns v2.0 tool definitions for the tools/list response.
List<Map<String, dynamic>> v2ToolDefinitions() {
  return [
    _archInspectTool(),
    _archRefactorTool(),
    _testRunUseCaseTool(),
    _codeGenerateViewTool(),
    _graphqlPullSchemaTool(),
    _graphqlGenerateFromSchemaTool(),
    _xrayInspectTool(),
    _xrayTriggerActionTool(),
    _xrayTriggerMockTool(),
    _sessionSaveTool(),
    _sessionRestoreTool(),
  ];
}

Map<String, dynamic> _archInspectTool() {
  return {
    'name': 'arch_inspect',
    'description':
        'Returns the full architectural model of the project: entities, '
        'use cases, repositories, data sources, presentation layers, '
        'DI registrations, and routes. Use this to understand the '
        'project structure before making changes.',
    'inputSchema': {
      'type': 'object',
      'properties': {},
    },
  };
}

Map<String, dynamic> _archRefactorTool() {
  return {
    'name': 'arch_refactor',
    'description':
        'Perform a micro-refactoring on the project. Supports: '
        'rename-entity-field (renames a field across entity and all references), '
        'add-entity-method (adds a method to an entity class). '
        'Uses AST Smart Regeneration for safe merges.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'operation': {
          'type': 'string',
          'enum': ['rename-entity-field', 'add-entity-method'],
          'description': 'The refactoring operation to perform',
        },
        'entity': {
          'type': 'string',
          'description': 'Entity name in PascalCase (e.g. Product, Todo)',
        },
        'oldField': {
          'type': 'string',
          'description': 'Current field name (for rename-entity-field)',
        },
        'newField': {
          'type': 'string',
          'description': 'New field name (for rename-entity-field)',
        },
        'method': {
          'type': 'string',
          'description':
              'Dart method code to add (for add-entity-method). '
              'Include the full method signature and body.',
        },
      },
      'required': ['operation', 'entity'],
    },
  };
}

Map<String, dynamic> _testRunUseCaseTool() {
  return {
    'name': 'test_runUseCase',
    'description':
        'Run a specific UseCase in isolation with provided params. '
        'Finds the UseCase file, sets up the execution context, and '
        'returns the Result. Useful for verifying UseCase behavior '
        'without running the full app.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'useCase': {
          'type': 'string',
          'description': 'UseCase class name (e.g. GetProductUseCase)',
        },
        'params': {
          'type': 'object',
          'description': 'JSON object to pass as the UseCase params',
        },
        'mocks': {
          'type': 'object',
          'description':
              'Optional map of dependency class names to mock return values',
        },
      },
      'required': ['useCase'],
    },
  };
}

Map<String, dynamic> _codeGenerateViewTool() {
  return {
    'name': 'code_generateView',
    'description':
        'Generate a new view/controller/state trio for an entity. '
        'Uses the canonical v5 generation pipeline with AST Smart '
        'Regeneration, so existing user code in views is preserved.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'entity': {
          'type': 'string',
          'description': 'Entity name in PascalCase (e.g. Product, Todo)',
        },
        'methods': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Methods to generate (e.g. ["get", "getList", "create"]). Default: ["get", "getList"]',
        },
        'state': {
          'type': 'boolean',
          'description': 'Generate State class (default: true)',
        },
        'di': {
          'type': 'boolean',
          'description': 'Generate DI registration (default: false)',
        },
      },
      'required': ['entity'],
    },
  };
}

Map<String, dynamic> _graphqlPullSchemaTool() {
  return {
    'name': 'graphql_pullSchema',
    'description':
        'Introspect a GraphQL endpoint and return the schema as JSON. '
        'Returns types, queries, mutations, and subscriptions available.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'GraphQL endpoint URL',
        },
        'auth': {
          'type': 'string',
          'description': 'Bearer authentication token',
        },
      },
      'required': ['url'],
    },
  };
}

Map<String, dynamic> _graphqlGenerateFromSchemaTool() {
  return {
    'name': 'graphql_generateFromSchema',
    'description':
        'Introspect a GraphQL schema and generate entities, enums, '
        'and UseCases from it. Agent-driven alternative to the CLI.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'GraphQL endpoint URL',
        },
        'auth': {
          'type': 'string',
          'description': 'Bearer authentication token',
        },
        'entities': {
          'type': 'string',
          'description': 'Comma-separated list of entities to generate',
        },
        'methods': {
          'type': 'string',
          'description':
              'Comma-separated methods per entity (default: get,getList,create,update,delete)',
        },
      },
      'required': ['url'],
    },
  };
}

Map<String, dynamic> _xrayInspectTool() {
  return {
    'name': 'xray_inspect',
    'description':
        'Inspect the live X-Ray widget tree from a running Flutter app. '
        'Returns all registered X-Ray nodes with their IDs, types, '
        'bound actions, and state snapshots. Requires the app to be '
        'running with X-Ray bridge enabled (zfa xray bridge).',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'port': {
          'type': 'integer',
          'description': 'X-Ray bridge port (default: 8372)',
        },
      },
    },
  };
}

Map<String, dynamic> _xrayTriggerActionTool() {
  return {
    'name': 'xray_triggerAction',
    'description':
        'Trigger a bound action on an X-Ray node in the running app. '
        'Requires the app to be running with X-Ray bridge enabled.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'nodeId': {
          'type': 'string',
          'description': 'X-Ray node ID (from xray_inspect)',
        },
        'payload': {
          'type': 'object',
          'description': 'Optional payload to pass to the action',
        },
        'port': {
          'type': 'integer',
          'description': 'X-Ray bridge port (default: 8372)',
        },
      },
      'required': ['nodeId'],
    },
  };
}

Map<String, dynamic> _xrayTriggerMockTool() {
  return {
    'name': 'xray_triggerMock',
    'description':
        'Trigger a mock injection via the X-Ray Control Deck. '
        'Requires the app to be running with X-Ray bridge enabled.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'mockName': {
          'type': 'string',
          'description': 'Name of the mock to trigger',
        },
        'payload': {
          'type': 'object',
          'description': 'Optional payload for the mock',
        },
        'port': {
          'type': 'integer',
          'description': 'X-Ray bridge port (default: 8372)',
        },
      },
      'required': ['mockName'],
    },
  };
}

Map<String, dynamic> _sessionSaveTool() {
  return {
    'name': 'session_save',
    'description':
        'Save the current MCP session state for later restoration. '
        'Persists subscribed paths, last inspect results, etc.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'sessionId': {
          'type': 'string',
          'description': 'Unique session identifier',
        },
        'state': {
          'type': 'object',
          'description': 'Session state to persist (arbitrary JSON object)',
        },
      },
      'required': ['sessionId'],
    },
  };
}

Map<String, dynamic> _sessionRestoreTool() {
  return {
    'name': 'session_restore',
    'description': 'Restore a previously saved MCP session.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'sessionId': {
          'type': 'string',
          'description': 'Session identifier to restore',
        },
      },
      'required': ['sessionId'],
    },
  };
}

// ------------------------------------------------------------------
// Tool handler
// ------------------------------------------------------------------

/// Handles v2.0 tool calls. Returns a result map, or null if unhandled.
///
/// [projectRoot] is the absolute path to the project root.
/// Returns a map suitable for JSON-RPC result content.
Future<Map<String, dynamic>?> handleV2ToolCall({
  required String toolName,
  required Map<String, dynamic> args,
  required String projectRoot,
  McpSessionStore? sessionStore,
}) async {
  final inspector = ArchInspector(projectRoot: projectRoot);
  final codeCap = CodeCapability(projectRoot: projectRoot);
  final testCap = TestCapability(projectRoot: projectRoot);

  switch (toolName) {
    case 'arch_inspect':
      final model = await inspector.inspect();
      return {
        'content': [
          {'type': 'text', 'text': jsonEncode(model.toJson())},
        ],
      };

    case 'arch_refactor':
      final result = await inspector.refactor(
        operation: args['operation'] as String,
        args: args,
      );
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          },
        ],
        'isError': !(result['success'] as bool? ?? false),
      };

    case 'test_runUseCase':
      final result = await testCap.runUseCase(
        useCaseName: args['useCase'] as String,
        params: args['params'] as Map<String, dynamic>?,
        mocks: args['mocks'] as Map<String, dynamic>?,
      );
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          },
        ],
        'isError': !(result['success'] as bool? ?? false),
      };

    case 'code_generateView':
      final result = await codeCap.generateView(
        entityName: args['entity'] as String,
        methods: (args['methods'] as List?)?.map((e) => e.toString()).toList(),
        state: args['state'] as bool? ?? true,
        di: args['di'] as bool? ?? false,
      );
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          },
        ],
        'isError': !(result['success'] as bool? ?? false),
      };

    case 'graphql_pullSchema':
      return await _handleGraphqlPullSchema(args);

    case 'graphql_generateFromSchema':
      return await _handleGraphqlGenerateFromSchema(args, projectRoot);

    case 'xray_inspect':
      final port = args['port'] as int? ?? 8372;
      final xray = XrayCapability(port: port);
      final result = await xray.inspect();
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          },
        ],
        'isError': !(result['success'] as bool? ?? false),
      };

    case 'xray_triggerAction':
      final port = args['port'] as int? ?? 8372;
      final xray = XrayCapability(port: port);
      final result = await xray.triggerAction(
        nodeId: args['nodeId'] as String,
        payload: args['payload'] as Map<String, dynamic>?,
      );
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          },
        ],
        'isError': !(result['success'] as bool? ?? false),
      };

    case 'xray_triggerMock':
      final port = args['port'] as int? ?? 8372;
      final xray = XrayCapability(port: port);
      final result = await xray.triggerMock(
        mockName: args['mockName'] as String,
        payload: args['payload'],
      );
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          },
        ],
        'isError': !(result['success'] as bool? ?? false),
      };

    case 'session_save':
      if (sessionStore != null) {
        final sessionId = args['sessionId'] as String;
        final stateToSave = args['state'] as Map<String, dynamic>? ?? {};
        final session = await sessionStore.getOrCreate(sessionId);

        // Replace session state with supplied state
        session.state.clear();
        session.state.addAll(stateToSave);

        await sessionStore.save(session);
        return {
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({
                'success': true,
                'sessionId': sessionId,
                'message': 'Session saved',
              }),
            },
          ],
        };
      }
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode({
              'success': false,
              'message': 'Session persistence not available',
            }),
          },
        ],
        'isError': true,
      };

    case 'session_restore':
      if (sessionStore != null) {
        final sessionId = args['sessionId'] as String;
        final sessions = await sessionStore.listSessions();
        final exists = sessions.contains(sessionId);

        if (exists) {
          final session = await sessionStore.getOrCreate(sessionId);
          return {
            'content': [
              {
                'type': 'text',
                'text': jsonEncode({
                  'success': true,
                  'sessionId': sessionId,
                  'state': session.state,
                  'message': 'Session restored',
                }),
              },
            ],
          };
        } else {
          return {
            'content': [
              {
                'type': 'text',
                'text': jsonEncode({
                  'success': false,
                  'sessionId': sessionId,
                  'message': 'Session not found',
                }),
              },
            ],
            'isError': true,
          };
        }
      }
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode({
              'success': false,
              'message': 'Session persistence not available',
            }),
          },
        ],
        'isError': true,
      };

    default:
      return null; // Not a v2 tool
  }
}

// ------------------------------------------------------------------
// GraphQL handlers
// ------------------------------------------------------------------

Future<Map<String, dynamic>?> _handleGraphqlPullSchema(
  Map<String, dynamic> args,
) async {
  final url = args['url'] as String;
  final auth = args['auth'] as String?;

  // Validate URL scheme and host
  Uri parsedUrl;
  try {
    parsedUrl = Uri.parse(url);
  } catch (e) {
    return {
      'content': [
        {'type': 'text', 'text': 'Invalid URL: $e'},
      ],
      'isError': true,
    };
  }

  // Only allow http/https schemes
  if (parsedUrl.scheme != 'http' && parsedUrl.scheme != 'https') {
    return {
      'content': [
        {'type': 'text', 'text': 'Invalid URL scheme: only http and https are allowed'},
      ],
      'isError': true,
    };
  }

  // Reject loopback and link-local hosts unless explicitly allowed
  // (For now, we'll reject them to be safe - an operator opt-in config could be added)
  final host = parsedUrl.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1' ||
      host.startsWith('169.254.') || host.startsWith('fe80:')) {
    return {
      'content': [
        {'type': 'text', 'text': 'Loopback and link-local hosts are not allowed for GraphQL introspection'},
      ],
      'isError': true,
    };
  }

  const introspectionQuery = r'''
query IntrospectionQuery {
  __schema {
    types {
      name
      kind
      fields {
        name
        type { name kind ofType { name kind ofType { name } } }
        args { name type { name kind ofType { name } } }
      }
    }
    queryType { name }
    mutationType { name }
    subscriptionType { name }
  }
}
''';

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);

  try {
    final request = await client.postUrl(parsedUrl);
    request.headers.set('Content-Type', 'application/json');
    if (auth != null) {
      request.headers.set('Authorization', 'Bearer $auth');
    }
    request.write(jsonEncode({'query': introspectionQuery}));

    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return {
        'content': [
          {'type': 'text', 'text': jsonEncode(json['data'])},
        ],
      };
    } else {
      return {
        'content': [
          {
            'type': 'text',
            'text': 'GraphQL introspection failed: ${response.statusCode} - $body',
          },
        ],
        'isError': true,
      };
    }
  } on TimeoutException {
    return {
      'content': [
        {'type': 'text', 'text': 'GraphQL introspection timed out'},
      ],
      'isError': true,
    };
  } catch (e) {
    return {
      'content': [
        {'type': 'text', 'text': 'Error connecting to GraphQL endpoint: $e'},
      ],
      'isError': true,
    };
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>?> _handleGraphqlGenerateFromSchema(
  Map<String, dynamic> args,
  String projectRoot,
) async {
  final url = args['url'] as String;
  final auth = args['auth'] as String?;
  final entities = args['entities'] as String?;
  final methods = args['methods'] as String?;

  final cliArgs = ['graphql', '--url=$url'];
  if (auth != null) cliArgs.add('--auth=$auth');
  if (entities != null) cliArgs.add('--entities=$entities');
  if (methods != null) cliArgs.add('--methods=$methods');

  try {
    final result = await Process.run(
      'dart',
      ['run', 'zuraffa:zfa', ...cliArgs],
      workingDirectory: projectRoot,
    );

    final stdout = result.stdout.toString();
    final stderr = result.stderr.toString();

    return {
      'content': [
        {
          'type': 'text',
          'text': result.exitCode == 0 ? stdout : 'Error: $stderr\n$stdout',
        },
      ],
      'isError': result.exitCode != 0,
    };
  } catch (e) {
    return {
      'content': [
        {'type': 'text', 'text': 'Error running graphql command: $e'},
      ],
      'isError': true,
    };
  }
}

// ------------------------------------------------------------------
// WebSocket server
// ------------------------------------------------------------------

/// Starts a WebSocket-based MCP server.
///
/// Provides JSON-RPC over WebSocket with optional token authentication
/// and file change streaming.
Future<HttpServer> startWebSocketServer({
  required int port,
  required String projectRoot,
  String? authToken,
  McpSessionStore? sessionStore,
  McpFileWatcher? fileWatcher,
}) async {
  final auth = McpAuth(token: authToken);
  final sessions = <WebSocket, String>{};

  // Bind to localhost if auth is disabled, otherwise allow external connections
  final bindAddress = auth.isEnabled ? '0.0.0.0' : '127.0.0.1';
  final server = await HttpServer.bind(bindAddress, port);
  stderr.writeln('[mcp-ws] Listening on ws://$bindAddress:$port');

  fileWatcher ??= McpFileWatcher(projectRoot: projectRoot);
  await fileWatcher.start();

  // Broadcast file events to all connected clients
  fileWatcher.events.listen((event) {
    final notification = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'notifications/fileChanged',
      'params': event.toJson(),
    });
    for (final ws in sessions.keys) {
      try {
        ws.add(notification);
      } catch (_) {}
    }
  });

  server.listen((HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      // Validate connection info is available
      final connectionInfo = request.connectionInfo;
      if (connectionInfo == null) {
        request.response.statusCode = 400;
        request.response.write('Connection info unavailable');
        await request.response.close();
        return;
      }

      // Reject remote clients when auth is disabled
      if (!auth.isEnabled && !connectionInfo.remoteAddress.isLoopback) {
        request.response.statusCode = 403;
        request.response.write('Remote connections not allowed without authentication');
        await request.response.close();
        return;
      }

      // Validate auth for remote connections when enabled
      if (auth.isEnabled && !connectionInfo.remoteAddress.isLoopback) {
        final authHeader = request.headers.value('Authorization');
        if (!auth.validateHeader(authHeader)) {
          request.response.statusCode = 401;
          request.response.write('Unauthorized');
          await request.response.close();
          return;
        }
      }

      final ws = await WebSocketTransformer.upgrade(request);
      final remoteIp = connectionInfo.remoteAddress.address;
      sessions[ws] = remoteIp;
      stderr.writeln('[mcp-ws] Client connected from $remoteIp');

      ws.listen(
        (data) async {
          if (data is! String) return;
          try {
            final rpc = jsonDecode(data) as Map<String, dynamic>;

            final authError = auth.validateMessage(rpc, remoteIp);
            if (authError != null) {
              ws.add(jsonEncode({
                'jsonrpc': '2.0',
                'error': {'code': -32001, 'message': authError},
                'id': rpc['id'],
              }));
              return;
            }

            final method = rpc['method'] as String?;
            final id = rpc['id'];

            if (method == 'initialize') {
              ws.add(jsonEncode({
                'jsonrpc': '2.0',
                'result': {
                  'protocolVersion': '2024-11-05',
                  'capabilities': {
                    'tools': {'listChanged': true},
                    'resources': {'subscribe': true, 'listChanged': true},
                  },
                  'serverInfo': {
                    'name': 'zfa-mcp-server',
                    'version': '6.0.0',
                  },
                },
                'id': id,
              }));
              return;
            }

            if (method == 'tools/list') {
              ws.add(jsonEncode({
                'jsonrpc': '2.0',
                'result': {'tools': v2ToolDefinitions()},
                'id': id,
              }));
              return;
            }

            if (method == 'tools/call') {
              final params =
                  rpc['params'] as Map<String, dynamic>? ?? {};
              final toolName = params['name'] as String;
              final toolArgs =
                  params['arguments'] as Map<String, dynamic>? ?? {};

              final result = await handleV2ToolCall(
                toolName: toolName,
                args: toolArgs,
                projectRoot: projectRoot,
                sessionStore: sessionStore,
              );

              if (result != null) {
                ws.add(jsonEncode({
                  'jsonrpc': '2.0',
                  'result': result,
                  'id': id,
                }));
              } else {
                ws.add(jsonEncode({
                  'jsonrpc': '2.0',
                  'error': {
                    'code': -32602,
                    'message': 'Unknown tool: $toolName',
                  },
                  'id': id,
                }));
              }
              return;
            }

            if (id != null) {
              ws.add(jsonEncode({
                'jsonrpc': '2.0',
                'error': {'code': -32601, 'message': 'Method not found'},
                'id': id,
              }));
            }
          } catch (e) {
            stderr.writeln('[mcp-ws] Error: $e');
            try {
              ws.add(jsonEncode({
                'jsonrpc': '2.0',
                'error': {'code': -32603, 'message': '$e'},
                'id': null,
              }));
            } catch (_) {}
          }
        },
        onDone: () {
          sessions.remove(ws);
          stderr.writeln('[mcp-ws] Client disconnected');
        },
        onError: (e) {
          sessions.remove(ws);
          stderr.writeln('[mcp-ws] Error: $e');
        },
      );
    } else {
      if (request.method == 'GET' &&
          request.uri.path == '/health') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({'status': 'ok', 'transport': 'websocket'}))
          ..close();
        return;
      }
      request.response
        ..statusCode = 400
        ..write('Use WebSocket connection')
        ..close();
    }
  });

  return server;
}
