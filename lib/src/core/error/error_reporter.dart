import '../../models/generator_config.dart';
import '../../models/generator_result.dart';
import 'suggestion_engine.dart';

class ErrorReporter {
  final SuggestionEngine suggestionEngine;

  ErrorReporter({SuggestionEngine? suggestionEngine})
    : suggestionEngine = suggestionEngine ?? SuggestionEngine();

  void report(GeneratorResult result, {GeneratorConfig? config}) {
    print('❌ Generation failed');
    for (final error in result.errors) {
      final label = _pluginLabel(error);
      if (label == null) {
        print('   • [core] $error');
      } else {
        print('   • [$label] ${_stripPluginPrefix(error)}');
      }
    }

    final suggestions = suggestionEngine.suggestionsFor(
      errors: result.errors,
      config: config,
    );

    if (suggestions.isNotEmpty) {
      print('');
      print('💡 Suggestions:');
      for (final suggestion in suggestions) {
        print('   • $suggestion');
      }
    }
  }

  String? _pluginLabel(String error) {
    final match = RegExp(
      r'Plugin\s+([a-zA-Z0-9_-]+)\s+failed',
    ).firstMatch(error);
    return match?.group(1);
  }

  String _stripPluginPrefix(String error) {
    return error.replaceFirst(
      RegExp(r'Plugin\s+[a-zA-Z0-9_-]+\s+failed:\s*'),
      '',
    );
  }
}
