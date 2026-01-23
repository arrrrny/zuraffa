class GeneratedFile {
  final String path;
  final String type;
  final String action;

  GeneratedFile({
    required this.path,
    required this.type,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'path': path,
        'action': action,
      };
}
