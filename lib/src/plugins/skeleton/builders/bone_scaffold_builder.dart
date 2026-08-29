/// Creates the bone directory structure with layer placeholders and barrel.
library;

import 'dart:io';

import '../models/bone.dart';
import 'entity_stub_builder.dart';
import 'manifest_builder.dart';

/// Builds the bone directory structure on the filesystem.
class BoneScaffoldBuilder {
  /// Creates a [BoneScaffoldBuilder].
  BoneScaffoldBuilder({
    ManifestBuilder? manifestBuilder,
    EntityStubBuilder? entityStubBuilder,
  })  : manifestBuilder = manifestBuilder ?? ManifestBuilder(),
        entityStubBuilder = entityStubBuilder ?? EntityStubBuilder();

  final ManifestBuilder manifestBuilder;
  final EntityStubBuilder entityStubBuilder;

  /// Writes the bone scaffold to the filesystem at [boneDir].
  Future<void> build(Bone bone, String boneDir) async {
    // Write manifest.
    final manifestContent = manifestBuilder.render(bone.manifest);
    await File('$boneDir/bone.yaml').create(recursive: true);
    await File('$boneDir/bone.yaml').writeAsString(manifestContent);

    // Write entity stubs.
    await Directory('$boneDir/lib/entities').create(recursive: true);
    for (final stub in bone.entityStubs) {
      final source = entityStubBuilder.build(stub);
      final filePath = '$boneDir/${stub.sourcePath}';
      await File(filePath).create(recursive: true);
      await File(filePath).writeAsString(source);
    }

    // Write barrel entry point.
    final barrelName = _toSnake(bone.featureSlug);
    final barrelPath = '$boneDir/lib/$barrelName.dart';
    final barrel = StringBuffer();
    for (final stub in bone.entityStubs) {
      barrel.writeln("export 'entities/${_toSnake(stub.name)}.dart';");
    }
    await File(barrelPath).create(recursive: true);
    await File(barrelPath).writeAsString(barrel.toString());

    // Write layer placeholders.
    for (final layer in bone.layers) {
      final layerDir = '$boneDir/${layer.path}';
      await Directory(layerDir).create(recursive: true);
      final readmePath = '$layerDir/README.md';
      await File(readmePath).create(recursive: true);
      await File(readmePath).writeAsString(
        '# ${layer.layer}\n\n'
        'Placeholder for the ${layer.layer} layer.\n',
      );
    }

    // Write per-entity test stubs (U17).
    await Directory('$boneDir/test').create(recursive: true);
    for (final stub in bone.entityStubs) {
      final snakeName = _toSnake(stub.name);
      final testPath = '$boneDir/test/${snakeName}_test.dart';
      final testContent = "import '../lib/$barrelName.dart';\n\n"
          'void main() {\n'
          '  // TODO: add entity tests\n'
          '}\n';
      await File(testPath).create(recursive: true);
      await File(testPath).writeAsString(testContent);
    }
  }

  String _toSnake(String name) {
    final result = name
        .replaceAll('-', '_')
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        );
    // Only remove leading underscore (from PascalCase start), not internal ones.
    return result.startsWith('_') ? result.substring(1) : result;
  }
}
