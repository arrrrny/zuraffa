// Issue #1418 (secondary, emission level): the generated mock datasource
// imports `package:zuraffa/mock.dart` and hides the entity's own symbols
// (#942). The hide list must contain ONLY names the mock barrel actually
// exports — an entity name absent from the mock barrel's surface must
// never appear in a `hide` clause (undefined_hidden_name → zfa build's
// analyze gate).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_datasource_builder.dart';
import 'package:zuraffa/src/utils/zuraffa_barrel_exports.dart';

const _entityContent = 'class Credentials { final String id; }';

RegExp _mockImportWithHide(String names) =>
    RegExp("import\\s+'package:zuraffa/mock.dart'\\s+hide\\s+$names;");

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1418_hide_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    final entityDir = Directory('$outputDir/domain/entities/credentials');
    await entityDir.create(recursive: true);
    await File(
      '${entityDir.path}/credentials.dart',
    ).writeAsString(_entityContent);
  });

  tearDown(() async {
    ZuraffaBarrelExports.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Builds the fake zuraffa package the resolver walks, then seeds from
  /// the temp root. When [bareReexport] is false the mock barrel diverges
  /// from the zuraffa barrel (the synthetic future state the filter's
  /// contract guards against); when true it bare-re-exports zuraffa.dart
  /// (today's real layout).
  void seedSurface({required bool bareReexport}) {
    final zuraffaRoot = '${tempDir.path}/fixture_zuraffa';
    Directory('$zuraffaRoot/lib/src').createSync(recursive: true);
    File(
      '$zuraffaRoot/lib/zuraffa.dart',
    ).writeAsStringSync("export 'src/core.dart';\n");
    File(
      '$zuraffaRoot/lib/src/core.dart',
    ).writeAsStringSync('class Credentials {}\nclass CredentialsPatch {}\n');
    if (bareReexport) {
      File(
        '$zuraffaRoot/lib/mock.dart',
      ).writeAsStringSync("export 'src/mock.dart';\n");
      File('$zuraffaRoot/lib/src/mock.dart').writeAsStringSync(
        "export 'package:zuraffa/zuraffa.dart';\n"
        'const bool zuraffaMockLibrary = true;\n',
      );
    } else {
      File(
        '$zuraffaRoot/lib/mock.dart',
      ).writeAsStringSync("export 'src/mock.dart';\n");
      File(
        '$zuraffaRoot/lib/src/mock.dart',
      ).writeAsStringSync('class MockThing {}\n');
    }
    final dotTool = Directory('${tempDir.path}/.dart_tool');
    dotTool.createSync(recursive: true);
    // NOTE: the target project's package_config points the `zuraffa`
    // package at the fixture root — exactly how the resolver locates the
    // barrel in a real generation target.
    File('${dotTool.path}/package_config.json').writeAsStringSync(
      '{"configVersion":2,"packages":[{"name":"zuraffa",'
      '"rootUri":"${Uri.file(zuraffaRoot)}","packageUri":"lib/"}]}',
    );
    ZuraffaBarrelExports.seed(tempDir.path);
  }

  Future<String> generateEmission() async {
    final config = GeneratorConfig(
      name: 'Credentials',
      outputDir: outputDir,
      methods: const ['get'],
      generateMock: true,
      generateDataSource: false,
    );
    await MockDataSourceBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(),
      fileSystem: FileSystem.create(),
    ).generateMockDataSource(config);
    final path =
        '$outputDir/data/datasources/credentials/credentials_mock_datasource.dart';
    return File(path).readAsString();
  }

  test(
    'diverged mock barrel: entity names absent from it are NOT hidden from mock.dart',
    () async {
      seedSurface(bareReexport: false);

      final source = await generateEmission();

      expect(
        _mockImportWithHide('[^;]*').hasMatch(source),
        isFalse,
        reason:
            'Credentials/CredentialsPatch are not exported by the mock '
            'barrel — hiding them from mock.dart is the exact '
            'undefined_hidden_name warning class (#1418)',
      );
      expect(source, contains("import 'package:zuraffa/mock.dart';"));
    },
  );

  test(
    'bare re-export: the #942 collision hide survives on the mock import',
    () async {
      seedSurface(bareReexport: true);

      final source = await generateEmission();

      expect(
        _mockImportWithHide(
          r'Credentials,\s*CredentialsPatch',
        ).hasMatch(source),
        isTrue,
        reason:
            'both names are verified against the mock barrel (bare '
            're-export union) — the collision protection holds',
      );
    },
  );
}
