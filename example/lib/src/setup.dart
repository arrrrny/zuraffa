import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';

import 'data/cache/hive_setup.dart';
import 'data/datasources/todo_local_datasource.dart';
import 'data/repositories/todo_repository_impl.dart';
import 'domain/domain.dart';
import 'presentation/todo_presenter.dart';

final getIt = GetIt.instance;

/// One-call setup: Hive init, adapters, boxes, DI registrations.
///
/// The dependency graph is:
///
///   Hive.box → TodoLocalDataSource → TodoRepositoryImpl
///                                          ↓
///                                   TodoPresenter
///
/// Each layer only depends on the layer below it.
Future<void> setup() async {
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<Todo>('todos');

  final localDataSource = TodoLocalDataSource(Hive.box<Todo>('todos'));
  final repository = TodoRepositoryImpl(localDataSource);
  final presenter = TodoPresenter(repository: repository);

  getIt.registerSingleton(presenter);
}
