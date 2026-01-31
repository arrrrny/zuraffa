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
        'repos': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Repository names to inject',
        },
        'repository': {
          'type': 'boolean',
          'description': 'Generate repository interface',
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
      },
      'required': ['name'],
    };

    print(const JsonEncoder.withIndent('  ').convert(schema));
  }
}
