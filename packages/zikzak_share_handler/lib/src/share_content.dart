/// The kind of content being shared.
enum ShareContentType { text, url, file }

/// The payload handed to a share sheet.
class ShareContent {
  ShareContent.text(String text, {this.title, this.subject})
    : type = ShareContentType.text,
      text = text,
      url = null,
      filePath = null,
      mimeType = null;

  ShareContent.url(String url, {this.title, this.subject})
    : type = ShareContentType.url,
      text = null,
      url = url,
      filePath = null,
      mimeType = null;

  ShareContent.file(String filePath, {this.title, this.subject, this.mimeType})
    : type = ShareContentType.file,
      text = null,
      url = null,
      filePath = filePath;

  final ShareContentType type;
  final String? text;
  final String? url;
  final String? filePath;
  final String? title;
  final String? subject;
  final String? mimeType;

  ShareContent copyWith({
    ShareContentType? type,
    String? text,
    String? url,
    String? filePath,
    String? title,
    String? subject,
    String? mimeType,
  }) {
    // Preserve the constructor invariants of the current type unless an
    // explicit new type is requested.
    final nextType = type ?? this.type;
    switch (nextType) {
      case ShareContentType.text:
        return ShareContent.text(
          text ?? this.text ?? '',
          title: title ?? this.title,
          subject: subject ?? this.subject,
        );
      case ShareContentType.url:
        return ShareContent.url(
          url ?? this.url ?? '',
          title: title ?? this.title,
          subject: subject ?? this.subject,
        );
      case ShareContentType.file:
        return ShareContent.file(
          filePath ?? this.filePath ?? '',
          title: title ?? this.title,
          subject: subject ?? this.subject,
          mimeType: mimeType ?? this.mimeType,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareContent &&
          type == other.type &&
          text == other.text &&
          url == other.url &&
          filePath == other.filePath &&
          title == other.title &&
          subject == other.subject &&
          mimeType == other.mimeType;

  @override
  int get hashCode =>
      Object.hash(type, text, url, filePath, title, subject, mimeType);

  @override
  String toString() => 'ShareContent($type)';
}
