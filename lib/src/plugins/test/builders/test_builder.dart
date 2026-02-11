import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class TestBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  TestBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final repoName = config.effectiveRepos.first;

    String className;
    String returnTypeConstructor = '';
    bool isStream = false;
    bool isCompletable = false;

    switch (method) {
      case 'get':
        className = 'Get${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        break;
      case 'getList':
        className = 'Get${entityName}ListUseCase';
        returnTypeConstructor = 't${entityName}List';
        break;
      case 'create':
        className = 'Create${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        returnTypeConstructor = 'null';
        isCompletable = true;
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        returnTypeConstructor = 't${entityName}List';
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final fileSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );
    final fileName = '${fileSnake}_usecase_test.dart';

    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(entitySnake);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    String useCaseFileName;
    if (method == 'getList') {
      useCaseFileName = 'get_${entitySnake}_list_usecase.dart';
    } else if (method == 'watchList') {
      useCaseFileName = 'watch_${entitySnake}_list_usecase.dart';
    } else {
      useCaseFileName =
          '${StringUtils.camelToSnake(method)}_${entitySnake}_usecase.dart';
    }

    final packageName = _resolvePackageName(projectRoot);
    final repoSnake = StringUtils.camelToSnake(
      repoName.replaceAll('Repository', ''),
    );

    final directives = [
      Directive.import('package:flutter_test/flutter_test.dart'),
      Directive.import('package:mocktail/mocktail.dart'),
      if (method != 'create') Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        'package:$packageName/src/domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import(
        'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart',
      ),
      Directive.import(
        'package:$packageName/src/domain/usecases/$entitySnake/$useCaseFileName',
      ),
    ];

    final mockRepoClass = 'Mock$repoName';
    final mockEntityClass = 'Mock$entityName';

    final mockRepo = Class(
      (c) => c
        ..name = mockRepoClass
        ..extend = refer('Mock')
        ..implements.add(refer(repoName)),
    );

    final mockEntity = Class(
      (c) => c
        ..name = mockEntityClass
        ..extend = refer('Mock')
        ..implements.add(refer(entityName)),
    );

    final mainMethod = Method(
      (m) => m
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block((b) {
          b.statements.add(
            declareVar('useCase', type: refer(className), late: true).statement,
          );
          b.statements.add(
            declareVar(
              'mockRepository',
              type: refer(mockRepoClass),
              late: true,
            ).statement,
          );

          final setUpBody = Block((s) {
            final fallbackValues = _getFallbackValues(
              config,
              method,
              mockEntityClass,
            );
            for (final val in fallbackValues) {
              s.statements.add(
                refer('registerFallbackValue').call([val]).statement,
              );
            }
            s.statements.add(
              refer(
                'mockRepository',
              ).assign(refer(mockRepoClass).call([])).statement,
            );
            s.statements.add(
              refer('useCase')
                  .assign(refer(className).call([refer('mockRepository')]))
                  .statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            if (method != 'delete') {
              g.statements.add(
                declareFinal(
                  't$entityName',
                ).assign(refer(mockEntityClass).call([])).statement,
              );
            }

            if (![
              'get',
              'create',
              'delete',
              'watch',
              'update',
            ].contains(method)) {
              if (['getList', 'watchList'].contains(method)) {
                g.statements.add(
                  declareFinal(
                    't${entityName}List',
                  ).assign(literalList([refer('t$entityName')])).statement,
                );
              }
            }

            final tests = isStream
                ? _generateStreamTests(
                    config,
                    method,
                    entityName,
                    returnTypeConstructor,
                  )
                : _generateFutureTests(
                    config,
                    method,
                    entityName,
                    returnTypeConstructor,
                    isCompletable,
                  );

            g.statements.addAll(tests);
          });

          b.statements.add(
            refer(
              'group',
            ).call([literalString(className), groupBody.toClosure()]).statement,
          );
        }),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [mockRepo, mockEntity, mainMethod],
        directives: directives,
      ),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> generateCustom(GeneratorConfig config) async {
    final useCaseName = '${config.name}UseCase';
    final useCaseType = config.useCaseType;
    final paramsType = config.paramsType ?? 'NoParams';
    final fileName = '${config.nameSnake}_usecase_test.dart';

    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(config.effectiveDomain);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    final packageName = _resolvePackageName(projectRoot);

    final directives = [
      Directive.import('package:flutter_test/flutter_test.dart'),
      Directive.import('package:mocktail/mocktail.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${config.nameSnake}_usecase.dart',
      ),
    ];

    final mockSpecs = <Class>[];
    for (final repo in config.effectiveRepos) {
      mockSpecs.add(
        Class(
          (c) => c
            ..name = 'Mock$repo'
            ..extend = refer('Mock')
            ..implements.add(refer(repo)),
        ),
      );

      final repoSnake = StringUtils.camelToSnake(
        repo.replaceAll('Repository', ''),
      );
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart',
        ),
      );
    }

    final mainMethod = Method(
      (m) => m
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block((b) {
          b.statements.add(
            declareVar(
              'useCase',
              type: refer(useCaseName),
              late: true,
            ).statement,
          );
          for (final repo in config.effectiveRepos) {
            b.statements.add(
              declareVar(
                'mock$repo',
                type: refer('Mock$repo'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            s.statements.add(
              refer('registerFallbackValue').call([
                refer(
                  'ListQueryParams',
                ).constInstance(const [], const {}, [refer('dynamic')]),
              ]).statement,
            );
            for (final repo in config.effectiveRepos) {
              s.statements.add(
                refer(
                  'mock$repo',
                ).assign(refer('Mock$repo').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call(
                      config.effectiveRepos
                          .map((r) => refer('mock$r'))
                          .toList(),
                    ),
                  )
                  .statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            final testCall = _generateCustomTestBody(
              config,
              paramsType,
              useCaseType,
            );
            g.statements.add(testCall.statement);
          });

          b.statements.add(
            refer('group').call([
              literalString(useCaseName),
              groupBody.toClosure(),
            ]).statement,
          );
        }),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [...mockSpecs, mainMethod],
        directives: directives,
      ),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> generateOrchestrator(GeneratorConfig config) async {
    final useCaseName = '${config.name}UseCase';
    final fileName = '${config.nameSnake}_usecase_test.dart';

    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(config.effectiveDomain);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    final packageName = _resolvePackageName(projectRoot);

    final directives = [
      Directive.import('package:flutter_test/flutter_test.dart'),
      Directive.import('package:mocktail/mocktail.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${config.nameSnake}_usecase.dart',
      ),
    ];

    final mockSpecs = <Class>[];
    for (final usecase in config.usecases) {
      mockSpecs.add(
        Class(
          (c) => c
            ..name = 'Mock${usecase}UseCase'
            ..extend = refer('Mock')
            ..implements.add(refer('${usecase}UseCase')),
        ),
      );

      final usecaseSnake = StringUtils.camelToSnake(usecase);
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/usecases/$usecaseSnake/${usecaseSnake}_usecase.dart',
        ),
      );
    }

    final mainMethod = Method(
      (m) => m
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block((b) {
          b.statements.add(
            declareVar(
              'useCase',
              type: refer(useCaseName),
              late: true,
            ).statement,
          );
          for (final usecase in config.usecases) {
            b.statements.add(
              declareVar(
                'mock${usecase}UseCase',
                type: refer('Mock${usecase}UseCase'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            for (final usecase in config.usecases) {
              s.statements.add(
                refer(
                  'mock${usecase}UseCase',
                ).assign(refer('Mock${usecase}UseCase').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call(
                      config.usecases
                          .map((u) => refer('mock${u}UseCase'))
                          .toList(),
                    ),
                  )
                  .statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            final paramsType = config.paramsType ?? 'NoParams';
            final callArgs = paramsType == 'NoParams'
                ? refer('NoParams').constInstance([])
                : refer('params');

            final testBody = Block((t) {
              t.statements.add(const Code('// Arrange'));
              t.statements.add(
                const Code('// TODO: Mock returns from child usecases'),
              );
              t.statements.add(const Code(''));
              t.statements.add(const Code('// Act'));
              t.statements.add(
                declareFinal(
                  'result',
                ).assign(refer('useCase').call([callArgs]).awaited).statement,
              );
              t.statements.add(const Code(''));
              t.statements.add(const Code('// Assert'));
              t.statements.add(
                refer('expect').call([
                  refer('result'),
                  refer('isA').call([], {}, [refer('Success')]),
                ]).statement,
              );
            });

            g.statements.add(
              refer('test').call([
                literalString('should orchestrate all usecases'),
                testBody.toClosure(asAsync: true),
              ]).statement,
            );
          });

          b.statements.add(
            refer('group').call([
              literalString(useCaseName),
              groupBody.toClosure(),
            ]).statement,
          );
        }),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [...mockSpecs, mainMethod],
        directives: directives,
      ),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<List<GeneratedFile>> generatePolymorphic(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];
    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(config.effectiveDomain);
    final testDirPath = path.joinAll(testPathParts);

    final packageName = _resolvePackageName(projectRoot);

    for (final variant in config.variants) {
      final className = '${config.name}${variant}UseCase';
      final classSnake = StringUtils.camelToSnake('${config.name}$variant');
      final fileName = '${classSnake}_usecase_test.dart';
      final filePath = path.join(testDirPath, fileName);

      final directives = [
        Directive.import('package:flutter_test/flutter_test.dart'),
        Directive.import('package:mocktail/mocktail.dart'),
        Directive.import('package:zuraffa/zuraffa.dart'),
        Directive.import(
          'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${classSnake}_usecase.dart',
        ),
      ];

      final mockSpecs = <Class>[];
      if (config.repo != null) {
        final repoName = '${config.repo}Repository';
        mockSpecs.add(
          Class(
            (c) => c
              ..name = 'Mock$repoName'
              ..extend = refer('Mock')
              ..implements.add(refer(repoName)),
          ),
        );

        final repoSnake = StringUtils.camelToSnake(
          config.repo!.replaceAll('Repository', ''),
        );
        directives.add(
          Directive.import(
            'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart',
          ),
        );
      }

      final mainMethod = Method(
        (m) => m
          ..name = 'main'
          ..returns = refer('void')
          ..body = Block((b) {
            b.statements.add(
              declareVar(
                'useCase',
                type: refer(className),
                late: true,
              ).statement,
            );
            if (config.repo != null) {
              b.statements.add(
                declareVar(
                  'mock${config.repo}Repository',
                  type: refer('Mock${config.repo}Repository'),
                  late: true,
                ).statement,
              );
            }

            final setUpBody = Block((s) {
              if (config.repo != null) {
                s.statements.add(
                  refer('mock${config.repo}Repository')
                      .assign(refer('Mock${config.repo}Repository').call([]))
                      .statement,
                );
              }
              final setupArgs = config.repo != null
                  ? [refer('mock${config.repo}Repository')]
                  : <Expression>[];
              s.statements.add(
                refer(
                  'useCase',
                ).assign(refer(className).call(setupArgs)).statement,
              );
            });

            b.statements.add(
              refer('setUp').call([setUpBody.toClosure()]).statement,
            );

            final groupBody = Block((g) {
              final paramsType = config.paramsType ?? 'NoParams';
              final callArgs = paramsType == 'NoParams'
                  ? refer('NoParams').constInstance([])
                  : refer('params');

              final testBody = Block((t) {
                t.statements.add(const Code('// Arrange'));
                t.statements.add(
                  const Code('// TODO: Mock return from repository'),
                );
                t.statements.add(const Code(''));
                t.statements.add(const Code('// Act'));
                if (config.useCaseType == 'stream') {
                  t.statements.add(
                    declareFinal(
                      'result',
                    ).assign(refer('useCase').call([callArgs])).statement,
                  );
                  t.statements.add(const Code(''));
                  t.statements.add(const Code('// Assert'));
                  t.statements.add(
                    refer('expectLater')
                        .call([
                          refer('result'),
                          refer('emits').call([
                            refer('isA').call([], {}, [refer('Success')]),
                          ]),
                        ])
                        .awaited
                        .statement,
                  );
                } else {
                  t.statements.add(
                    declareFinal('result')
                        .assign(refer('useCase').call([callArgs]).awaited)
                        .statement,
                  );
                  t.statements.add(const Code(''));
                  t.statements.add(const Code('// Assert'));
                  t.statements.add(
                    refer('expect').call([
                      refer('result'),
                      refer('isA').call([], {}, [refer('Success')]),
                    ]).statement,
                  );
                }
              });

              g.statements.add(
                refer('test').call([
                  literalString(
                    config.useCaseType == 'stream'
                        ? 'should emit values from stream'
                        : 'should return Success',
                  ),
                  testBody.toClosure(asAsync: true),
                ]).statement,
              );
            });

            b.statements.add(
              refer('group').call([
                literalString(className),
                groupBody.toClosure(),
              ]).statement,
            );
          }),
      );

      final content = specLibrary.emitLibrary(
        specLibrary.library(
          specs: [...mockSpecs, mainMethod],
          directives: directives,
        ),
      );

      final file = await FileUtils.writeFile(
        filePath,
        content,
        'test',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      );
      files.add(file);
    }

    return files;
  }

  String _resolvePackageName(String projectRoot) {
    String packageName = 'your_app';
    try {
      final pubspecFile = File(path.join(projectRoot, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final lines = pubspecFile.readAsLinesSync();
        for (final line in lines) {
          if (line.trim().startsWith('name:')) {
            packageName = line.split(':')[1].trim();
            break;
          }
        }
      }
    } catch (_) {}
    return packageName;
  }

  List<Expression> _getFallbackValues(
    GeneratorConfig config,
    String method,
    String mockEntityClass,
  ) {
    final entityName = config.name;
    final idType = config.idType;
    final idValue = idType == 'int' ? literalNum(1) : literalString('1');

    switch (method) {
      case 'get':
      case 'watch':
        return [refer('QueryParams<$entityName>').constInstance([])];
      case 'getList':
      case 'watchList':
        return [refer('ListQueryParams<$entityName>').constInstance([])];
      case 'create':
        return [refer(mockEntityClass).call([])];
      case 'update':
        final dataType = config.useZorphy
            ? '${entityName}Patch'
            : 'Partial<$entityName>';
        final dataValue = config.useZorphy
            ? refer('${entityName}Patch').call([])
            : refer('Partial<$entityName>').call([]);
        return [
          refer(
            'UpdateParams<$idType, $dataType>',
          ).call([], {'id': idValue, 'data': dataValue}),
        ];
      case 'delete':
        return [
          refer('DeleteParams<$idType>').constInstance([], {'id': idValue}),
        ];
      default:
        return [];
    }
  }

  List<Code> _generateFutureTests(
    GeneratorConfig config,
    String method,
    String entityName,
    String returnConstructor,
    bool isCompletable,
  ) {
    final idType = config.idType;
    final idValue = idType == 'int' ? literalNum(1) : literalString('1');

    Expression paramsExpr;
    Expression arrangeCall;
    Expression verifyCall;
    Expression failureArrangeCall;

    if (method == 'get') {
      if (idType == 'NoParams') {
        paramsExpr = refer('NoParams').call([]);
        arrangeCall = refer(
          'mockRepository',
        ).property('get').call([refer('QueryParams').constInstance([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('get').call([refer('QueryParams').constInstance([])]);
      } else {
        paramsExpr = config.useZorphy
            ? refer('QueryParams<$entityName>').call([], {
                'filter': refer('Eq').call([
                  refer('${entityName}Fields').property(config.queryField),
                  literalString('1'),
                ]),
              })
            : refer('QueryParams<$entityName>').call([], {
                'params': refer('Params').call([
                  literalMap({config.queryField: literalString('1')}),
                ]),
              });
        arrangeCall = refer(
          'mockRepository',
        ).property('get').call([refer('any').call([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('get').call([refer('any').call([])]);
      }
    } else if (method == 'getList') {
      paramsExpr = refer('ListQueryParams<$entityName>').call([]);
      arrangeCall = refer(
        'mockRepository',
      ).property('getList').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('getList').call([refer('any').call([])]);
    } else if (method == 'create') {
      paramsExpr = refer('t$entityName');
      arrangeCall = refer(
        'mockRepository',
      ).property('create').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('create').call([refer('any').call([])]);
    } else if (method == 'update') {
      final dataType = config.useZorphy
          ? '${entityName}Patch'
          : 'Partial<$entityName>';
      final dataValue = config.useZorphy
          ? refer('${entityName}Patch').call([])
          : refer('Partial<$entityName>').call([]);
      paramsExpr = refer(
        'UpdateParams<$idType, $dataType>',
      ).call([], {'id': idValue, 'data': dataValue});
      arrangeCall = refer(
        'mockRepository',
      ).property('update').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('update').call([refer('any').call([])]);
    } else if (method == 'delete') {
      paramsExpr = refer('DeleteParams<$idType>').call([], {'id': idValue});
      arrangeCall = refer(
        'mockRepository',
      ).property('delete').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('delete').call([refer('any').call([])]);
    } else {
      return [];
    }

    if (method != 'create' && method != 'update') {
      // paramsExpr = paramsExpr.constInstance([]); // tricky if it was already built
    }

    failureArrangeCall = arrangeCall;

    final successTest = Block((t) {
      t.statements.add(
        refer(
          'when',
        ).call([arrangeCall.toClosure()]).property('thenAnswer').call([
          Method(
            (m) => m
              ..requiredParameters.add(Parameter((p) => p..name = '_'))
              ..modifier = MethodModifier.async
              ..lambda = true
              ..body =
                  (method == 'delete'
                          ? literalMap({})
                          : refer(returnConstructor))
                      .code,
          ).closure,
        ]).statement,
      );
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr]).awaited).statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
      t.statements.add(
        refer('expect').call([
          refer('result').property('isSuccess'),
          literalBool(true),
        ]).statement,
      );
      if (!isCompletable) {
        t.statements.add(
          refer('expect').call([
            refer('result').property('getOrElse').call([
              Method(
                (m) => m
                  ..lambda = true
                  ..body = refer(
                    'throw',
                  ).call([refer('Exception').call([])]).code,
              ).closure,
            ]),
            refer('equals').call([refer(returnConstructor)]),
          ]).statement,
        );
      }
    });

    final failureTest = Block((t) {
      t.statements.add(
        declareFinal(
          'exception',
        ).assign(refer('Exception').call([literalString('Error')])).statement,
      );
      t.statements.add(
        refer('when')
            .call([failureArrangeCall.toClosure()])
            .property('thenThrow')
            .call([refer('exception')])
            .statement,
      );
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr]).awaited).statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
      t.statements.add(
        refer('expect').call([
          refer('result').property('isFailure'),
          literalBool(true),
        ]).statement,
      );
    });

    return [
      refer('test').call([
        literalString('should call repository.$method and return result'),
        successTest.toClosure(asAsync: true),
      ]).statement,
      const Code(''),
      refer('test').call([
        literalString('should return Failure when repository throws'),
        failureTest.toClosure(asAsync: true),
      ]).statement,
    ];
  }

  List<Code> _generateStreamTests(
    GeneratorConfig config,
    String method,
    String entityName,
    String returnConstructor,
  ) {
    final idType = config.idType;

    Expression paramsExpr;
    Expression arrangeCall;
    Expression verifyCall;

    if (method == 'watch') {
      if (idType == 'NoParams') {
        paramsExpr = refer('NoParams').call([]);
        arrangeCall = refer(
          'mockRepository',
        ).property('watch').call([refer('QueryParams').constInstance([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('watch').call([refer('QueryParams').constInstance([])]);
      } else {
        paramsExpr = config.useZorphy
            ? refer('QueryParams<$entityName>').call([], {
                'filter': refer('Eq').call([
                  refer('${entityName}Fields').property(config.queryField),
                  literalString('1'),
                ]),
              })
            : refer('QueryParams<$entityName>').call([], {
                'params': refer('Params').call([
                  literalMap({config.queryField: literalString('1')}),
                ]),
              });
        arrangeCall = refer(
          'mockRepository',
        ).property('watch').call([refer('any').call([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('watch').call([refer('any').call([])]);
      }
    } else if (method == 'watchList') {
      paramsExpr = refer('ListQueryParams<$entityName>').call([]);
      arrangeCall = refer(
        'mockRepository',
      ).property('watchList').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('watchList').call([refer('any').call([])]);
    } else {
      return [];
    }

    final successTest = Block((t) {
      final arrangeCallExpr = refer('when')
          .call([arrangeCall.toClosure()])
          .property('thenAnswer')
          .call([
            Method(
              (m) => m
                ..requiredParameters.add(Parameter((p) => p..name = '_'))
                ..lambda = true
                ..body = refer(
                  'Stream',
                ).property('value').call([refer(returnConstructor)]).code,
            ).closure,
          ]);
      t.statements.add(arrangeCallExpr.statement);
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr])).statement,
      );
      t.statements.add(
        refer('expectLater')
            .call([
              refer('result'),
              refer('emits').call([
                refer(
                  'isA',
                ).call([], {}, [refer('Success')]).property('having').call([
                  Method(
                    (m) => m
                      ..requiredParameters.add(Parameter((p) => p..name = 's'))
                      ..lambda = true
                      ..body = refer('s').property('value').code,
                  ).closure,
                  literalString('value'),
                  refer('equals').call([refer(returnConstructor)]),
                ]),
              ]),
            ])
            .awaited
            .statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
    });

    final failureTest = Block((t) {
      t.statements.add(
        declareFinal('exception')
            .assign(refer('Exception').call([literalString('Stream Error')]))
            .statement,
      );
      final arrangeCallExpr = refer('when')
          .call([arrangeCall.toClosure()])
          .property('thenAnswer')
          .call([
            Method(
              (m) => m
                ..requiredParameters.add(Parameter((p) => p..name = '_'))
                ..lambda = true
                ..body = refer(
                  'Stream',
                ).property('error').call([refer('exception')]).code,
            ).closure,
          ]);
      t.statements.add(arrangeCallExpr.statement);
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr])).statement,
      );
      t.statements.add(
        refer('expectLater')
            .call([
              refer('result'),
              refer('emits').call([
                refer('isA').call([], {}, [refer('Failure')]),
              ]),
            ])
            .awaited
            .statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
    });

    return [
      refer('test').call([
        literalString('should emit values from repository stream'),
        successTest.toClosure(asAsync: true),
      ]).statement,
      const Code(''),
      refer('test').call([
        literalString('should emit Failure when repository stream errors'),
        failureTest.toClosure(asAsync: true),
      ]).statement,
    ];
  }

  Expression _generateCustomTestBody(
    GeneratorConfig config,
    String paramsType,
    String useCaseType,
  ) {
    final callArgs = paramsType == 'NoParams'
        ? refer('NoParams').constInstance([])
        : <Expression>[];

    final testContent = Block((t) {
      t.statements.add(const Code('// Arrange'));
      t.statements.add(const Code('// TODO: Mock return from repositories'));
      t.statements.add(const Code(''));
      t.statements.add(const Code('// Act'));

      if (useCaseType == 'background') {
        final args = callArgs is List<Expression>
            ? callArgs
            : [callArgs as Expression];
        t.statements.add(
          declareFinal(
            'result',
          ).assign(refer('useCase').property('buildTask').call(args)).statement,
        );
        t.statements.add(const Code(''));
        t.statements.add(const Code('// Assert'));
        t.statements.add(
          refer('expect').call([
            refer('result'),
            refer('isA').call([], {}, [refer('BackgroundTask')]),
          ]).statement,
        );
      } else if (useCaseType == 'stream') {
        final args = callArgs is List<Expression>
            ? callArgs
            : [callArgs as Expression];
        t.statements.add(
          declareFinal('result').assign(refer('useCase').call(args)).statement,
        );
        t.statements.add(const Code(''));
        t.statements.add(const Code('// Assert'));
        t.statements.add(
          refer('expectLater')
              .call([
                refer('result'),
                refer('emits').call([
                  refer('isA').call([], {}, [refer('Success')]),
                ]),
              ])
              .awaited
              .statement,
        );
      } else {
        final args = callArgs is List<Expression>
            ? callArgs
            : [callArgs as Expression];
        t.statements.add(
          declareFinal(
            'result',
          ).assign(refer('useCase').call(args).awaited).statement,
        );
        t.statements.add(const Code(''));
        t.statements.add(const Code('// Assert'));
        t.statements.add(
          refer('expect').call([
            refer('result').property('isSuccess'),
            literalBool(true),
          ]).statement,
        );
      }
    });

    return refer('test').call([
      literalString(
        useCaseType == 'stream'
            ? 'should emit values from stream'
            : 'should return Success',
      ),
      testContent.toClosure(asAsync: true),
    ]);
  }
}

extension on Expression {
  Expression toClosure({bool asAsync = false}) {
    return Method(
      (m) => m
        ..body = code
        ..modifier = asAsync ? MethodModifier.async : null,
    ).closure;
  }
}

extension on Code {
  Expression toClosure({bool asAsync = false}) {
    return Method(
      (m) => m
        ..body = this
        ..modifier = asAsync ? MethodModifier.async : null,
    ).closure;
  }
}
