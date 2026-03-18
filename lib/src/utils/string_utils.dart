class StringUtils {
  static String camelToSnake(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == ' ') {
        final current = buffer.toString();
        if (current.isNotEmpty && current[current.length - 1] != '_') {
          buffer.write('_');
        }
        continue;
      }
      // Only add underscore before actual uppercase letters
      if (i > 0 &&
          char.toLowerCase() != char &&
          char.toUpperCase() == char &&
          char != '_' &&
          input[i - 1] != '_' &&
          input[i - 1] != ' ') {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  static String pascalToCamel(String input) {
    if (input.isEmpty) return '';
    return input[0].toLowerCase() + input.substring(1);
  }

  static String convertToPascalCase(String text) {
    var finalText = '';
    var words = text.split('_');

    for (var word in words) {
      if (word.isEmpty) continue;
      finalText += word[0].toUpperCase() + word.substring(1);
    }

    return finalText;
  }

  static String capitalize(String input) {
    if (input.isEmpty) return '';
    return input[0].toUpperCase() + input.substring(1);
  }

  static String toContinuous(String name) {
    if (name.isEmpty) return '';
    final lower = name.toLowerCase();

    // Handle PascalCase/camelCase by checking for common verbs at the start
    final verbs = [
      'Check',
      'Request',
      'Get',
      'Create',
      'Update',
      'Delete',
      'Watch',
      'Send',
      'Open',
      'Verify',
      'Fetch',
      'Load',
    ];

    for (final verb in verbs) {
      if ((name.startsWith(verb) || name.startsWith(pascalToCamel(verb))) &&
          name.length > verb.length) {
        final rest = name.substring(verb.length);
        return '${toContinuous(verb)}$rest';
      }
    }

    // Exact matches for standard methods
    if (lower == 'get') return 'Getting';
    if (lower == 'list' || lower == 'getlist') return 'GettingList';
    if (lower == 'create') return 'Creating';
    if (lower == 'update') return 'Updating';
    if (lower == 'delete') return 'Deleting';
    if (lower == 'watch') return 'Watching';
    if (lower == 'watchlist') return 'WatchingList';

    // If it already ends with 'ing', capitalize and return
    if (lower.endsWith('ing')) return capitalize(name);

    // Heuristics for others
    if (lower.endsWith('e')) {
      return '${capitalize(name.substring(0, name.length - 1))}ing';
    }

    return '${capitalize(name)}ing';
  }

  static String snakeToPath(String input) {
    if (input.isEmpty) return '';
    return input.replaceAll('_', '/');
  }
}
