import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zuraffa/src/zfa_cli.dart' as zfa show version;

/// MCP Server for Zuraffa CLI
///
/// This server implements the Model Context Protocol to expose
/// zfa CLI functionality as MCP tools.
///
/// Run with: dart run zuraffa:zuraffa_mcp_server
void main(List<String> args) async {
  // Check for flags passed to the server process itself
  final useZorphyByDefault =
      args.contains('--zorphy') || args.contains('--always-zorphy');

  final server = ZuraffaMcpServer(useZorphyByDefault: useZorphyByDefault);
  await server.run();
}

class ZuraffaMcpServer {
  final bool useZorphyByDefault;

  ZuraffaMcpServer({this.useZorphyByDefault = false});

  // Cache for resource listings to avoid repeated filesystem scans
  List<Map<String, dynamic>>? _resourcesCache;
  DateTime? _resourcesCacheTime;
  static const _cacheDuration = Duration(minutes: 10);

  // Maximum files to return to prevent large responses
  static const _maxFiles = 100;

  /// Main server loop that handles JSON-RPC messages
  Future<void> run() async {
    // Enable stdin line reading
    // These settings may fail in non-TTY contexts (like when stdin is piped)
    try {
      stdin.echoMode = false;
    } catch (_) {
      // Ignore errors in piped context
    }
    try {
      stdin.lineMode = true;
    } catch (_) {
      // Ignore errors in piped context
    }

    if (useZorphyByDefault) {
      stderr.writeln('Spawned with default Zorphy mode enabled');
    }

    // Set up the stream first to ensure it's ready
    final stream = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Keep the process alive indefinitely
    // Use a completer that never completes to prevent exit
    final keepAlive = Completer<void>();

    // Start processing messages IMMEDIATELY before any delays
    // This ensures we don't miss any early messages from Zed
    _processStream(stream).catchError((e) {
      stderr.writeln('Message processor error: $e');
      // Don't exit - keep the process alive
    });

    // Wait forever - this keeps the process alive even if stdin closes
    await keepAlive.future;
  }

  /// Process stdin messages from the provided stream
  Future<void> _processStream(Stream<String> stream) async {
    final completer = Completer<void>();

    // Use subscription instead of await-for to prevent early exit
    stream.listen(
      (line) async {
        if (line.isEmpty) return;

        try {
          final request = jsonDecode(line) as Map<String, dynamic>;
          final response = await handleRequest(request);
          // Only send response if it's not a notification (notifications have id == null)
          if (response != null) {
            stdout.writeln(jsonEncode(response));
          }
        } catch (e, stackTrace) {
          stderr.writeln('Error processing request: $e\n$stackTrace');
          final errorResponse = {
            'jsonrpc': '2.0',
            'error': {
              'code': -32603,
              'message': 'Internal error: ${e.toString()}',
            },
            'id': null,
          };
          stdout.writeln(jsonEncode(errorResponse));
        }
      },
      onError: (e) {
        stderr.writeln('Stream error: $e');
        // Don't complete - keep listening
      },
      onDone: () {
        // Stdin closed - but don't log anything to avoid confusing Zed
        // Just keep the process alive silently
        // Don't complete the completer - process stays alive forever
      },
      cancelOnError: false,
    );

    // Wait forever - never complete this future
    await completer.future;
  }

  /// Handle incoming JSON-RPC requests
  Future<Map<String, dynamic>?> handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'] as String?;
    final id = request['id'];

