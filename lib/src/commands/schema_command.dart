import 'dart:convert';

class SchemaCommand {
  void execute() {
    final schema = {
      '\$schema': 'http://json-schema.org/draft-07/schema#',
      'title': 'ZFA Generator Configuration',
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': 'Entity or UseCase name (PascalCase)',
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
              'watchList'
            ],
          },
          'description': 'Methods to generate for entity-based usecases',
        },
        'repo': {
          'type': 'string',
          'description': 'Repository to inject (single, enforces SRP)',
        },
        'usecases': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'UseCases to compose (orchestrator pattern)',
        },
        'variants': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Variants for polymorphic pattern',
        },
        'domain': {
          'type': 'string',
          'description': 'Domain folder for custom UseCases (required)',
        },
        'method': {
          'type': 'string',
          'description': 'Repository method name (default: auto from UseCase name)',
        },
        'append': {
          'type': 'boolean',
          'description': 'Append to existing repository/datasources',
        },
        'type': {
          'type': 'string',
          'enum': ['usecase', 'stream', 'background', 'completable'],
          'description': 'UseCase type for custom usecases',
        },
        'params': {
          'type': 'string',
          'description': 'Params type for custom usecase',
        },
        'returns': {
          'type': 'string',
          'description': 'Return type for custom usecase',
        },
        'id_type': {
          'type': 'string',
          'description': 'ID type for entity (default: String)',
        },
        'vpc': {
          'type': 'boolean',
          'description': 'Generate View + Presenter + Controller',
        },
        'state': {
          'type': 'boolean',
          'description': 'Generate State object',
        },
        'data': {
          'type': 'boolean',
          'description': 'Generate data layer (DataRepository + DataSource)',
        },
        'cache': {
          'type': 'boolean',
          'description': 'Enable caching with dual datasources',
        },
        'cache_policy': {
          'type': 'string',
          'enum': ['daily', 'restart', 'ttl'],
          'description': 'Cache policy',
        },
        'mock': {
          'type': 'boolean',
          'description': 'Generate mock data files',
        },
        'di': {
          'type': 'boolean',
          'description': 'Generate dependency injection files',
        },
        'test': {
          'type': 'boolean',
          'description': 'Generate unit tests',
        },
      },
      'required': ['name'],
    };

    print(const JsonEncoder.withIndent('  ').convert(schema));
  }
}
