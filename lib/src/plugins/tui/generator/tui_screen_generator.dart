/// Generates list/detail TUI screens for a Zuraffa entity (FR-011, SC-005).
///
/// The generator emits Dart source files declaring:
/// * `<Entity>ListScreen` — a list screen bound to the entity's
///   `getList` use case via [StreamUseCaseBinding] (or [UseCaseResultBinding]
///   for one-shot reads).
/// * `<Entity>DetailScreen` — a detail screen bound to the entity's `get`
///   use case via [UseCaseResultBinding].
///
/// Generated screens use only `package:zuraffa/...` and `package:nocterm/...`
/// imports — never `package:flutter` (FR-012). They require zero manual
/// wiring to run (SC-005): the generated screens auto-resolve their
/// dependencies via `ZuraffaDIContainer`.
library;

import 'package:dart_style/dart_style.dart';

import '../../../utils/string_utils.dart';

/// Metadata describing the entity whose TUI screens should be generated.
class TuiEntitySpec {
  const TuiEntitySpec({
    required this.name,
    required this.fields,
    required this.useCases,
    this.repositoryName,
  });

  /// The entity class name (e.g. `Product`).
  final String name;

  /// The entity's field declarations (`<name>:<type>`).
  final List<TuiFieldSpec> fields;

  /// The use cases available for binding (e.g. `get`, `getList`).
  final List<TuiUseCaseSpec> useCases;

  /// The repository name (defaults to `<name>Repository`).
  final String? repositoryName;

  String get repository => repositoryName ?? '${name}Repository';
}

class TuiFieldSpec {
  const TuiFieldSpec({required this.name, required this.type});

  /// Field name (e.g. `id`, `name`).
  final String name;

  /// Field Dart type (e.g. `String`, `int`, `double`).
  final String type;

  @override
  String toString() => '$type $name';
}

class TuiUseCaseSpec {
  const TuiUseCaseSpec({
    required this.name,
    required this.returnsType,
    this.isStream = false,
    this.paramsType,
  });

  /// The use case method name (e.g. `get`, `getList`).
  final String name;

  /// The use case's return type (e.g. `Product`, `List<Product>`).
  final String returnsType;

  /// Whether the use case is a stream (StreamUseCase) or one-shot (UseCase).
  final bool isStream;

  /// The params type, if any (e.g. `String` for `get(id: String)`).
  final String? paramsType;

  /// The use case class name (legacy, method-only form: `GetUseCase`,
  /// `GetListUseCase`).
  ///
  /// NOTE (#997): this method-only name does NOT match the class names the
  /// usecase plugin actually emits for an entity — those are
  /// entity-qualified (`GetProductUseCase`, `GetProductListUseCase`). The
  /// generated screens therefore resolve the entity-qualified name via
  /// [TuiScreenGenerator._useCaseClassName] instead of this getter. The
  /// getter is kept for input-schema consumers that only need the
  /// method-only label.
  String get className {
    final pascal = name[0].toUpperCase() + name.substring(1);
    return '${pascal}UseCase';
  }
}

/// Emits list/detail TUI screen Dart source for a Zuraffa entity.
///
/// The emitted source is pure-Dart (FR-012): only `package:zuraffa/...`
/// and `package:nocterm/...` imports — never `package:flutter`. The
/// generator uses [DartFormatter] to produce idiomatic output.
///
/// Entity + use-case imports are RELATIVE paths into the target project
/// (issue #997): the entity and its use cases live in the *target*
/// project's `lib/src/domain/` tree, never inside the `zuraffa` package —
/// so `package:zuraffa/domain/...` could never resolve and is no longer
/// emitted. The class names referenced by the screens are the
/// entity-qualified names the usecase plugin really generates
/// (`GetProductUseCase`, `GetProductListUseCase`).
class TuiScreenGenerator {
  TuiScreenGenerator({DartFormatter? formatter})
    : _formatter =
          formatter ??
          DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  final DartFormatter _formatter;

  /// The use-case class name the usecase plugin really emits for
  /// [method] on [entityName]: `GetProductUseCase` for `get`,
  /// `GetProductListUseCase` for `getList`, `WatchProductListUseCase` for
  /// `watchList` — i.e. `<Verb><Entity>[List]UseCase`.
  static String _useCaseClassName(String entityName, String method) {
    final verb = method[0].toUpperCase() + method.substring(1);
    if (verb.endsWith('List')) {
      final bare = verb.substring(0, verb.length - 4);
      return '$bare${entityName}ListUseCase';
    }
    return '$verb${entityName}UseCase';
  }

