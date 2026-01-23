class StringUtils {
  static String camelToSnake(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (i > 0 && char.toUpperCase() == char && char != '_') {
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
      finalText += word[0].toUpperCase() + word.substring(1, word.length);
    }

    return finalText;
  }
}