    switch (method) {
      case 'initialize':
        return _initialize(id);
      case 'tools/list':
        return _listTools(id);
      case 'tools/call':
        return await _callTool(
          id,
          request['params'] as Map<String, dynamic>? ?? {},
        );
      case 'resources/list':
        return await _listResources(id);
      case 'resources/read':
        return await _readResource(
          id,
          request['params'] as Map<String, dynamic>? ?? {},
        );
      case 'shutdown':
        // Graceful shutdown
        return _success(id, {});
      case 'ping':
        return _success(id, {'pong': true});
      default:
        // Don't respond to unknown notifications (id == null)
        if (id == null) {
          return null;
        }
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  /// Handle initialize request
  Map<String, dynamic> _initialize(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'result': {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {'listChanged': true},
          'resources': {'subscribe': true, 'listChanged': true},
        },
        'serverInfo': {'name': 'zfa-mcp-server', 'version': zfa.version},
      },
      'id': id,
    };
  }

  /// List available tools
  Map<String, dynamic> _listTools(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'result': {
        'tools': [
          _generateToolDefinition(),
          _schemaToolDefinition(),
          _validateToolDefinition(),
          _entityCreateToolDefinition(),
          _entityEnumToolDefinition(),
          _entityAddFieldToolDefinition(),
          _entityFromJsonToolDefinition(),
          _entityListToolDefinition(),
          _configInitToolDefinition(),
          _configShowToolDefinition(),
          _configSetToolDefinition(),
          _graphqlToolDefinition(),
        ],
      },
      'id': id,
    };
  }

  /// Generate tool definition
  Map<String, dynamic> _generateToolDefinition() {
    return {
      'name': 'generate',
      'description':
          'Generate Clean Architecture code for Flutter projects including UseCases, Repositories, Views, Presenters, Controllers, State objects, and Data layers. Use --state with --vpc for automatic state management, or --vpc alone for custom controller implementation.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Entity or UseCase name in PascalCase (e.g., Product, ProcessOrder)',
          },
          'methods': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': [
                'get',
                'getList',
                'create',
                'update',
                'delete',
                'watch',
                'watchList',
              ],
            },
            'description': 'Methods to generate for entity-based UseCases',
          },
          'vpc': {
            'type': 'boolean',
            'description':
                'Generate View, Presenter, and Controller (presentation layer)',
          },
          'pc': {
            'type': 'boolean',
            'description':
                'Generate Presenter and Controller only (preserve custom View)',
          },
          'pcs': {
            'type': 'boolean',
            'description':
                'Generate Presenter, Controller, and State (preserve custom View)',
          },
          'state': {
            'type': 'boolean',
            'description':
                'Generate State object with granular loading states (isGetting, isCreating, etc.). When enabled with --vpc, the Controller will use StatefulController mixin and automatically update state. When disabled, Controller methods are generated with empty handlers for custom implementation.',
          },
          'data': {
            'type': 'boolean',
            'description':
                'Generate data layer (DataRepository + DataSource, always includes remote datasource)',
          },
          'datasource': {
            'type': 'boolean',
            'description': 'Generate DataSource only',
          },
          'init': {
            'type': 'boolean',
            'description':
                'Generate initialize method for repository and datasource',
          },
          'id_field': {
            'type': 'string',
            'description': 'ID field name (default: id)',
          },
          'id_field_type': {
            'type': 'string',
            'description':
                'ID field type - ONLY include if user explicitly specifies (default: String)',
          },
          'query_field': {
            'type': 'string',
            'description': 'Query field name for get/watch (default: id)',
          },
          'query_field_type': {
            'type': 'string',
            'description':
                'Query field type - ONLY include if user explicitly specifies (default: matches id_field_type)',
          },
          'zorphy': {
            'type': 'boolean',
            'description': 'Use Zorphy-style typed patches',
          },
          'gql': {
            'type': 'boolean',
            'description': 'Generate GraphQL query/mutation/subscription files',
          },
          'gql_type': {
            'type': 'string',
            'enum': ['query', 'mutation', 'subscription'],
            'description':
                'GraphQL operation type - auto-detected for entity methods (get/getList=query, create/update/delete=mutation, watch/watchList=subscription)',
          },
          'gql_returns': {
            'type': 'string',
            'description':
                'GraphQL return fields as comma-separated string (e.g., "id,name,price,category")',
          },
          'gql_input_type': {
            'type': 'string',
            'description': 'GraphQL input type name for mutation/subscription',
          },
          'gql_input_name': {
            'type': 'string',
            'description': 'GraphQL input variable name (default: input)',
          },
          'gql_name': {
            'type': 'string',
            'description':
                'Custom GraphQL operation name (default: auto-generated)',
          },
          'repo': {
            'type': 'string',
            'description':
                'Repository to inject (for custom UseCases) - enforces Single Responsibility Principle',
          },
          'service': {
            'type': 'string',
            'description':
                'Service to inject (alternative to repo for custom UseCases) - generates service interface',
          },
          'usecases': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'UseCases to compose (for orchestrator pattern) - comma-separated list',
          },
          'variants': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Variants for polymorphic pattern (e.g., Barcode,Url,Text) - generates abstract + variants + factory',
          },
          'domain': {
            'type': 'string',
            'description':
                'Domain folder for custom UseCases (required for custom UseCases)',
          },
          'method': {
            'type': 'string',
            'description':
                'Dependency method name (default: auto-generated from UseCase name)',
          },
          'service_method': {
            'type': 'string',
            'description':
                'Service method name (default: auto-generated from UseCase name)',
          },
          'append': {
            'type': 'boolean',
            'description':
                'Append method to existing repository/datasource files without regenerating',
          },
          'params': {
            'type': 'string',
            'description':
                'Params type for custom UseCase - ONLY include if user explicitly specifies (default: NoParams)',
          },
          'returns': {
            'type': 'string',
            'description':
                'Return type for custom UseCase - ONLY include if user explicitly specifies (default: void)',
          },
          'type': {
            'type': 'string',
            'enum': ['usecase', 'stream', 'background', 'completable', 'sync'],
            'description': 'UseCase type for custom UseCases',
          },
          'output': {
            'type': 'string',
            'description':
                'Output directory - ONLY include if user explicitly specifies a custom path. Do NOT guess or include default value.',
          },
          'dry_run': {
            'type': 'boolean',
            'description': 'Preview without writing files',
          },
          'force': {
            'type': 'boolean',
            'description': 'Overwrite existing files',
          },
          'verbose': {
            'type': 'boolean',
            'description': 'Enable verbose output',
          },
          'test': {
            'type': 'boolean',
            'description': 'Generate unit tests for generated UseCases',
          },
          'cache': {
            'type': 'boolean',
            'description':
                'Enable caching with dual datasources (remote + local)',
          },
          'cache_policy': {
            'type': 'string',
            'enum': ['daily', 'restart', 'ttl'],
            'description':
                'Cache policy: daily (default), restart (app session only), ttl (time-based)',
          },
          'cache_storage': {
            'type': 'string',
            'enum': ['hive', 'sqlite', 'shared_preferences'],
            'description': 'Local storage implementation hint for caching',
          },
          'mock': {
            'type': 'boolean',
            'description': 'Generate mock data files alongside other layers',
          },
          'mock_data_only': {
            'type': 'boolean',
            'description': 'Generate only mock data files (no other layers)',
          },
          'use_mock': {
            'type': 'boolean',
            'description':
                'Use mock datasource in DI registration (default: remote datasource)',
          },
          'di': {
            'type': 'boolean',
            'description': 'Generate dependency injection files using get_it',
          },
        },
        'required': ['name'],
      },
    };
  }

  /// Schema tool definition
  Map<String, dynamic> _schemaToolDefinition() {
    return {
      'name': 'schema',
      'description':
          'Get the JSON schema for ZFA configuration validation. Useful for AI agents to validate configs before generation.',
      'inputSchema': {'type': 'object', 'properties': {}},
    };
  }

  /// Validate tool definition
  Map<String, dynamic> _validateToolDefinition() {
    return {
      'name': 'validate',
      'description':
          'Validate a JSON configuration file against the ZFA schema',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'config': {
            'type': 'object',
            'description': 'The configuration object to validate',
          },
        },
        'required': ['config'],
      },
    };
  }

  /// Handle tool calls
  Future<Map<String, dynamic>> _callTool(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final toolName = params['name'] as String;
    final args = params['arguments'] as Map<String, dynamic>? ?? {};

    try {
      String result;

      switch (toolName) {
        case 'generate':
          result = await _runGenerateCommand(args);
          break;
        case 'schema':
          result = await _runSchemaCommand();
          break;
        case 'validate':
          result = await _runValidateCommand(args);
          break;
        case 'entity_create':
          result = await _runEntityCreateCommand(args);
          break;
        case 'entity_enum':
          result = await _runEntityEnumCommand(args);
          break;
        case 'entity_add_field':
          result = await _runEntityAddFieldCommand(args);
          break;
        case 'entity_from_json':
          result = await _runEntityFromJsonCommand(args);
          break;
        case 'entity_list':
          result = await _runEntityListCommand(args);
          break;
        case 'config_init':
          result = await _runConfigCommand(['init', ...?_configArgs(args)]);
          break;
        case 'config_show':
          result = await _runConfigCommand(['show']);
          break;
        case 'config_set':
          result = await _runConfigCommand([
            'set',
            args['key'] as String,
            args['value'].toString(),
          ]);
          break;
        case 'graphql':
          result = await _runGraphqlCommand(args);
          break;
        default:
          return _error(id, -32602, 'Unknown tool: $toolName');
      }

      return {
        'jsonrpc': '2.0',
        'result': {
          'content': [
            {'type': 'text', 'text': result},
          ],
        },
        'id': id,
      };
    } catch (e, stackTrace) {
      return {
        'jsonrpc': '2.0',
        'result': {
          'content': [
            {
              'type': 'text',
              'text':
                  'Error: ${e.toString()}\n\nStack trace:\n${stackTrace.toString()}',
            },
          ],
          'isError': true,
        },
        'id': id,
      };
    }
  }

  /// Run entity create command
  Future<String> _runEntityCreateCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = ['entity', 'create', '--name=${args["name"]}'];

    if (args['output'] != null) cliArgs.add('--output=${args["output"]}');
    if (args['json'] == true) cliArgs.add('--json');
    if (args['json'] == false) cliArgs.add('--no-json');
    if (args['sealed'] == true) cliArgs.add('--sealed');
    if (args['non_sealed'] == true) cliArgs.add('--non-sealed');
    if (args['copywith_fn'] == true) cliArgs.add('--copywith-fn');
    if (args['compare'] == true) cliArgs.add('--compare');
    if (args['compare'] == false) cliArgs.add('--no-compare');
    if (args['extends'] != null) cliArgs.add('--extends=${args["extends"]}');

    if (args['fields'] != null) {
      final fields = args['fields'] as List;
      for (final field in fields) {
        cliArgs.add('--field=$field');
      }
    }

    if (args['subtype'] != null) {
      final subtypes = args['subtype'] as List;
      for (final subtype in subtypes) {
        cliArgs.add('--subtype=$subtype');
      }
    }

    return await _runZuraffaProcess(cliArgs);
  }

  /// Run entity enum command
  Future<String> _runEntityEnumCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = ['entity', 'enum', '--name=${args["name"]}'];

    if (args['output'] != null) cliArgs.add('--output=${args["output"]}');

    if (args['values'] != null) {
      final values = args['values'] as List;
      cliArgs.add('--value=${values.join(',')}');
    }

    return await _runZuraffaProcess(cliArgs);
  }

  /// Run entity add-field command
  Future<String> _runEntityAddFieldCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = [
      'entity',
      'add-field',
      '--name=${args["name"]}',
    ];

    if (args['output'] != null) cliArgs.add('--output=${args["output"]}');

    if (args['fields'] != null) {
      final fields = args['fields'] as List;
      for (final field in fields) {
        cliArgs.add('--field=$field');
      }
    }

    return await _runZuraffaProcess(cliArgs);
  }

  /// Run entity from-json command
  Future<String> _runEntityFromJsonCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = [
      'entity',
      'from-json',
      args['file'] as String,
    ];

    if (args['name'] != null) cliArgs.add('--name=${args["name"]}');
    if (args['output'] != null) cliArgs.add('--output=${args["output"]}');
    if (args['json'] == true) cliArgs.add('--json');
    if (args['json'] == false) cliArgs.add('--no-json');
    if (args['prefix_nested'] == true) cliArgs.add('--prefix-nested');
    if (args['prefix_nested'] == false) cliArgs.add('--no-prefix-nested');

    return await _runZuraffaProcess(cliArgs);
  }

  /// Run entity list command
  Future<String> _runEntityListCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = ['entity', 'list'];

    if (args['output'] != null) cliArgs.add('--output=${args["output"]}');

    return await _runZuraffaProcess(cliArgs);
  }

  /// Entity Create tool definition
  Map<String, dynamic> _entityCreateToolDefinition() {
    return {
      'name': 'entity_create',
      'description':
          'Create a new Zorphy entity with fields. Supports JSON serialization, sealed classes, inheritance, and all Zorphy features.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Entity name in PascalCase (e.g., User, Product)',
          },
          'output': {
            'type': 'string',
            'description':
                'Output directory (default: lib/src/domain/entities)',
          },
          'fields': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Fields in format "name:type" or "name:type?" for nullable',
          },
          'json': {
            'type': 'boolean',
            'description': 'Enable JSON serialization',
          },
          'sealed': {'type': 'boolean', 'description': 'Create sealed class'},
          'non_sealed': {
            'type': 'boolean',
            'description': 'Create non-sealed class',
          },
          'copywith_fn': {
            'type': 'boolean',
            'description': 'Function-based copyWith',
          },
          'compare': {'type': 'boolean', 'description': 'Enable compareTo'},
          'extends': {'type': 'string', 'description': 'Interface to extend'},
          'subtype': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Explicit subtypes',
          },
        },
        'required': ['name'],
      },
    };
  }

  /// Entity Enum tool definition
  Map<String, dynamic> _entityEnumToolDefinition() {
    return {
      'name': 'entity_enum',
      'description': 'Create a new enum in the entities/enums directory',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Enum name in PascalCase'},
          'output': {'type': 'string', 'description': 'Output base directory'},
          'values': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Enum values',
          },
        },
        'required': ['name', 'values'],
      },
    };
  }

  /// Entity Add-Field tool definition
  Map<String, dynamic> _entityAddFieldToolDefinition() {
    return {
      'name': 'entity_add_field',
      'description': 'Add field(s) to an existing Zorphy entity',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Entity name'},
          'output': {'type': 'string', 'description': 'Output base directory'},
          'fields': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Fields to add in format "name:type"',
          },
        },
        'required': ['name', 'fields'],
      },
    };
  }

  /// Entity From-JSON tool definition
  Map<String, dynamic> _entityFromJsonToolDefinition() {
    return {
      'name': 'entity_from_json',
      'description': 'Create Zorphy entity/ies from a JSON file',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'file': {'type': 'string', 'description': 'Path to JSON file'},
          'name': {'type': 'string', 'description': 'Entity name'},
          'output': {'type': 'string', 'description': 'Output base directory'},
          'json': {
            'type': 'boolean',
            'description': 'Enable JSON serialization',
          },
          'prefix_nested': {
            'type': 'boolean',
            'description': 'Prefix nested entities',
          },
        },
        'required': ['file'],
      },
    };
  }

  /// Entity List tool definition
  Map<String, dynamic> _entityListToolDefinition() {
    return {
      'name': 'entity_list',
      'description': 'List all Zorphy entities and enums',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'output': {'type': 'string', 'description': 'Directory to search'},
        },
      },
    };
  }

  /// Config Init tool definition
  Map<String, dynamic> _configInitToolDefinition() {
    return {
      'name': 'config_init',
      'description':
          'Initialize ZFA configuration file (.zfa.json) with default settings for entity generation, GraphQL, caching, and more.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'Project root directory (default: current directory)',
          },
        },
      },
    };
  }

  /// Config Show tool definition
  Map<String, dynamic> _configShowToolDefinition() {
    return {
      'name': 'config_show',
      'description': 'Show current ZFA configuration settings from .zfa.json',
      'inputSchema': {'type': 'object', 'properties': {}},
    };
  }

  /// Config Set tool definition
  Map<String, dynamic> _configSetToolDefinition() {
    return {
      'name': 'config_set',
      'description':
          'Update a ZFA configuration value in .zfa.json. Valid keys: zorphyByDefault, jsonByDefault, compareByDefault, filterByDefault, defaultEntityOutput, gqlByDefault, buildByDefault, appendByDefault, routeByDefault, diByDefault.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description': 'Configuration key to set',
            'enum': [
              'zorphyByDefault',
              'jsonByDefault',
              'compareByDefault',
              'filterByDefault',
              'defaultEntityOutput',
              'gqlByDefault',
              'buildByDefault',
              'appendByDefault',
              'routeByDefault',
              'diByDefault',
            ],
          },
          'value': {
            'description': 'Value to set (boolean for flags, string for paths)',
          },
        },
        'required': ['key', 'value'],
      },
    };
  }

  /// GraphQL tool definition
  Map<String, dynamic> _graphqlToolDefinition() {
    return {
      'name': 'graphql',
      'description':
          'Introspect a GraphQL schema and generate Zorphy entities, enums, and UseCases. Can generate complete Clean Architecture layers from a GraphQL endpoint.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'GraphQL endpoint URL (required)',
          },
          'auth': {
            'type': 'string',
            'description': 'Bearer authentication token',
          },
          'output': {
            'type': 'string',
            'description': 'Output directory (default: lib/src)',
          },
          'methods': {
            'type': 'string',
            'description':
                'CRUD methods to generate, comma-separated (default: get,getList,create,update,delete)',
          },
          'entities': {
            'type': 'string',
            'description': 'Entities to generate, comma-separated',
          },
          'queries': {
            'type': 'string',
            'description':
                'Specific GraphQL queries to import as UseCases, comma-separated',
          },
          'mutations': {
            'type': 'string',
            'description':
                'Specific GraphQL mutations to import as UseCases, comma-separated',
          },
          'domain': {
            'type': 'string',
            'description':
                'Domain name for queries/mutations (required with --queries or --mutations)',
          },
          'repo': {
            'type': 'string',
            'description': 'Repository name to inject for UseCase generation',
          },
          'service': {
            'type': 'string',
            'description': 'Service name to inject (alternative to repo)',
          },
          'exclude': {
            'type': 'string',
            'description': 'Types to exclude, comma-separated',
          },
          'display': {
            'type': 'string',
            'description':
                'List available items from schema: entities, queries, mutations, all',
          },
          'data': {
            'type': 'boolean',
            'description': 'Generate Data layer (DataSource/DataRepository)',
          },
          'zorphy': {
            'type': 'boolean',
            'description':
                'Use Zorphy annotations for entities (default: true)',
          },
          'dry_run': {
            'type': 'boolean',
            'description': 'Preview without writing files',
          },
          'force': {
            'type': 'boolean',
            'description': 'Overwrite existing files',
          },
          'verbose': {
            'type': 'boolean',
            'description': 'Enable verbose output',
          },
        },
        'required': ['url'],
      },
    };
  }

  /// Helper to extract optional config args
  List<String>? _configArgs(Map<String, dynamic> args) {
    if (args['path'] != null) return [args['path'] as String];
    return null;
  }

  /// Run a config subcommand
  Future<String> _runConfigCommand(List<String> subArgs) async {
    return await _runZuraffaProcess(['config', ...subArgs]);
  }

  /// Run the graphql command
  Future<String> _runGraphqlCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = ['graphql', '--url=${args["url"]}'];

    if (args['auth'] != null) cliArgs.add('--auth=${args["auth"]}');
    if (args['output'] != null) cliArgs.add('--output=${args["output"]}');
    if (args['methods'] != null) cliArgs.add('--methods=${args["methods"]}');
    if (args['entities'] != null) {
      cliArgs.add('--entities=${args["entities"]}');
    }
    if (args['queries'] != null) cliArgs.add('--queries=${args["queries"]}');
    if (args['mutations'] != null) {
      cliArgs.add('--mutations=${args["mutations"]}');
    }
    if (args['domain'] != null) cliArgs.add('--domain=${args["domain"]}');
    if (args['repo'] != null) cliArgs.add('--repo=${args["repo"]}');
    if (args['service'] != null) cliArgs.add('--service=${args["service"]}');
    if (args['exclude'] != null) cliArgs.add('--exclude=${args["exclude"]}');
    if (args['display'] != null) cliArgs.add('--display=${args["display"]}');
    if (args['data'] == true) cliArgs.add('--data');
    if (args['zorphy'] == true) cliArgs.add('--zorphy');
    if (args['zorphy'] == false) cliArgs.add('--no-zorphy');
    if (args['dry_run'] == true) cliArgs.add('--dry-run');
    if (args['force'] == true) cliArgs.add('--force');
    if (args['verbose'] == true) cliArgs.add('--verbose');

    return await _runZuraffaProcess(cliArgs);
  }

  /// Run the generate command
  Future<String> _runGenerateCommand(Map<String, dynamic> args) async {
    final List<String> cliArgs = ['generate', args['name'] as String];

    // Entity-based options
    if (args['methods'] != null) {
      final methods = args['methods'] as List;
      if (methods.isNotEmpty) {
        cliArgs.add('--methods=${methods.join(',')}');
      }
    }
    if (args['vpc'] == true) cliArgs.add('--vpc');
    if (args['state'] == true) cliArgs.add('--state');
    if (args['data'] == true) cliArgs.add('--data');
    if (args['datasource'] == true) cliArgs.add('--datasource');
    if (args['init'] == true) cliArgs.add('--init');
    if (args['id_field'] != null) {
      cliArgs.add('--id-field=${args['id_field']}');
    }
    if (args['id_field_type'] != null || args['id_type'] != null) {
      // Support both for backward compatibility
      cliArgs.add(
        '--id-field-type=${args['id_field_type'] ?? args['id_type']}',
      );
    }
    if (args['query_field'] != null) {
      cliArgs.add('--query-field=${args['query_field']}');
    }
    if (args['query_field_type'] != null) {
      cliArgs.add('--query-field-type=${args['query_field_type']}');
    }

    // Zorphy logic: Explicit flag > Default flag
    final useZorphy =
        args['zorphy'] == true ||
        args['zorphy'] == true ||
        (args['zorphy'] == null &&
            args['zorphy'] == null &&
            useZorphyByDefault);
    if (useZorphy) cliArgs.add('--zorphy');

    if (args['repo'] != null) cliArgs.add('--repo=${args['repo']}');
    if (args['service'] != null) cliArgs.add('--service=${args['service']}');
    if (args['usecases'] != null) {
      final usecases = args['usecases'] as List;
      if (usecases.isNotEmpty) {
        cliArgs.add('--usecases=${usecases.join(',')}');
      }
    }
    if (args['variants'] != null) {
      final variants = args['variants'] as List;
      if (variants.isNotEmpty) {
        cliArgs.add('--variants=${variants.join(',')}');
      }
    }
    if (args['domain'] != null) cliArgs.add('--domain=${args['domain']}');
    if (args['method'] != null) cliArgs.add('--method=${args['method']}');
    if (args['service_method'] != null) {
      cliArgs.add('--service-method=${args['service_method']}');
    }
    if (args['append'] == true) cliArgs.add('--append');
    if (args['params'] != null) cliArgs.add('--params=${args['params']}');
    if (args['returns'] != null) cliArgs.add('--returns=${args['returns']}');
    if (args['type'] != null) cliArgs.add('--type=${args['type']}');

    // Output options
    if (args['output'] != null) cliArgs.add('--output=${args['output']}');
    if (args['dry_run'] == true) cliArgs.add('--dry-run');
    if (args['force'] == true) cliArgs.add('--force');
    if (args['verbose'] == true) cliArgs.add('--verbose');
    if (args['test'] == true) cliArgs.add('--test');

    // Cache options
    if (args['cache'] == true) cliArgs.add('--cache');
    if (args['cache_policy'] != null) {
      cliArgs.add('--cache-policy=${args['cache_policy']}');
    }
    if (args['cache_storage'] != null) {
      cliArgs.add('--cache-storage=${args['cache_storage']}');
    }

    // Mock and DI options
    if (args['mock'] == true) cliArgs.add('--mock');
    if (args['mock_data_only'] == true) cliArgs.add('--mock-data-only');
    if (args['use_mock'] == true) cliArgs.add('--use-mock');
    if (args['di'] == true) cliArgs.add('--di');

    // Always use JSON format for parsing
    cliArgs.add('--format=json');

    return await _runZuraffaProcess(cliArgs);
  }

  /// Run the schema command
  Future<String> _runSchemaCommand() async {
    return await _runZuraffaProcess(['schema']);
  }

  /// Run the validate command
  Future<String> _runValidateCommand(Map<String, dynamic> args) async {
    // Write config to temp file
    final tempFile = File('.zfa_mcp_temp_config.json');
    try {
      await tempFile.writeAsString(jsonEncode(args['config']));

      final result = await _runZuraffaProcess(['validate', tempFile.path]);

      // Clean up
      try {
        await tempFile.delete();
      } catch (_) {
        // Ignore cleanup errors
      }

      return result;
    } catch (e) {
      // Clean up on error
      try {
        await tempFile.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  /// Execute zfa CLI process
  Future<String> _runZuraffaProcess(List<String> args) async {
    // Find the Dart executable
    final dartExecutable = Platform.executable;

    // Check if we're running from the package or need to call it globally
    // Try to use 'dart run' with the package first
    final process = await Process.run(
      dartExecutable,
      ['run', 'zuraffa:zfa', ...args],
      environment: {...Platform.environment},
      workingDirectory: Directory.current.path,
    );

    final stdoutStr = process.stdout as String;
    final stderrStr = process.stderr as String;

    if (process.exitCode != 0) {
      throw ProcessException(
        'zfa',
        args,
        stderrStr.isNotEmpty ? stderrStr : stdoutStr,
        process.exitCode,
      );
    }

    // If the output looks like JSON, pretty-print it for readability
    try {
      final json = jsonDecode(stdoutStr) as Map<String, dynamic>;
      return jsonEncode(json);
    } catch (_) {
      // Not JSON, return as-is
      return stdoutStr;
    }
  }

  /// Create a success response
  Map<String, dynamic> _success(dynamic id, Map<String, dynamic> result) {
    return {'jsonrpc': '2.0', 'result': result, 'id': id};
  }

  /// Create an error response
  Map<String, dynamic> _error(dynamic id, int code, String message) {
    return {
      'jsonrpc': '2.0',
      'error': {'code': code, 'message': message},
      'id': id,
    };
  }

  /// List available resources (generated files)
  Future<Map<String, dynamic>> _listResources(dynamic id) async {
    try {
      // Return cached results if available and fresh
      if (_resourcesCache != null &&
          _resourcesCacheTime != null &&
          DateTime.now().difference(_resourcesCacheTime!) < _cacheDuration) {
        return {
          'jsonrpc': '2.0',
          'result': {'resources': _resourcesCache!.take(_maxFiles).toList()},
          'id': id,
        };
      }

      final collected = <Map<String, dynamic>>[];
      final listingFuture = _doResourceListing(collected);

      // Use a longer timeout for IDE restart scenarios, but return partial results
      final cached = await listingFuture.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          // Return whatever we've collected so far (partial results)
          stderr.writeln(
            'Resource listing timeout, returning ${collected.length} partial results',
          );
          return collected.take(_maxFiles).toList();
        },
      );

      _resourcesCache = cached;
      _resourcesCacheTime = DateTime.now();

      return {
        'jsonrpc': '2.0',
        'result': {'resources': _resourcesCache},
        'id': id,
      };
    } catch (e) {
      stderr.writeln('Error listing resources: $e');
      return _error(id, -32603, 'Failed to list resources: ${e.toString()}');
    }
  }

  /// Read a resource's contents
  Future<Map<String, dynamic>> _readResource(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final uri = params['uri'] as String?;

    if (uri == null) {
      return _error(id, -32602, 'Missing uri parameter');
    }

    try {
      final file = File(uri.replaceFirst('file://', ''));
      if (!await file.exists()) {
        return _error(id, -32602, 'Resource not found: $uri');
      }

      final contents = await file.readAsString();

      return {
        'jsonrpc': '2.0',
        'result': {
          'contents': [
            {'uri': uri, 'mimeType': 'text/dart', 'text': contents},
          ],
        },
        'id': id,
      };
    } catch (e) {
      return _error(id, -32603, 'Error reading resource: ${e.toString()}');
    }
  }

  /// Scan a directory and add found Dart files to resources
  Future<void> _scanDirectory(
    String dirPath,
    List<Map<String, dynamic>> resources, {
    String prefix = '',
  }) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      // List with timeout - wrap in try-catch to skip slow directories
      try {
        final entities = await dir.list().toList().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => [],
        );

        for (final entity in entities) {
          try {
            if (entity is File && entity.path.endsWith('.dart')) {
              final relativePath = entity.path.replaceFirst('$dirPath/', '');
              final name = relativePath
                  .replaceAll('/', '.')
                  .replaceAll('.dart', '');

              resources.add({
                'uri': 'file://${entity.path}',
                'name': name,
                'description': '$prefix$relativePath',
                'mimeType': 'text/dart',
              });
            }
          } catch (_) {
            // Skip problematic files silently
          }
        }
      } catch (_) {
        // Skip slow or problematic directories silently
      }
    } catch (_) {
      // Skip problematic directories silently
    }
  }

  /// Perform actual resource listing with timeouts
  Future<List<Map<String, dynamic>>> _doResourceListing(
    List<Map<String, dynamic>> collected,
  ) async {
    // Scan common ZFA directories for Dart files (single level only)
    final directories = [
      'lib/src/domain/repositories',
      'lib/src/domain/usecases',
      'lib/src/data/data_sources',
      'lib/src/data/repositories',
      'lib/src/presentation',
    ];

    // Scan directories sequentially to reduce overhead
    for (final dirPath in directories) {
      await _scanDirectory(dirPath, collected);
      if (collected.length >= _maxFiles) break;
    }

    // Scan entities directory if we haven't hit the limit
    if (collected.length < _maxFiles) {
      await _scanDirectory(
        'lib/src/domain/entities',
        collected,
        prefix: 'entity/',
      );
    }

    return collected.take(_maxFiles).toList();
  }
}
