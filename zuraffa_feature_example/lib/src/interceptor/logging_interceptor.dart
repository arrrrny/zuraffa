import 'package:zuraffa/zuraffa.dart';

import '../state/todo_state.dart';

/// Example interceptor that logs todo fetch calls.
///
/// Demonstrates the observer pattern: calls `next(request)` and
/// subscribes to the result for logging, but does not modify it.
InterceptorEntry<void, List<Todo>> loggingInterceptor() {
  return InterceptorEntry<void, List<Todo>>(
    name: 'todo-logging',
    handler: (void request, next) {
      // ignore: avoid_print
      print('[LoggingInterceptor] Fetching todos...');
      final result = next(request);
      result.onSuccess((todos) {
        // ignore: avoid_print
        print('[LoggingInterceptor] Fetched ${todos.length} todos.');
      });
      result.onFailure((error) {
        // ignore: avoid_print
        print('[LoggingInterceptor] Failed: $error');
      });
      return result;
    },
  );
}
