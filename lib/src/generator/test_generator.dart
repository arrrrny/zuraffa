import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

class TestGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  TestGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  Future<GeneratedFile> generateForMethod(String method) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final repoName = config.effectiveRepos.first;

    // Test folders are often mirrors of lib, but let's assume standard flutter test location
    // test/domain/usecases/entity/...

    String className;
    String returnTypeConstructor = ''; // e.g. tTodo
    bool isStream = false;
    bool isCompletable = false;
    bool needsEntityImport = true;

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

    final fileSnake =
        StringUtils.camelToSnake(className.replaceAll('UseCase', ''));
    final fileName = '${fileSnake}_usecase_test.dart';

    // Construct path: test/domain/usecases/entity_name/...
    // Note: outputDir is usually lib/src, so we need to navigate out to test/

    // We'll create a new path for tests based on standard convention
    final projectRoot = outputDir.replaceAll('lib/src', '');

    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    if (config.subdirectory != null && config.subdirectory!.isNotEmpty) {
      testPathParts.add(config.subdirectory!);
    }
    testPathParts.add(entitySnake);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    // Determine the correct usecase filename based on method
    String useCaseFileName;
    if (method == 'getList') {
      useCaseFileName = 'get_${entitySnake}_list_usecase.dart';
    } else if (method == 'watchList') {
      useCaseFileName = 'watch_${entitySnake}_list_usecase.dart';
    } else {
      useCaseFileName =
          '${StringUtils.camelToSnake(method)}_${entitySnake}_usecase.dart';
    }

    final imports = <String>[
      "import 'package:flutter_test/flutter_test.dart';",
      "import 'package:mocktail/mocktail.dart';",
    ];

    if (method != 'create') {
      imports.add(
        "import 'package:zuraffa/zuraffa.dart';",
      );
    }

    // Try to resolve package name
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

    final repoSnake =
        StringUtils.camelToSnake(repoName.replaceAll('Repository', ''));

    // Generate imports
    if (needsEntityImport) {
      imports.add(
          "import 'package:$packageName/src/domain/entities/$entitySnake/$entitySnake.dart';");
    }
    imports.add(
        "import 'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart';");
    imports.add(
        "import 'package:$packageName/src/domain/usecases/$entitySnake/$useCaseFileName';");

    final mockRepoClass = 'Mock$repoName';
    final mockEntityClass = 'Mock$entityName';

    String setupBody = '''
  late $className useCase;
  late $mockRepoClass mockRepository;

  setUp(() {
    ${method == 'getList' || method == 'watchList' ? 'registerFallbackValue(const ListQueryParams());\n    ' : ''}
    mockRepository = $mockRepoClass();
    useCase = $className(mockRepository);
  });''';

    // Generate test body
    String testBody = '';

    if (isStream) {
      testBody = _generateStreamTests(
          method, entityName, mockRepoClass, returnTypeConstructor);
    } else {
      testBody = _generateFutureTests(method, entityName, mockRepoClass,
          returnTypeConstructor, isCompletable);
    }

    final content = '''
// Generated by zfa
// zfa generate ${config.name} --methods=$method --test

${imports.join('\n')}

class $mockRepoClass extends Mock implements $repoName {}
class $mockEntityClass extends Mock implements $entityName {}

void main() {
$setupBody

  group('$className', () {
    ${(method != 'delete') ? 'final t$entityName = $mockEntityClass();\n    ' : ''}
    ${([
      'get',
      'create',
      'delete',
      'watch'
    ].contains(method)) ? '' : (method == 'update') ? '    final u$entityName = t$entityName.toJson();\n' : ([
            'getList',
            'watchList'
          ].contains(method)) ? '    final t${entityName}List = [t$entityName];\n' : '    final t${entityName}List = [t$entityName];\n    final u$entityName = t$entityName.toJson();\n'}

$testBody
  });
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _generateFutureTests(String method, String entityName,
      String mockRepoClass, String returnConstructor, bool isCompletable) {
    String arrange;
    String verifyCall;
    String paramsConstructor;
    String failureArrange;

    if (method == 'get') {
      if (config.idField == 'null') {
        paramsConstructor = "const NoParams()";
        arrange =
            "when(() => mockRepository.get()).thenAnswer((_) async => $returnConstructor);";
        verifyCall = "verify(() => mockRepository.get()).called(1);";
        failureArrange =
            "when(() => mockRepository.get()).thenThrow(exception);";
      } else {
        paramsConstructor = "const QueryParams('1')";
        arrange =
            "when(() => mockRepository.get(any())).thenAnswer((_) async => $returnConstructor);";
        verifyCall = "verify(() => mockRepository.get(any())).called(1);";
        failureArrange =
            "when(() => mockRepository.get(any())).thenThrow(exception);";
      }
    } else if (method == 'getList') {
      paramsConstructor = "const ListQueryParams()";
      arrange =
          "when(() => mockRepository.getList(any())).thenAnswer((_) async => $returnConstructor);";
      verifyCall = "verify(() => mockRepository.getList(any())).called(1);";
      failureArrange =
          "when(() => mockRepository.getList(any())).thenThrow(exception);";
    } else if (method == 'create') {
      paramsConstructor = "t$entityName";
      arrange =
          "when(() => mockRepository.create(any())).thenAnswer((_) async => $returnConstructor);";
      verifyCall = "verify(() => mockRepository.create(any())).called(1);";
      failureArrange =
          "when(() => mockRepository.create(any())).thenThrow(exception);";
    } else if (method == 'update') {
      paramsConstructor = "UpdateParams(id: '1', data: u$entityName)";
      arrange =
          "when(() => mockRepository.update(any())).thenAnswer((_) async => $returnConstructor);";
      verifyCall = "verify(() => mockRepository.update(any())).called(1);";
      failureArrange =
          "when(() => mockRepository.update(any())).thenThrow(exception);";
    } else if (method == 'delete') {
      paramsConstructor = "const DeleteParams('1')";
      arrange =
          "when(() => mockRepository.delete(any())).thenAnswer((_) async => {});";
      verifyCall = "verify(() => mockRepository.delete(any())).called(1);";
      failureArrange =
          "when(() => mockRepository.delete(any())).thenThrow(exception);";
    } else {
      return '';
    }

    final successCheck = isCompletable
        ? "expect(result.isSuccess, true);"
        : "expect(result.isSuccess, true);\n      expect(result.getOrElse(() => throw Exception()), equals($returnConstructor));";

    return '''
    test('should call repository.$method and return result', () async {
      // Arrange
      $arrange

      // Act
      final result = await useCase($paramsConstructor);

      // Assert
      $verifyCall
      $successCheck
    });

    test('should return Failure when repository throws', () async {
      // Arrange
      final exception = Exception('Error');
      $failureArrange

      // Act
      final result = await useCase($paramsConstructor);

      // Assert
      $verifyCall
      expect(result.isFailure, true);
    });''';
  }

  String _generateStreamTests(String method, String entityName,
      String mockRepoClass, String returnConstructor) {
    String arrange;
    String verifyCall;
    String paramsConstructor;
    String failureArrange;

    if (method == 'watch') {
      if (config.idField == 'null') {
        paramsConstructor = "NoParams()";
        arrange =
            "when(() => mockRepository.watch()).thenAnswer((_) => Stream.value($returnConstructor));";
        verifyCall = "verify(() => mockRepository.watch()).called(1);";
        failureArrange =
            "when(() => mockRepository.watch()).thenAnswer((_) => Stream.error(exception));";
      } else {
        paramsConstructor = "QueryParams('1')";
        arrange =
            "when(() => mockRepository.watch(any())).thenAnswer((_) => Stream.value($returnConstructor));";
        verifyCall = "verify(() => mockRepository.watch(any())).called(1);";
        failureArrange =
            "when(() => mockRepository.watch(any())).thenAnswer((_) => Stream.error(exception));";
      }
    } else if (method == 'watchList') {
      paramsConstructor = "ListQueryParams()";
      arrange =
          "when(() => mockRepository.watchList(any())).thenAnswer((_) => Stream.value($returnConstructor));";
      verifyCall = "verify(() => mockRepository.watchList(any())).called(1);";
      failureArrange =
          "when(() => mockRepository.watchList(any())).thenAnswer((_) => Stream.error(exception));";
    } else {
      return '';
    }

    return '''
    test('should emit values from repository stream', () async {
      // Arrange
      $arrange

      // Act
      final result = useCase($paramsConstructor);

      // Assert
      await expectLater(
        result,
        emits(isA<Success>().having((s) => s.value, 'value', equals($returnConstructor))),
      );
      $verifyCall
    });

    test('should emit Failure when repository stream errors', () async {
      // Arrange
      final exception = Exception('Stream Error');
      $failureArrange

      // Act
      final result = useCase(const $paramsConstructor);

      // Assert
      await expectLater(
        result,
        emits(isA<Failure>()),
      );
      $verifyCall
    });''';
  }

  Future<GeneratedFile> generateCustom() async {
    final useCaseName = '${config.name}UseCase';
    final useCaseType = config.useCaseType;
    final paramsType = config.paramsType ?? 'NoParams';
    final fileName = '${config.nameSnake}_usecase_test.dart';

    // Construct path: test/domain/usecases/entity_name/...
    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    if (config.subdirectory != null && config.subdirectory!.isNotEmpty) {
      testPathParts.add(config.subdirectory!);
    }
    // Add entity subfolder for custom UseCases
    testPathParts.add(config.nameSnake);

    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    final imports = <String>[
      "import 'package:flutter_test/flutter_test.dart';",
      "import 'package:mocktail/mocktail.dart';",
      "import 'package:zuraffa/zuraffa.dart';",
    ];

    // Try to resolve package name
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

    // Import usecase
    if (config.subdirectory != null) {
      imports.add(
          "import 'package:$packageName/src/domain/usecases/${config.subdirectory}/${config.nameSnake}_usecase.dart';");
    } else {
      imports.add(
          "import 'package:$packageName/src/domain/usecases/${config.nameSnake}/${config.nameSnake}_usecase.dart';");
    }

    final mocks = <String>[];
    final setupMocks = <String>[];

    for (final repo in config.repos) {
      final mockName = 'Mock$repo';
      mocks.add('class $mockName extends Mock implements $repo {}');
      setupMocks.add('mock$repo = $mockName();');

      final repoSnake =
          StringUtils.camelToSnake(repo.replaceAll('Repository', ''));
      imports.add(
          "import 'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart';");
    }

    final setupArgs = config.repos.map((r) => 'mock$r').join(', ');
    final setupInstantiation = 'useCase = $useCaseName($setupArgs);';

    final fields = <String>[];
    fields.add('late $useCaseName useCase;');
    for (final repo in config.repos) {
      fields.add('late Mock$repo mock$repo;');
    }

    String testBody = '';
    final callArgs = paramsType == 'NoParams' ? 'const NoParams()' : '';

    if (useCaseType == 'background') {
      testBody = '''
    test('should return BackgroundTask', () {
      // Act
      final result = useCase.buildTask($callArgs); // Adjust params if needed

      // Assert
      expect(result, isA<BackgroundTask>());
    });''';
    } else if (useCaseType == 'stream') {
      testBody = '''
    test('should emit values from stream', () async {
      // Arrange
      // TODO: Mock stream return from repositories

      // Act
      final result = useCase($callArgs); // Adjust params if needed

      // Assert
      await expectLater(
        result,
        emits(isA<Success>()),
      );
    });''';
    } else {
      // usecase or completable
      testBody = '''
    test('should return Success', () async {
      // Arrange
      // TODO: Mock return from repositories

      // Act
      final result = await useCase($callArgs); // Adjust params if needed

      // Assert
      expect(result.isSuccess, true);
    });''';
    }

    final content = '''
// Generated by zfa
// zfa generate ${config.name} --type=$useCaseType --test

${imports.join('\n')}

${mocks.join('\n')}

void main() {
  ${fields.join('\n  ')}

  setUp(() {
    registerFallbackValue(const ListQueryParams());
    ${setupMocks.join('\n    ')}
    $setupInstantiation
  });

  group('$useCaseName', () {
$testBody
  });
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
