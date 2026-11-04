import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/cancel_token.dart';
import 'package:zuraffa/src/core/module/mcp_usecase_tool.dart';
import 'package:zuraffa/src/domain/usecase.dart';

// Zorphy-style params/result doubles: `fromJson` + `toJson` are exactly the
// members Zorphy generates for entities/params, so they stand in for the
// "Zorphy entities give the JSON-schema seam" contract (issue #2046).
class GreetParams {
  final String name;
  final bool shout;

  const GreetParams({required this.name, this.shout = false});

  factory GreetParams.fromJson(Map<String, dynamic> json) => GreetParams(
    name: json['name'] as String,
    shout: json['shout'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'name': name, if (shout) 'shout': true};
}

class Greeting {
  final String message;

  const Greeting(this.message);

  Map<String, dynamic> toJson() => {'message': message};
}

class GreetUseCase extends UseCase<Greeting, GreetParams> {
  @override
  Future<Greeting> execute(GreetParams params, CancelToken? cancelToken) =>
      Future.value(Greeting('Hello, ${params.name}${params.shout ? '!' : ''}'));
}

class BoomUseCase extends UseCase<Greeting, GreetParams> {
  @override
  Future<Greeting> execute(GreetParams params, CancelToken? cancelToken) async {
    throw Exception('boom');
  }
}

class UpperCaseUseCase extends UseCase<String, GreetParams> {
  @override
  Future<String> execute(GreetParams params, CancelToken? cancelToken) =>
      Future.value(params.name.toUpperCase());
}

void main() {
  group('McpUseCaseTool', () {
    test('declares name/description from the registration', () {
      final tool = McpUseCaseTool<Greeting, GreetParams>(
        useCase: GreetUseCase(),
        name: 'greet',
        description: 'Greets the named user.',
        decode: GreetParams.fromJson,
      );
      expect(tool.name, 'greet');
      expect(tool.description, 'Greets the named user.');
    });

    test('is mutating by default and readonly only when declared', () {
      final mutating = McpUseCaseTool<Greeting, GreetParams>(
        useCase: GreetUseCase(),
        name: 'greet',
        description: 'd',
        decode: GreetParams.fromJson,
      );
      final readonly = McpUseCaseTool<Greeting, GreetParams>(
        useCase: GreetUseCase(),
        name: 'greet',
        description: 'd',
        readonly: true,
        decode: GreetParams.fromJson,
      );
      expect(mutating.readonly, isFalse);
      expect(readonly.readonly, isTrue);
    });

    test('carries the declarative inputSchema it was given', () {
      final schema = McpSchema.object(
        properties: {
          'name': McpSchema.string(description: 'Who to greet'),
          'shout': McpSchema.boolean(description: 'Shout the greeting'),
        },
        required: ['name'],
      );
      final tool = McpUseCaseTool<Greeting, GreetParams>(
        useCase: GreetUseCase(),
        name: 'greet',
        description: 'd',
        inputSchema: schema,
        decode: GreetParams.fromJson,
      );
      expect(tool.inputSchema, same(schema));
      expect(tool.inputSchema['type'], 'object');
      expect(
        (tool.inputSchema['properties']
            as Map<String, dynamic>)['name']['type'],
        'string',
      );
      expect(tool.inputSchema['required'], ['name']);
    });

    test('decodes arguments through the params seam and round-trips the result '
        'through toJson', () async {
      final tool = McpUseCaseTool<Greeting, GreetParams>(
        useCase: GreetUseCase(),
        name: 'greet',
        description: 'd',
        decode: GreetParams.fromJson,
      );
      final result = await tool.call({'name': 'Ada', 'shout': true});
      expect(result.isError, isFalse);
      expect(jsonDecode(result.text), {'message': 'Hello, Ada!'});
    });

    test(
      'invalid arguments decode to a tool-level error, never a throw',
      () async {
        final tool = McpUseCaseTool<Greeting, GreetParams>(
          useCase: GreetUseCase(),
          name: 'greet',
          description: 'd',
          decode: GreetParams.fromJson,
        );
        final result = await tool.call({'nope': 1});
        expect(result.isError, isTrue);
        expect(result.text, contains('greet'));
      },
    );

    test('usecase failure surfaces as an isError result', () async {
      final tool = McpUseCaseTool<Greeting, GreetParams>(
        useCase: BoomUseCase(),
        name: 'boom',
        description: 'd',
        decode: GreetParams.fromJson,
      );
      final result = await tool.call({'name': 'Ada'});
      expect(result.isError, isTrue);
      expect(result.text, contains('boom'));
    });

    test('results without toJson fall back to toString encoding', () async {
      final tool = McpUseCaseTool<String, GreetParams>(
        useCase: UpperCaseUseCase(),
        name: 'upper',
        description: 'd',
        decode: GreetParams.fromJson,
      );
      final result = await tool.call({'name': 'ada'});
      expect(result.isError, isFalse);
      expect(result.text, 'ADA');
    });
  });

  group('McpSchema', () {
    test('object builds a draft-07 subset object schema', () {
      final schema = McpSchema.object(
        description: 'Greet args',
        properties: {
          'name': McpSchema.string(description: 'Who to greet'),
          'count': McpSchema.integer(description: 'How many times'),
          'rate': McpSchema.number(),
          'shout': McpSchema.boolean(),
          'tags': McpSchema.array(items: McpSchema.string()),
          'kind': McpSchema.string(enumValues: ['formal', 'casual']),
        },
        required: ['name'],
      );
      expect(schema['type'], 'object');
      expect(schema['description'], 'Greet args');
      expect(schema['required'], ['name']);
      final props = schema['properties'] as Map<String, dynamic>;
      expect(props['name']['type'], 'string');
      expect(props['count']['type'], 'integer');
      expect(props['rate']['type'], 'number');
      expect(props['shout']['type'], 'boolean');
      expect(props['tags']['type'], 'array');
      expect(props['tags']['items']['type'], 'string');
      expect(props['kind']['enum'], ['formal', 'casual']);
    });
  });
}
