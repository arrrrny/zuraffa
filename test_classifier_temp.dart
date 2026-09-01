import 'lib/src/plugins/tdd/services/red_classifier.dart';
import 'lib/src/plugins/tdd/services/runner.dart';

void main() async {
  final runner = SingleTestRunner();
  try {
    final template = await runner.loadSingleTemplate(
      workingDirectory: '/Users/ahmettok/Developer/forklift',
    );
    print('Template: [$template]');
    
    final record = await runner.runSingle(
      singleTemplate: template,
      testPath: '/Users/ahmettok/Developer/forklift/test/tdd/a1_test.dart',
      testName: 'A1 (US1-S1) A clear instruction maps to a phase-1 capability, is executed, and the outcome is reported in plain language',
      workingDirectory: '/Users/ahmettok/Developer/forklift',
    );
    print('Command: [${record.command}]');
    print('Exit: ${record.exitCode}');
    print('TestCount: ${record.testCount}');
    final cls = classify(record);
    print('Classification: $cls');
  } catch(e) {
    print('Error: $e');
  }
}
