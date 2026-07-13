// Example bridge for Todo — mirrors what `zfa api Todo` would generate.
//
// Registers Todo UseCases as dart:developer extensions callable from
// any VM Service client while the app runs in debug/profile mode.

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/todo/todo.dart';
import '../../domain/usecases/todo/create_todo_usecase.dart';
import '../../domain/usecases/todo/get_todo_list_usecase.dart';

final getIt = GetIt.instance;

void registerTodoApiBridge() {
  if (kReleaseMode) return;
  if (kProfileMode && !Zuraffa.enableApiInProfile) return;

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.todo.createTodo',
      domain: 'todo',
      usecase: 'createTodo',
      params: {'args': 'Todo'},
      returns: 'Todo',
      isStream: false,
    ),
    handler: _handleCreateTodo,
  );

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.todo.getTodoList',
      domain: 'todo',
      usecase: 'getTodoList',
      params: {},
      returns: 'List<Todo>',
      isStream: false,
    ),
    handler: _handleGetTodoList,
  );
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// Creates a Todo from a JSON-encoded `args` parameter.
Future<developer.ServiceExtensionResponse> _handleCreateTodo(
  String method,
  Map<String, String> args,
) async {
  try {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());
    }
    // Auto-fill id if not provided — the repository generates it.
    if (!json.containsKey('id') || json['id'] == null) {
      json['id'] = 0;
    }
    if (!json.containsKey('createdAt') || json['createdAt'] == null) {
      json['createdAt'] = DateTime.now().toIso8601String();
    }
    final params = Todo.fromJson(json);
    final useCase = getIt<CreateTodoUseCase>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(result, (v) => v.toJson());
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

/// Returns the full todo list (no params needed).
Future<developer.ServiceExtensionResponse> _handleGetTodoList(
  String method,
  Map<String, String> args,
) async {
  try {
    final params = ListQueryParams<Todo>();
    final useCase = getIt<GetTodoListUseCase>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => {'items': v.map((e) => e.toJson()).toList()},
    );
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}
