import 'dart:io';

class RegistrationInfo {
  final String fileName;
  final String functionName;

  const RegistrationInfo({required this.fileName, required this.functionName});
}

class RegistrationDetector {
  const RegistrationDetector();

  List<RegistrationInfo> detectRegistrations(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      return [];
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_di.dart'))
        .toList();

    final registrations = <RegistrationInfo>[];
    for (final file in files) {
      final fileName = file.uri.pathSegments.last;
      if (fileName == 'index.dart') {
        continue;
      }
      final content = file.readAsStringSync();
      final match = RegExp(
        r'void (register\w+)\(GetIt getIt\)',
      ).firstMatch(content);
      if (match != null) {
        registrations.add(
          RegistrationInfo(fileName: fileName, functionName: match.group(1)!),
        );
      }
    }
    return registrations;
  }
}
