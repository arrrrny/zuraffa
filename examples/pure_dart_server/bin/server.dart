/// Example pure Dart server using zuraffa.
///
/// Demonstrates that zuraffa core (DI, UseCase, hooks, signals)
/// works without any Flutter SDK dependency.
///
/// Run:  dart run bin/server.dart
library;

import 'package:logging/logging.dart';
import 'package:zuraffa/zuraffa.dart';

// ── Domain ──────────────────────────────────────────────────────────

class User {
  final String id;
  final String name;
  final String email;
  const User({required this.id, required this.name, required this.email});
}

// ── UseCase ────────────────────────────────────────────────────────

class GetUserUseCase extends UseCase<User, String> {
  @override
  Future<User> execute(String params, CancelToken? cancelToken) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return User(id: params, name: 'Alice', email: 'alice@example.com');
  }
}

// ── Repository with FailureHandler ─────────────────────────────────

class UserRepository with Loggable, FailureHandler {
  @override
  Logger get logger => Logger('UserRepository');

  Future<User> fetchUser(String id) async {
    try {
      throw FormatException('bad response');
    } catch (e) {
      throw handleError(e);
    }
  }
}

// ── Plugin system ──────────────────────────────────────────────────

class MyServicePlugin extends ZuraffaPlugin {
  @override
  String get pluginId => 'my_service';

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    di.registerLazySingleton<GetUserUseCase>(() => GetUserUseCase());
    di.registerFactory<String>(() => 'hello from plugin');
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};
}

// ── Main ───────────────────────────────────────────────────────────

Future<void> main() async {
  Zuraffa.setEnvironment(Environment.development);

  // 1. Engine + plugin system (pure Dart, no Flutter)
  final engine = ZuraffaEngine()..register(MyServicePlugin());
  await engine.bootstrap();

  final greeting = engine.di.get<String>();
  print('Plugin greeting: $greeting');

  // 2. UseCase with Result (via call())
  final useCase = GetUserUseCase();
  final result = await useCase('user-123');
  result.fold(
    (user) => print('User: ${user.name} (${user.email})'),
    (f) => print('Failure: ${f.message}'),
  );

  // 3. FailureHandler (pure Dart — uses ZuraffaPlatformException)
  final repo = UserRepository();
  try {
    await repo.fetchUser('x');
  } on AppFailure catch (e) {
    print('Caught AppFailure: ${e.runtimeType} — ${e.message}');
  }

  // 4. Signal (pure Dart)
  final counter = Signal<int>(0);
  counter.listen((v) => print('Signal updated: $v'));
  counter.value = 42;

  print('\nPure Dart zuraffa example completed successfully.');
}