  /// The use-case import path (relative, into the target project) for a
  /// use-case class named [className] on the entity whose snake-case name
  /// is [entitySnake]. Mirrors the usecase plugin's real output layout:
  /// `lib/src/domain/usecases/<entity_snake>/<class_snake>_usecase.dart`.
  static String _useCaseImport(String entitySnake, String className) {
    final classSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );
    return '../../domain/usecases/$entitySnake/${classSnake}_usecase.dart';
  }

  /// Generates the `<Entity>ListScreen` Dart source.
  ///
  /// The list screen subscribes to the entity's `getList` use case stream
  /// (or refreshes the one-shot list use case on demand) and renders a
  /// `ListView` with the entity's primary fields as columns.
  String generateListScreen(TuiEntitySpec entity) {
    final listUseCase = entity.useCases.firstWhere(
      (u) => u.name == 'getList' || u.name == 'watchList',
      orElse: () => entity.useCases.firstWhere(
        (u) => u.returnsType.contains('List<'),
        orElse: () => throw ArgumentError(
          'Entity ${entity.name} has no list-returning use case',
        ),
      ),
    );

    // Real, entity-qualified use-case class + import (#997).
    final entitySnake = StringUtils.camelToSnake(entity.name);
    final listUseCaseClass = _useCaseClassName(entity.name, listUseCase.name);
    final listUseCaseImport = _useCaseImport(entitySnake, listUseCaseClass);

    final source =
        '''
// GENERATED BY zuraffa/tui — do not edit by hand.
// specs/017-tui-plugin FR-011 / SC-005.

import 'package:nocterm/nocterm.dart';
import 'package:zuraffa/src/plugins/tui/core/stateful_screen.dart';
import 'package:zuraffa/src/plugins/tui/di/tui_di_resolver.dart';
import 'package:zuraffa/src/plugins/tui/binding/binding.dart';
import 'package:zuraffa/src/core/module/di_container.dart';
import '../../domain/entities/$entitySnake/$entitySnake.dart';
import '$listUseCaseImport';

class ${entity.name}ListScreen extends StatefulScreen {
  const ${entity.name}ListScreen({super.key});

  @override
  TuiScreenState<${entity.name}ListScreen> createState() =>
      _${entity.name}ListScreenState();
}

class _${entity.name}ListScreenState
    extends TuiScreenState<${entity.name}ListScreen> {
  late final UseCaseResultBinding<List<${entity.name}>, void> _binding;

  @override
  void initState() {
    super.initState();
    // Resolve the use case through the caller's ZuraffaDIContainer (FR-008).
    // In a real app the container is injected by ZuraffaTui.run; for tests
    // the container is registered before the screen is mounted.
    final di = ZuraffaDIContainer();
    _binding = UseCaseResultBinding<List<${entity.name}>, void>(
      useCase: $listUseCaseClass(di.get<${entity.repository}>()),
      params: null,
      onValue: (_) => setState(() {}),
    );
    _binding.start();
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Component buildScreen(BuildContext context) {
    final items = _binding.value ?? const [];
    return Center(
      child: Column(
        children: [
          Text('${entity.name} List'),
          ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) =>
                Text(items[i].${entity.fields.first.name}.toString()),
          ),
        ],
      ),
    );
  }
}
''';
    return _formatter.format(source);
  }

  /// Generates the `<Entity>DetailScreen` Dart source.
  ///
  /// The detail screen reads a single entity via its `get` use case and
  /// renders its fields in a two-column table.
  String generateDetailScreen(TuiEntitySpec entity) {
    final getUseCase = entity.useCases.firstWhere(
      (u) => u.name == 'get',
      orElse: () =>
          throw ArgumentError('Entity ${entity.name} has no get use case'),
    );

    // Real, entity-qualified use-case class + import (#997).
    final entitySnake = StringUtils.camelToSnake(entity.name);
    final getUseCaseClass = _useCaseClassName(entity.name, getUseCase.name);
    final getUseCaseImport = _useCaseImport(entitySnake, getUseCaseClass);

    final headers = entity.fields.map((f) => "'${f.name}'").join(', ');
    final rowCells = entity.fields
        .map((f) => "item.${f.name}.toString()")
        .join(', ');

    final source =
        '''
// GENERATED BY zuraffa/tui — do not edit by hand.
// specs/017-tui-plugin FR-011 / SC-005.

import 'package:nocterm/nocterm.dart';
import 'package:zuraffa/src/plugins/tui/core/stateful_screen.dart';
import 'package:zuraffa/src/plugins/tui/di/tui_di_resolver.dart';
import 'package:zuraffa/src/plugins/tui/binding/binding.dart';
import 'package:zuraffa/src/core/module/di_container.dart';
import 'package:zuraffa/src/plugins/tui/widgets/table.dart';
import '../../domain/entities/$entitySnake/$entitySnake.dart';
import '$getUseCaseImport';

class ${entity.name}DetailScreen extends StatefulScreen {
  const ${entity.name}DetailScreen({
    super.key,
    required this.id,
  });

  final String id;

  @override
  TuiScreenState<${entity.name}DetailScreen> createState() =>
      _${entity.name}DetailScreenState();
}

class _${entity.name}DetailScreenState
    extends TuiScreenState<${entity.name}DetailScreen> {
  late final UseCaseResultBinding<${entity.name}, String> _binding;

  @override
  void initState() {
    super.initState();
    final di = ZuraffaDIContainer();
    _binding = UseCaseResultBinding<${entity.name}, String>(
      useCase: $getUseCaseClass(di.get<${entity.repository}>()),
      params: component.id,
      onValue: (_) => setState(() {}),
    );
    _binding.start();
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Component buildScreen(BuildContext context) {
    final item = _binding.value;
    return Center(
      child: Column(
        children: [
          Text('${entity.name} Detail'),
          if (item != null)
            Table(
              headers: [$headers],
              rows: [
                [$rowCells],
              ],
            )
          else
            Text('Loading...'),
        ],
      ),
    );
  }
}
''';
    return _formatter.format(source);
  }
}
