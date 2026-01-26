class GeneratedFile {
  final String path;
  final String type;
  final String action;
  final String? content;

  GeneratedFile({
    required this.path,
    required this.type,
    required this.action,
    this.content,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'path': path,
        'action': action,
        'content': content,
      };
}
