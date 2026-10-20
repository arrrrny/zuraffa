import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../models/parsed_usecase_info.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/method_shape_parser.dart';
import '../../../utils/project_flavor.dart';
import '../services/mock_staleness_detector.dart';
import 'mock_type_helper.dart';

/// Generates the certified mock datasource that implements
/// `<Entity>DataSource`.
///
/// Lane contract (issue #1570): the skip decision for an existing mock
/// is a SHAPE check, not an existence check. The mock's implemented
/// member set is compared against the interface's declared member set
/// ([MockStalenessDetector] — the certification's structural
/// primitives, the same comparison the tdd lane's stale-mirror check
/// follows):
///   * in-sync mock → `skipped` (idempotent regeneration: extend,
///     never clobber);
///   * stale mock (missing interface members) → repaired through the
///     idempotent append path, ledger `updated`, with a notice naming
///     the missing members — the drift never reaches the analyze gate
///     as a compile error (`non_abstract_class_inherits_abstract_member`).
///     The repair is strictly additive: members the mock already
///     declares are not re-emitted, so customized bodies survive
///     (issue #1570 review).
/// `--force` regeneration, `--append` idempotent member addition, and
/// `--revert` undo/delete keep their pre-existing contracts.
class MockDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  MockDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create();

  Future<GeneratedFile> generateMockDataSource(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final filePath =
        '$outputDir/data/datasources/$entitySnake/${entitySnake}_mock_datasource.dart';
    final fileExists = await fileSystem.exists(filePath);

    // Issue #1570: shape-check staleness detection — the skip decision
    // is the interface/mock member-set comparison (the certification's
    // structural check, like the tdd lane's stale-mirror comparison),
    // not "file exists → skip". When the certified mock implements a
    // strict subset of the interface (created earlier by `mock create`
    // or a make run with a smaller --methods= set), the mock is STALE:
    // repair it through the idempotent append path below instead of
    // skipping, so interface and implementer cannot drift apart (the
    // non_abstract_class_inherits_abstract_member / build-gate-red
    // failure class). The check arms exactly where the old code had
    // the existence-based skip: an existing file the fresh path would
    // refuse. Append / force / revert runs keep their own contracts.
    final missingInterfaceMembers =
        fileExists &&
            !config.appendToExisting &&
            !options.force &&
            !config.revert
        ? await MockStalenessDetector.detectMockStaleness(
            interfacePath:
                '$outputDir/data/datasources/$entitySnake/${entitySnake}_datasource.dart',
            interfaceClass: '${entityName}DataSource',
            mockPath: filePath,
            mockClass: '${entityName}MockDataSource',
            fileSystem: fileSystem,
          )
        : const <ParsedUseCaseInfo>[];
    final shapeDrift = missingInterfaceMembers.isNotEmpty;
    if (shapeDrift) {
      print(
        '🔧 Shape drift detected: ${entityName}MockDataSource is missing '
        '${missingInterfaceMembers.map((m) => m.fieldName).join(", ")} '
        'declared by ${entityName}DataSource — repairing '
        '$filePath (issue #1570)',
      );
    }

    // Issue #942: the mock datasource imports the entity file AND the
    // framework mock barrel unprefixed. When the entity's name matches a
    // zuraffa core export (an entity named `Credentials` — the framework
    // exports its own `Credentials` params class), every use of the name
    // is an `ambiguous_import` error and the generated tree does not
    // compile. The generator knows the entity's own symbols, so the
    // barrel import hides exactly those symbols and the entity's own
    // definitions win resolution. With no locally-imported entity types
    // the hide list is empty and the import is emitted unchanged.
    // Issue #1418: the hide is verified against the MOCK barrel's own
    // surface — the import's actual library — not against zuraffa.dart
    // (an unverified hide is an undefined_hidden_name warning, and zfa
    // build's analyze gate fails on warnings).
    final allReturnsTypes = <String>{
      if (config.returnsType != null && config.returnsType!.isNotEmpty)
        config.returnsType!,
      for (final m in config.methods)
        if (_parseMethodShape(m).$3 != null &&
            _parseMethodShape(m).$3!.isNotEmpty)
          _parseMethodShape(m).$3!,
    };
    final barrelHide = <String>{
      if (config.isEntityBased &&
          fileSystem.existsSync(
            '$outputDir/domain/entities/$entitySnake/$entitySnake.dart',
          ))
        ...EntityUtils.mockBarrelHideNames(entityName),
      for (final rt in allReturnsTypes)
        for (final type in EntityUtils.extractEntityTypes(rt))
          ...EntityUtils.mockBarrelHideNames(type),
      if (config.paramsType != null && config.paramsType!.isNotEmpty)
        for (final type in EntityUtils.extractEntityTypes(config.paramsType!))
          ...EntityUtils.mockBarrelHideNames(type),
    }.toList();

    final foreignEntitySnakes = <String>{};
    for (final rt in allReturnsTypes) {
      for (final type in EntityUtils.extractEntityTypes(rt)) {
        final snake = StringUtils.camelToSnake(type);
        if (snake == entitySnake && config.isEntityBased) continue;
        foreignEntitySnakes.add(snake);
      }
    }
    if (config.paramsType != null && config.paramsType!.isNotEmpty) {
      for (final type in EntityUtils.extractEntityTypes(config.paramsType!)) {
        final snake = StringUtils.camelToSnake(type);
        if (snake == entitySnake && config.isEntityBased) continue;
        foreignEntitySnakes.add(snake);
      }
    }

    final flavor = await detectProjectFlavor(outputDir, fileSystem);
    final mockImport = flavor == ProjectFlavor.flutter
        ? 'package:zuraffa_flutter/zuraffa_flutter.dart'
        : 'package:zuraffa/mock.dart';

    final directives = [
      Directive.import('dart:async'),
      // Canonical zuraffa-native mock marker: detects native mocking for static
      // tooling (e.g. speckit-tdd-setup) without a third-party double library.
      Directive.import(mockImport, hide: barrelHide),
      if (config.isEntityBased &&
          fileSystem.existsSync(
            '$outputDir/domain/entities/$entitySnake/$entitySnake.dart',
          ))
        Directive.import(
          '../../../domain/entities/$entitySnake/$entitySnake.dart',
        ),
      for (final snake in foreignEntitySnakes)
        if (fileSystem.existsSync(
          '$outputDir/domain/entities/$snake/$snake.dart',
        ))
          Directive.import('../../../domain/entities/$snake/$snake.dart'),
      if (fileSystem.existsSync(
        '$outputDir/data/mock/${entitySnake}_mock_data.dart',
      ))
        Directive.import('../../mock/${entitySnake}_mock_data.dart'),
      for (final rt in allReturnsTypes)
        for (final type in EntityUtils.extractEntityTypes(rt))
          if (fileSystem.existsSync(
            '$outputDir/data/mock/${StringUtils.camelToSnake(type)}_mock_data.dart',
          ))
            Directive.import(
              '../../mock/${StringUtils.camelToSnake(type)}_mock_data.dart',
            ),
      Directive.import('${entitySnake}_datasource.dart'),
    ];

    final delayField = Field(
      (f) => f
        ..name = '_delay'
        ..modifier = FieldModifier.final$
        ..type = refer('Duration'),
    );

    final constructor = Constructor(
      (c) => c
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'delay'
              ..type = refer('Duration?'),
          ),
        )
        ..initializers.add(
          refer('_delay')
              .assign(
                refer('delay').ifNullThen(
                  refer(
                    'Duration',
                  ).constInstance(const [], {'milliseconds': literalNum(100)}),
                ),
              )
              .code,
        ),
    );

    final methods = <Method>[];

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(refer('override'))
            ..returns = typeHelper.futureVoidType()
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.addAll([
                  refer('logger').property('info').call([
                    literalString('Initializing ${entityName}MockDataSource'),
                  ]).statement,
                  refer('Future<void>')
                      .property('delayed')
                      .call([
                        refer(
                          'Duration',
                        ).constInstance(const [], {'seconds': literalNum(1)}),
                      ])
                      .awaited
                      .statement,
                  refer('logger').property('info').call([
                    literalString('${entityName}MockDataSource initialized'),
                  ]).statement,
                ]),
            ),
        ),
      );

      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<bool>')
            ..lambda = true
            ..body = refer(
              'Stream',
            ).property('value').call([literalBool(true)]).code,
        ),
      );

      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..annotations.add(refer('override'))
            ..returns = typeHelper.futureVoidType()
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Disposing ${entityName}MockDataSource'),
                  ]).statement,
                ),
            ),
        ),
      );
    }

    methods.addAll(_generateMockDataSourceMethods(config));

    if ((config.appendToExisting || shapeDrift) && fileExists) {
      final existing = await fileSystem.read(filePath);
      var updated = existing;

      // Add missing imports
      final entities = <String>{};
      if (config.paramsType != null && config.paramsType != 'NoParams') {
        entities.addAll(EntityUtils.extractEntityTypes(config.paramsType!));
      }
      if (config.returnsType != null && config.returnsType != 'void') {
        entities.addAll(EntityUtils.extractEntityTypes(config.returnsType!));
      }
      // Issue #1923: a repaired member may declare types this run's config
      // does not (the shape-drift case — the member came from the
      // interface). Import them too, or the synthesized foreign-entity
      // body references an unresolved type.
      for (final member in missingInterfaceMembers) {
        if (member.paramsType != null && member.paramsType != 'NoParams') {
          entities.addAll(EntityUtils.extractEntityTypes(member.paramsType!));
        }
        if (member.returnsType != null && member.returnsType != 'void') {
          entities.addAll(EntityUtils.extractEntityTypes(member.returnsType!));
        }
      }
      final targetEntity = config.isCustomUseCase && config.returnsType != null
          ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
                config.name
          : config.name;
      entities.add('${targetEntity}MockData');

      for (final entityName in entities) {
        final entitySnake = StringUtils.camelToSnake(
          entityName.replaceAll('MockData', ''),
        );
        final isMockData = entityName.endsWith('MockData');
        final importPath = isMockData
            ? '../../mock/${entitySnake}_mock_data.dart'
            : '../../../domain/entities/$entitySnake/$entitySnake.dart';

        if (!updated.contains(importPath)) {
          final importRequest = AppendRequest.import(
            source: updated,
            importPath: importPath,
          );
          updated = appendExecutor.execute(importRequest).source;
        }
      }

      // Issue #1570 review: the repaired mock's implemented member set
      // is read through the detector's shared primitive (same scope as
      // the drift check — the mock class only), and a shape-drift
      // repair is strictly ADDITIVE: members the mock already declares
      // are never re-emitted (the append strategy replaces same-name
      // members, which would clobber customized bodies — the finding's
      // verified `get` case). The explicit `appendToExisting` path
      // keeps its pre-existing append-or-replace contract.
      final existingMembers =
          MockStalenessDetector.implementedMemberNamesIn(
            updated,
            '${entityName}MockDataSource',
          ) ??
          const <String>{};

      for (final method in methods) {
        final methodName = method.name;
        if (shapeDrift &&
            methodName != null &&
            existingMembers.contains(methodName)) {
          continue;
        }
        final methodSource = specLibrary.emitSpec(method);
        final request = AppendRequest.method(
          source: updated,
          className: '${entityName}MockDataSource',
          memberSource: methodSource,
        );
        final result = config.revert
            ? appendExecutor.undo(request)
            : appendExecutor.execute(request);
        updated = result.source;
        if (methodName != null) existingMembers.add(methodName);
      }

      // Issue #1570: the config-driven method set above covers the
      // requested --methods= surface; the shape drift may name members
      // the interface carries that this run's config does not (e.g.
      // `mock create` after an unrelated append). Synthesize
      // implementations for exactly those missing members from the
      // interface's own shapes so the repaired mock always covers the
      // full declared surface.
      for (final member in missingInterfaceMembers) {
        if (existingMembers.contains(member.fieldName)) continue;
        final method = _mockMethodImplForMissingMember(
          entityName: entityName,
          member: member,
        );
        if (method == null) continue;
        final request = AppendRequest.method(
          source: updated,
          className: '${entityName}MockDataSource',
          memberSource: specLibrary.emitSpec(method),
        );
        final result = config.revert
            ? appendExecutor.undo(request)
            : appendExecutor.execute(request);
        updated = result.source;
        existingMembers.add(member.fieldName);
      }

      final written = await FileUtils.writeFile(
        filePath,
        updated,
        'mock_datasource',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
      // Issue #1570: a shape-drift repair is an UPDATE (extend the
      // member set), not a wholesale overwrite — the ledger says so the
      // same way the method-append lane's mock writer does. The
      // user-requested append path (appendToExisting) keeps its
      // pre-existing action contract untouched.
      if (shapeDrift && written.action == 'overwritten') {
        return GeneratedFile(
          path: written.path,
          type: written.type,
          action: 'updated',
          content: written.content,
        );
      }
      return written;
    }

    final clazz = Class(
      (c) => c
        ..name = '${entityName}MockDataSource'
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..docs.add('/// Mock data source for $entityName')
        ..fields.add(delayField)
        ..constructors.add(constructor)
        ..methods.addAll(methods),
    );

    if (config.revert && !config.appendToExisting) {
      return FileUtils.deleteFile(
        filePath,
        'mock_datasource',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'mock_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
      fileSystem: fileSystem,
    );
  }

  /// Issue #1570: builds a mock implementation for one missing
  /// interface member from the interface's own extracted shape
  /// ([ParsedUseCaseInfo]). Body patterns mirror what the lane already
  /// emits for the known CRUD shapes: log → delay → sample fixture /
  /// Future.value / Stream.fromFuture.
  ///
  /// The signature mirrors the interface declaration: no `params`
  /// argument when the member declares none, and a getter body when the
  /// interface member is a getter (issue #1570 review — an always-required
  /// `params` is `invalid_override` for `dispose()` and
  /// `conflicting_method_and_field` for `Stream<bool> get isInitialized`).
  /// The stream body's delayed future is typed `Future<$returns>` so
  /// `Stream.fromFuture` yields `Stream<T>` (a `Future<void>` yields
  /// `Stream<void>` and fails `argument_type_not_assignable`).
  ///
  /// Returns null for shapes this lane cannot honestly implement: the
  /// only getter shape the interface writer emits is the `--init`
  /// `Stream<bool> get isInitialized`; any other getter is left to the
  /// certification gate's report instead of fabricating a body.
  Method? _mockMethodImplForMissingMember({
    required String entityName,
    required ParsedUseCaseInfo member,
  }) {
    final returns = member.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');
    final isStream = member.useCaseType == 'stream';
    final isVoid = baseReturns == 'void' || baseReturns == 'dynamic';
    final paramsType = member.paramsType ?? 'NoParams';
    // Issue #1923: a missing foreign-entity member whose entity wraps
    // `List<$entityName>` is derivable from the subject fixture — repair it
    // with the same honest paged read the create path emits, instead of the
    // single-entity sample (a wrong-type body).
    final foreignPage = !isList && !isVoid && baseReturns != entityName
        ? _deriveForeignPageShape(
            entityName: entityName,
            foreignType: baseReturns,
            paramsType: paramsType,
          )
        : null;

    if (member.isGetter) {
      if (!isStream || baseReturns != 'bool') return null;
      return Method(
        (m) => m
          ..name = member.fieldName
          ..type = MethodType.getter
          ..returns = refer('Stream<bool>')
          ..annotations.add(refer('override'))
          ..lambda = true
          ..body = refer(
            'Stream',
          ).property('value').call([literalBool(true)]).code,
      );
    }

    final returnType = isStream ? 'Stream<$returns>' : 'Future<$returns>';

    final futureBody = Block(
      (b) => b
        ..statements.addAll([
          refer('logger').property('info').call([
            literalString('${member.fieldName} called'),
          ]).statement,
          refer(
            'Future',
          ).property('delayed').call([refer('_delay')]).awaited.statement,
          if (isList) ...[
            refer(
              '${entityName}MockData',
            ).property('sampleList').returned.statement,
          ] else if (isVoid) ...[
            refer('Future').property('value').call([]).returned.statement,
          ] else if (foreignPage != null)
            ..._foreignPageStatements(
              entityName: entityName,
              foreignType: baseReturns,
              shape: foreignPage,
            )
          else ...[
            refer(
              '${entityName}MockData',
            ).property('sample$entityName').returned.statement,
          ],
        ]),
    );

    final streamBody = Block(
      (b) => b
        ..statements.add(
          refer('Stream')
              .property('fromFuture')
              .call([
                refer('Future<$returns>').property('delayed').call([
                  refer('_delay'),
                  Method(
                    (mm) => mm
                      ..lambda = foreignPage == null
                      ..body = foreignPage != null
                          ? Block(
                              (bb) => bb
                                ..statements.addAll(
                                  _foreignPageStatements(
                                    entityName: entityName,
                                    foreignType: baseReturns,
                                    shape: foreignPage,
                                  ),
                                ),
                            )
                          : (isList
                                ? refer(
                                    '${entityName}MockData',
                                  ).property('sampleList').code
                                : (isVoid
                                      ? refer(
                                          'Future',
                                        ).property('value').call([]).code
                                      : refer(
                                          '${entityName}MockData',
                                        ).property('sample$entityName').code)),
                  ).closure,
                ]),
              ])
              .returned
              .statement,
        ),
    );

    return Method(
      (m) => m
        ..name = member.fieldName
        ..returns = refer(returnType)
        ..annotations.add(refer('override'))
        ..modifier = isStream ? null : MethodModifier.async
        ..requiredParameters.addAll(
          member.parameterCount == 0
              ? const []
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(paramsType),
                  ),
                ],
        )
        ..body = isStream ? streamBody : futureBody,
    );
  }

  static (String, String?, String?) _parseMethodShape(String token) =>
      MethodShapeParser.parseMethodShape(token);

  /// The verbs the switch in [_generateMockDataSourceMethods] handles
  /// explicitly; every other token is an arbitrary member and carries the
  /// #1850 shape contract ([validateMemberShapes]).
  static const _crudMethodNames = <String>{
    'get',
    'list',
    'getList',
    'create',
    'update',
    'toggle',
    'delete',
    'watch',
    'watchList',
  };

  /// Unwraps `?` and `Future<...>` / `Stream<...>` so wrapped shapes
  /// (e.g. `Future<void>`, `Future<Entity>`) classify identically to their
  /// raw forms (issue #1824).
  static String _baseReturnType(String returns) {
    var baseReturns = returns.replaceAll('?', '');
    var changed = true;
    while (changed) {
      changed = false;
      if (baseReturns.startsWith('Future<') && baseReturns.endsWith('>')) {
        baseReturns = baseReturns.substring(7, baseReturns.length - 1).trim();
        changed = true;
      } else if (baseReturns.startsWith('Stream<') &&
          baseReturns.endsWith('>')) {
        baseReturns = baseReturns.substring(7, baseReturns.length - 1).trim();
        changed = true;
      }
    }
    return baseReturns;
  }

  /// Issue #1850 (honest bodies): the return shapes an arbitrary verb can be
  /// given a real body for. Shared by validation and emission so the
  /// pre-flight and the generated method can never disagree.
  static bool _isHonestArbitraryReturn(
    String baseReturns,
    String entityName, [
    String? outputDir,
  ]) {
    if (baseReturns == 'void' || baseReturns == 'dynamic') return true;
    if (baseReturns == entityName) return true;
    if (outputDir != null &&
        EntityAnalyzer.entityFileExists(baseReturns, outputDir)) {
      return true;
    }
    if (baseReturns.startsWith('List<') && baseReturns.endsWith('>')) {
      final inner = baseReturns.substring(5, baseReturns.length - 1).trim();
      if (inner == entityName) return true;
      if (outputDir != null &&
          EntityAnalyzer.entityFileExists(inner, outputDir)) {
        return true;
      }
      return false;
    }
    return false;
  }

  /// Issue #1922: validates every arbitrary (non-CRUD) member shape of
  /// [config] WITHOUT emitting or writing anything, so a refused member
  /// (the #1850 `ArgumentError`) leaves the working tree untouched instead
  /// of clobbering the datasource interface that was written before the
  /// shape check used to run.
  static void validateMemberShapes(GeneratorConfig config) {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    for (final method in config.methods) {
      if (_crudMethodNames.contains(method)) continue;
      final parsed = _parseMethodShape(method);
      final methodName = parsed.$1;
      final methodReturns = parsed.$3 ?? config.returnsType;
      final returns = (methodReturns != null && methodReturns.isNotEmpty)
          ? methodReturns
          : 'void';
      final baseReturns = _baseReturnType(returns);
      if (!_isHonestArbitraryReturn(
        baseReturns,
        entityName,
        config.outputDir,
      )) {
        throw ArgumentError(
          'unknown return type $baseReturns for member $methodName',
        );
      }
    }
  }

  List<Method> _generateMockDataSourceMethods(GeneratorConfig config) {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final collectionName = StringUtils.pluralize(entityCamel);
    final methods = <Method>[];

    if (config.isCustomUseCase &&
        (config.paramsType != null || config.returnsType != null)) {
      final methodName = StringUtils.pascalToCamel(config.name);
      final returns = config.returnsType ?? 'void';
      final baseReturns = returns.replaceAll('?', '');
      final isList = baseReturns.startsWith('List<');

      final isStream = config.useCaseType == 'stream';
      final returnType = isStream ? 'Stream<$returns>' : 'Future<$returns>';

      // Issue #1865 review: derive the canned-value class from the
      // RETURNS type (the entity whose mock-data file is actually
      // generated), not the seam name. Fall back to a primitive value
      // for primitive returns instead of referencing a phantom mock-data
      // class.
      final primitives = <String>{
        'String',
        'int',
        'double',
        'bool',
        'void',
        'DateTime',
        'dynamic',
        'Object',
      };
      final returnsEntityTypes =
          (config.returnsType != null && config.returnsType!.isNotEmpty)
          ? EntityUtils.extractEntityTypes(config.returnsType!)
          : <String>[];
      final targetEntity = returnsEntityTypes.isNotEmpty
          ? returnsEntityTypes.first
          : entityName;
      final isPrimitiveReturn =
          primitives.contains(baseReturns) ||
          (isList &&
              primitives.contains(
                baseReturns
                    .substring(5, baseReturns.length - 1)
                    .replaceAll('?', ''),
              ));
      final mockDataClass = '${targetEntity}MockData';
      final sampleProperty = 'sample$targetEntity';

      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..annotations.add(refer('override'))
            ..returns = refer(returnType)
            ..modifier = isStream ? null : MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(config.paramsType ?? 'NoParams'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.addAll([
                  refer('logger').property('info').call([
                    literalString('$methodName called with params: \$params'),
                  ]).statement,
                  if (isStream) ...[
                    refer('Stream')
                        .property('fromFuture')
                        .call([
                          refer('Future<$returns>').property('delayed').call([
                            refer('_delay'),
                            Method(
                              (mm) => mm
                                ..lambda = true
                                ..body = isList
                                    ? (isPrimitiveReturn
                                          ? literalList([]).code
                                          : refer(
                                              mockDataClass,
                                            ).property('sampleList').code)
                                    : (baseReturns == 'void'
                                          ? refer(
                                              'Future',
                                            ).property('value').call([]).code
                                          : (isPrimitiveReturn
                                                ? _primitiveValue(
                                                    baseReturns,
                                                  ).code
                                                : refer(mockDataClass)
                                                      .property(sampleProperty)
                                                      .code)),
                            ).closure,
                          ]),
                        ])
                        .returned
                        .statement,
                  ] else ...[
                    refer('Future<void>')
                        .property('delayed')
                        .call([refer('_delay')])
                        .awaited
                        .statement,
                    if (isList) ...[
                      if (isPrimitiveReturn)
                        literalList([]).returned.statement
                      else
                        refer(
                          mockDataClass,
                        ).property('sampleList').returned.statement,
                    ] else if (baseReturns == 'void') ...[
                      refer(
                        'Future',
                      ).property('value').call([]).returned.statement,
                    ] else if (isPrimitiveReturn) ...[
                      _primitiveValue(baseReturns).returned.statement,
                    ] else ...[
                      refer(
                        mockDataClass,
                      ).property(sampleProperty).returned.statement,
                    ],
                  ],
                ]),
            ),
        ),
      );
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          final isNoParams = config.idFieldType == 'NoParams';
          methods.add(
            Method(
              (m) => m
                ..name = 'get'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      refer('logger').property('info').call([
                        literalString(
                          'Getting $entityName with params: \$params',
                        ),
                      ]).statement,
                      refer('Future<void>')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      if (isNoParams) ...[
                        declareFinal('item')
                            .assign(
                              refer(
                                '${entityName}MockData',
                              ).property('sample$entityName'),
                            )
                            .statement,
                      ] else ...[
                        declareFinal('item')
                            .assign(
                              refer('${entityName}MockData')
                                  .property(collectionName)
                                  .property('query')
                                  .call([refer('params')]),
                            )
                            .statement,
                      ],
                      refer('logger').property('info').call([
                        literalString('Successfully retrieved $entityName'),
                      ]).statement,
                      refer('item').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'list':
          methods.add(
            Method(
              (m) => m
                ..name = 'list'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<List<$entityName>>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('NoParams'),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      refer('logger').property('info').call([
                        literalString(
                          'Listing ${StringUtils.pluralize(entityName)}',
                        ),
                      ]).statement,
                      refer('Future<void>')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      refer(
                        '${entityName}MockData',
                      ).property(collectionName).returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'getList':
          methods.add(
            Method(
              (m) => m
                ..name = 'getList'
                ..annotations.add(refer('override'))
                ..returns = typeHelper.listOfFuture(entityName)
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      refer('logger').property('info').call([
                        literalString(
                          'Getting $entityName list with params: \$params',
                        ),
                      ]).statement,
                      refer('Future<void>')
                          .property('delayed')
                          .call([refer('_delay')])
                          .awaited
                          .statement,
                      declareVar('items')
                          .assign(
                            refer(
                              '${entityName}MockData',
                            ).property(collectionName),
                          )
                          .statement,
                      Code(
                        'if (params.offset != null && params.offset! > 0) { items = items.skip(params.offset!).toList(); }',
                      ),
                      Code(
                        'if (params.limit != null && params.limit! > 0) { items = items.take(params.limit!).toList(); }',
                      ),
                      refer('logger').property('info').call([
                        literalString(
                          'Successfully retrieved \${items.length} ${StringUtils.pluralize(entityName)}',
                        ),
                      ]).statement,
                      refer('items').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'create':
          final isNoParamsCreate = config.idFieldType == 'NoParams';
          // #463: the mock store must be a genuine in-memory implementation —
          // create appends the item to the backing collection so a follow-up
          // get/getList can retrieve it (the submit→get lifecycle).
          final createStatements = <Code>[
            refer('logger').property('info').call([
              isNoParamsCreate
                  ? literalString('Creating $entityName')
                  : literalString(
                      'Creating $entityName: \${item.${config.idField}}',
                    ),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
            refer('${entityName}MockData')
                .property(collectionName)
                .property('add')
                .call([refer('item')])
                .statement,
            refer('logger').property('info').call([
              isNoParamsCreate
                  ? literalString('Successfully created $entityName')
                  : literalString(
                      'Successfully created $entityName: \${item.${config.idField}}',
                    ),
            ]).statement,
          ];
          methods.add(
            Method(
              (m) => m
                ..name = 'create'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'item'
                      ..type = refer(entityName),
                  ),
                )
                ..body = Block(
                  (b) => b
                    ..statements.addAll([
                      ...createStatements,
                      refer('item').returned.statement,
                    ]),
                ),
            ),
          );
          break;

        case 'update':
          final dataType = '${entityName}Patch';
          final updateParamsType =
              'UpdateParams<${config.idFieldType}, $dataType>';
          final isNoParams = config.idFieldType == 'NoParams';
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParams
                  ? literalString('Updating $entityName')
                  : literalString('Updating $entityName: \${params.id}'),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParams) {
            // #463: persist singleton updates — apply the patch to the
            // current sample and store the result back at the head of the
            // collection.
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('sample$entityName'),
                  )
                  .statement,
              declareFinal('updated')
                  .assign(
                    refer('params').property('data').property('applyTo').call([
                      refer('existing'),
                    ]),
                  )
                  .statement,
              Code('${entityName}MockData.$collectionName[0] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          } else {
            // #463: persist updates — locate by id, apply the patch, and
            // replace the entry in the backing collection.
            final orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('notFoundFailure')
                    .call([literalString('$entityName not found in mock data')])
                    .thrown
                    .code,
            ).closure;
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer('${entityName}MockData')
                        .property(collectionName)
                        .property('firstWhere')
                        .call(
                          [
                            Method(
                              (m) => m
                                ..requiredParameters.add(
                                  Parameter((p) => p..name = 'item'),
                                )
                                ..lambda = true
                                ..body = refer('item')
                                    .property(config.idField)
                                    .equalTo(refer('params').property('id'))
                                    .code,
                            ).closure,
                          ],
                          {'orElse': orElse},
                        ),
                  )
                  .statement,
              declareFinal('updated')
                  .assign(
                    refer('params').property('data').property('applyTo').call([
                      refer('existing'),
                    ]),
                  )
                  .statement,
              declareFinal('index')
                  .assign(
                    refer('${entityName}MockData')
                        .property(collectionName)
                        .property('indexOf')
                        .call([refer('existing')]),
                  )
                  .statement,
              Code('${entityName}MockData.$collectionName[index] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully updated $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          }

          methods.add(
            Method(
              (m) => m
                ..name = 'update'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(updateParamsType),
                  ),
                )
                ..body = Block((b) => b..statements.addAll(bodyStatements)),
            ),
          );
          break;

        case 'toggle':
          // #294: the mock datasource must implement `toggle` to match
          // the datasource interface (which now defaults to including
          // toggle in its methods list). Without this case the builder
          // silently dropped toggle, producing a class that failed
          // `implements` with `non_abstract_class_inherits_abstract_member`.
          final toggleFieldEnum = 'Field<$entityName, dynamic>';
          final toggleParamsType =
              'ToggleParams<${config.idFieldType}, $toggleFieldEnum>';
          final isNoParamsToggle = config.idFieldType == 'NoParams';
          final toggleBodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParamsToggle
                  ? literalString('Toggling $entityName')
                  : literalString(
                      'Toggling $entityName: \${params.id} on field \${params.field}',
                    ),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParamsToggle) {
            toggleBodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer(
                      '${entityName}MockData',
                    ).property('sample$entityName'),
                  )
                  .statement,
              declareFinal('updated')
                  .assign(
                    refer('existing').property('copyWithField').call([
                      refer('params').property('field'),
                      refer('params').property('value'),
                    ]),
                  )
                  .statement,
              Code('${entityName}MockData.$collectionName[0] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully toggled $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          } else {
            // #463: persist toggles — locate by id, apply the field flip via
            // copyWithField, and replace the entry in the backing collection.
            final orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('notFoundFailure')
                    .call([literalString('$entityName not found in mock data')])
                    .thrown
                    .code,
            ).closure;
            toggleBodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer('${entityName}MockData')
                        .property(collectionName)
                        .property('firstWhere')
                        .call(
                          [
                            Method(
                              (m) => m
                                ..requiredParameters.add(
                                  Parameter((p) => p..name = 'item'),
                                )
                                ..lambda = true
                                ..body = refer('item')
                                    .property(config.idField)
                                    .equalTo(refer('params').property('id'))
                                    .code,
                            ).closure,
                          ],
                          {'orElse': orElse},
                        ),
                  )
                  .statement,
              declareFinal('updated')
                  .assign(
                    refer('existing').property('copyWithField').call([
                      refer('params').property('field'),
                      refer('params').property('value'),
                    ]),
                  )
                  .statement,
              declareFinal('index')
                  .assign(
                    refer('${entityName}MockData')
                        .property(collectionName)
                        .property('indexOf')
                        .call([refer('existing')]),
                  )
                  .statement,
              Code('${entityName}MockData.$collectionName[index] = updated;'),
              refer('logger').property('info').call([
                literalString('Successfully toggled $entityName'),
              ]).statement,
              refer('updated').returned.statement,
            ]);
          }

          methods.add(
            Method(
              (m) => m
                ..name = 'toggle'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(toggleParamsType),
                  ),
                )
                ..body = Block(
                  (b) => b..statements.addAll(toggleBodyStatements),
                ),
            ),
          );
          break;

        case 'delete':
          final deleteParamsType = 'DeleteParams<${config.idFieldType}>';
          final isNoParams = config.idFieldType == 'NoParams';
          final bodyStatements = <Code>[
            refer('logger').property('info').call([
              isNoParams
                  ? literalString('Deleting $entityName')
                  : literalString('Deleting $entityName: \${params.id}'),
            ]).statement,
            refer(
              'Future<void>',
            ).property('delayed').call([refer('_delay')]).awaited.statement,
          ];

          if (isNoParams) {
            bodyStatements.addAll([
              refer('logger').property('info').call([
                literalString('Successfully deleted $entityName'),
              ]).statement,
            ]);
          } else {
            // #463: persist deletes — locate by id (throws notFoundFailure
            // when absent) and remove the entry from the backing collection.
            final orElse = Method(
              (m) => m
                ..lambda = true
                ..body = refer('notFoundFailure')
                    .call([literalString('$entityName not found in mock data')])
                    .thrown
                    .code,
            ).closure;
            bodyStatements.addAll([
              declareFinal('existing')
                  .assign(
                    refer('${entityName}MockData')
                        .property(collectionName)
                        .property('firstWhere')
                        .call(
                          [
                            Method(
                              (m) => m
                                ..requiredParameters.add(
                                  Parameter((p) => p..name = 'item'),
                                )
                                ..lambda = true
                                ..body = refer('item')
                                    .property(config.idField)
                                    .equalTo(refer('params').property('id'))
                                    .code,
                            ).closure,
                          ],
                          {'orElse': orElse},
                        ),
                  )
                  .statement,
              refer('${entityName}MockData')
                  .property(collectionName)
                  .property('remove')
                  .call([refer('existing')])
                  .statement,
              refer('logger').property('info').call([
                literalString('Successfully deleted $entityName'),
              ]).statement,
            ]);
          }

          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..annotations.add(refer('override'))
                ..returns = typeHelper.futureVoidType()
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(deleteParamsType),
                  ),
                )
                ..body = Block((b) => b..statements.addAll(bodyStatements)),
            ),
          );
          break;

        case 'watch':
          final isNoParamsWatch = config.idFieldType == 'NoParams';
          methods.add(
            Method(
              (m) => m
                ..name = 'watch'
                ..annotations.add(refer('override'))
                ..returns = refer('Stream<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..body = refer('Stream')
                    .property('periodic')
                    .call([
                      refer(
                        'Duration',
                      ).constInstance(const [], {'seconds': literalNum(2)}),
                      Method(
                        (m) => m
                          ..requiredParameters.add(
                            Parameter((p) => p..name = 'count'),
                          )
                          ..lambda = true
                          ..body = isNoParamsWatch
                              ? refer(
                                  '${entityName}MockData',
                                ).property('sample$entityName').code
                              : refer('${entityName}MockData')
                                    .property(collectionName)
                                    .property('query')
                                    .call([refer('params')])
                                    .code,
                      ).closure,
                    ])
                    .property('take')
                    .call([literalNum(10)])
                    .returned
                    .statement,
            ),
          );
          break;

        case 'watchList':
          methods.add(
            Method(
              (m) => m
                ..name = 'watchList'
                ..annotations.add(refer('override'))
                ..returns = typeHelper.listOfStream(entityName)
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..body = refer('Stream')
                    .property('periodic')
                    .call([
                      refer(
                        'Duration',
                      ).constInstance(const [], {'seconds': literalNum(2)}),
                      Method(
                        (m) => m
                          ..requiredParameters.add(
                            Parameter((p) => p..name = 'count'),
                          )
                          ..body = Block(
                            (b) => b
                              ..statements.addAll([
                                declareVar('items')
                                    .assign(
                                      refer(
                                        '${entityName}MockData',
                                      ).property(collectionName),
                                    )
                                    .statement,
                                Code(
                                  'if (params.offset != null && params.offset! > 0) { items = items.skip(params.offset!).toList(); }',
                                ),
                                Code(
                                  'if (params.limit != null && params.limit! > 0) { items = items.take(params.limit!).toList(); }',
                                ),
                                refer('items').returned.statement,
                              ]),
                          ),
                      ).closure,
                    ])
                    .property('take')
                    .call([literalNum(5)])
                    .returned
                    .statement,
            ),
          );
          break;
        default:
          // Issue #1823 / #1850: arbitrary (non-CRUD) verbs declared via
          // --methods. A method token may carry its own shape as
          // `name:params->returns` (issue #1850 "named members"); tokens
          // without a shape fall back to the call-wide --params/--returns.
          {
            final parsed = _parseMethodShape(method);
            final methodName = parsed.$1;
            final methodParams = parsed.$2 ?? config.paramsType;
            final methodReturns = parsed.$3 ?? config.returnsType;
            final returns = (methodReturns != null && methodReturns.isNotEmpty)
                ? methodReturns
                : 'void';
            final baseReturns = _baseReturnType(returns);
            final isVoid = baseReturns == 'void' || baseReturns == 'dynamic';
            // Issue #1824 review: branch on list-ness and entity-ness so a
            // non-void arbitrary verb does not always return a single entity
            // (which fails `return_of_invalid_type` for List<T>/primitives).
            final isList =
                baseReturns.startsWith('List<') && baseReturns.endsWith('>');
            final listInner = isList
                ? baseReturns.substring(5, baseReturns.length - 1).trim()
                : '';
            final isEntityList = isList && listInner == entityName;
            final isEntityReturn = baseReturns == entityName;
            // Issue #1928: a return type that names a real on-disk entity
            // (including one whose public class lives in a Zorphy `part`
            // file, e.g. ZikZakPage) is a known type even when it is not
            // the datasource's own entity. Resolve by file existence rather
            // than by class declaration in the main file.
            final paramsType = (methodParams != null && methodParams.isNotEmpty)
                ? methodParams
                : 'NoParams';
            final hasParams = paramsType != 'NoParams';
            final returnType =
                returns.startsWith('Future<') || returns.startsWith('Stream<')
                ? returns
                : 'Future<$returns>';
            final futureReturnType = returnType; // returnType already wrapped
            // Issue #1923: a foreign entity that wraps a list of the
            // subject (`items: List<$entityName>`) IS derivable from the
            // subject's fixture set — the paginated-store shape. An honest
            // paged read is synthesized below; every other foreign return
            // keeps the #1850 refusal.
            final foreignPage = !isVoid && !isEntityList && !isEntityReturn
                ? _deriveForeignPageShape(
                    entityName: entityName,
                    foreignType: baseReturns,
                    paramsType: paramsType,
                  )
                : null;
            // Issue #1850 (honest bodies): a non-void arbitrary verb whose
            // return type resolves to no known fixture must refuse rather
            // than emit `throw UnimplementedError()` under a conformance:
            // true verdict. Issue #1923 narrows "known fixture" to include
            // a foreign paged wrapper over the subject fixture.
            if (!isVoid &&
                !isEntityList &&
                !isEntityReturn &&
                foreignPage == null) {
              throw ArgumentError(
                'unknown return type $baseReturns for member $methodName',
              );
            }
            methods.add(
              Method(
                (m) => m
                  ..name = methodName
                  ..annotations.add(refer('override'))
                  ..returns = refer(futureReturnType)
                  ..modifier = MethodModifier.async
                  ..requiredParameters.addAll(
                    hasParams
                        ? [
                            Parameter(
                              (pp) => pp
                                ..name = 'params'
                                ..type = refer(paramsType),
                            ),
                          ]
                        : const <Parameter>[],
                  )
                  ..body = Block(
                    (b) => b
                      ..statements.addAll([
                        refer('logger').property('info').call([
                          literalString('$methodName called'),
                        ]).statement,
                        refer('Future<void>')
                            .property('delayed')
                            .call([refer('_delay')])
                            .awaited
                            .statement,
                        if (isVoid)
                          refer(
                            'Future',
                          ).property('value').call([]).returned.statement
                        else if (isEntityList)
                          refer(
                            '${entityName}MockData',
                          ).property('sampleList').returned.statement
                        else if (isEntityReturn)
                          refer(
                            '${entityName}MockData',
                          ).property('sample$entityName').returned.statement
                        else if (foreignPage != null)
                          ..._foreignPageStatements(
                            entityName: entityName,
                            foreignType: baseReturns,
                            shape: foreignPage,
                          )
                        else
                          Code('throw UnimplementedError();'),
                      ]),
                  ),
              ),
            );
          }
          break;
      }
    }

    return methods;
  }

  /// Issue #1923: resolves the honest body shape for a foreign-entity
  /// return that the fixture set can feed — the paginated-store wrapper.
  ///
  /// The shape is derivable only when ALL of the following hold:
  ///   * the member takes `ListQueryParams<...>` (the paging inputs);
  ///   * the foreign entity's source exists and parses;
  ///   * it declares exactly one field typed `List<$entityName>` — the
  ///     slice source, filled from `<Subject>MockData.<plural>`;
  ///   * it declares a `hasMore` bool (or exactly one bool field);
  ///   * every other field is nullable (constructed as `null`).
  ///
  /// Anything else returns null, and the caller keeps the #1850 refusal
  /// rather than inventing a body.
  ({String listField, String hasMoreField, List<String> nullableFields})?
  _deriveForeignPageShape({
    required String entityName,
    required String foreignType,
    required String paramsType,
  }) {
    if (!paramsType.startsWith('ListQueryParams<')) return null;
    if (!EntityAnalyzer.entityFileExists(
      foreignType,
      outputDir,
      fileSystem: fileSystem,
    )) {
      return null;
    }
    final fields = EntityAnalyzer.analyzeEntity(
      foreignType,
      outputDir,
      fileSystem: fileSystem,
    );
    if (fields.isEmpty) return null;

    String normalize(String type) =>
        type.replaceAll('?', '').replaceAll(' ', '').trim();

    final listFields = fields.entries
        .where((entry) => normalize(entry.value) == 'List<$entityName>')
        .map((entry) => entry.key)
        .toList();
    if (listFields.length != 1) return null;

    final boolFields = fields.entries
        .where((entry) => normalize(entry.value) == 'bool')
        .map((entry) => entry.key)
        .toList();
    if (boolFields.isEmpty) return null;
    final String hasMoreField;
    if (boolFields.contains('hasMore')) {
      hasMoreField = 'hasMore';
    } else if (boolFields.length == 1) {
      hasMoreField = boolFields.single;
    } else {
      // Several bool fields and no `hasMore` — which one is the page flag is
      // not derivable, so the seam falls back to the honest refusal.
      return null;
    }

    final nullableFields = <String>[];
    for (final entry in fields.entries) {
      if (entry.key == listFields.single || entry.key == hasMoreField) {
        continue;
      }
      if (!entry.value.trim().endsWith('?')) return null;
      nullableFields.add(entry.key);
    }

    return (
      listField: listFields.single,
      hasMoreField: hasMoreField,
      nullableFields: nullableFields,
    );
  }

  /// Issue #1923: the honest paged-read body shared by the arbitrary-verb
  /// generator and the shape-drift repair — a real slice of the subject
  /// fixture list, wrapped in the foreign entity with a computed `hasMore`.
  List<Code> _foreignPageStatements({
    required String entityName,
    required String foreignType,
    required ({
      String listField,
      String hasMoreField,
      List<String> nullableFields,
    })
    shape,
  }) {
    final entityCamel = StringUtils.pascalToCamel(entityName);
    return [
      Code('''
final items = ${entityName}MockData.${entityCamel}s;
var offset = params.offset ?? 0;
if (offset < 0) offset = 0;
if (offset > items.length) offset = items.length;
var limit = params.limit ?? items.length;
if (limit < 0) limit = 0;
if (limit > items.length) limit = items.length;
final page = items.skip(offset).take(limit).toList();
'''),
      refer(foreignType)
          .call([], {
            shape.listField: refer('page'),
            shape.hasMoreField: refer('offset + page.length < items.length'),
            for (final field in shape.nullableFields) field: literalNull,
          })
          .returned
          .statement,
    ];
  }

  Expression _primitiveValue(String type) {
    switch (type) {
      case 'String':
        return literalString('mock_value');
      case 'int':
        return literalNum(1);
      case 'double':
        return literalNum(1.0);
      case 'bool':
        return literalBool(true);
      case 'DateTime':
        return refer('DateTime').property('now').call([]);
      default:
        return literalNull;
    }
  }
}
