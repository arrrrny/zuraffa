import '../models/generator_result.dart';

class CliLogger {
  static void info(String message) {
    print('ℹ️  $message');
  }

  static void success(String message) {
    print('✅ $message');
  }

  static void error(String message) {
    print('❌ $message');
  }

  static void warning(String message) {
    print('⚠️  $message');
  }

  static void printResult(GeneratorResult result) {
    if (result.success) {
      print('✅ Generated ${result.files.length} files for ${result.name}');
      print('');
      for (final file in result.files) {
        print('  ${file.action == 'created' ? '✓' : '⟳'} ${file.path}');
      }
      if (result.nextSteps.isNotEmpty) {
        print('');
        print('📝 Next steps:');
        for (final step in result.nextSteps) {
          print('   • $step');
        }
      }
    } else {
      print('❌ Generation failed');
      for (final error in result.errors) {
        print('   • $error');
      }
    }
  }
}
