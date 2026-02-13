import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';

class _TestPlugin extends ZuraffaPlugin {
  @override
  String get id => 'test';

  @override
  String get name => 'Test Plugin';

  @override
  String get version => '1.0.0';
}

class _TestFilePlugin extends FileGeneratorPlugin {
  @override
  String get id => 'file';

  @override
  String get name => 'File Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    return [
      GeneratedFile(
        path: 'lib/src/sample.dart',
        type: 'sample',
        action: 'create',
        content: 'class Sample {}',
      ),
    ];
  }
}

void main() {
  group('ZuraffaPlugin', () {
    test('validate defaults to success', () async {
      final plugin = _TestPlugin();
      final result = await plugin.validate(GeneratorConfig(name: 'Product'));
      expect(result.isValid, isTrue);
    });
  });

  group('FileGeneratorPlugin', () {
    test('implements ZuraffaPlugin', () {
      final plugin = _TestFilePlugin();
      expect(plugin, isA<ZuraffaPlugin>());
    });
  });
}
