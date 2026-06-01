import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  group('RemovedGenerateCommand', () {
    test('prints v5 migration guidance', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['generate', 'Product']);

      expect(
        output,
        contains("The 'generate' command was removed in Zuraffa v5"),
      );
      expect(output, contains('zfa make <Name>'));
      expect(output, contains('zfa feature <Name>'));
    });
  });
}
