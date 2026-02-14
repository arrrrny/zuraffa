# Zuraffa Zed Extension

[Zuraffa](https://zuraffa.com) is an AI-first Flutter Clean Architecture Framework with MCP server for generating UseCases, Repositories, Views, Controllers, State objects, and Data layers.

## Features

This extension provides an MCP (Model Context Protocol) server that exposes Zuraffa's code generation capabilities to Zed's AI assistant:

- **Entity Generation**: Create Zorphy entities with fields, JSON serialization, sealed classes, and inheritance
- **UseCase Generation**: Generate single-shot, streaming, background, and completable UseCases
- **Repository Generation**: Create repository interfaces and implementations
- **VPC Layer**: Generate View, Presenter, and Controller for presentation layer
- **State Management**: Generate State objects with granular loading states
- **Data Layer**: Generate DataSources and DataRepositories
- **GraphQL Integration**: Introspect GraphQL schemas and generate entities/usecases
- **Dependency Injection**: Generate DI setup with get_it
- **Routing**: Generate GoRouter route definitions
- **Testing**: Generate unit tests for UseCases

## Requirements

- [Dart SDK](https://dart.dev/get-dart) installed
- Zuraffa package activated globally:
  ```bash
  dart pub global activate zuraffa
  ```

## Installation

1. Open Zed
2. Go to Extensions (`zed: extensions`)
3. Search for "Zuraffa"
4. Click Install

## Usage

Once installed, the Zuraffa MCP server will be available in Zed's Agent Panel. You can ask the AI assistant to:

- "Generate a Product entity with get, getList, create, update, delete methods"
- "Create a User UseCase with authentication service"
- "Generate GraphQL entities from this endpoint"
- "Show me the available ZFA tools"

## Available MCP Tools

- `generate` - Generate Clean Architecture code
- `entity_create` - Create a new Zorphy entity
- `entity_enum` - Create a new enum
- `entity_add_field` - Add fields to an existing entity
- `entity_from_json` - Create entities from JSON
- `entity_list` - List all entities
- `graphql` - Introspect GraphQL schema and generate code
- `config_init` - Initialize ZFA configuration
- `config_show` - Show current configuration
- `config_set` - Set configuration value
- `doctor` - Show tooling information
- `view` - Generate view classes
- `test` - Generate unit tests
- `di` - Generate dependency injection
- `route` - Generate route definitions
- `schema` - Get JSON schema for validation
- `validate` - Validate configuration

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [Documentation](https://zuraffa.com/docs/intro)
- [GitHub Repository](https://github.com/arrrrny/zuraffa)
- [Pub.dev](https://pub.dev/packages/zuraffa)
