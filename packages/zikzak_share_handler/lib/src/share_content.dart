/// The kind of content being shared.
enum ShareContentType { text, url, file }

/// The payload handed to a share sheet.
class ShareContent {
  ShareContent.text(this.text, {this.title, this.subject})
    : type = ShareContentType.text,
      url = null,
      filePath = null,
      mimeType = null;

  ShareContent.url(this.url, {this.title, this.subject})
    : type = ShareContentType.url,
      text = null,
      filePath = null,
      mimeType = null;

  ShareContent.file(this.filePath, {this.title, this.subject, this.mimeType})
    : type = ShareContentType.file,
      text = null,
      url = null;

  final ShareContentType type;
  final String? text;
  final String? url;
  final String? filePath;
  final String? title;
  final String? subject;
  final String? mimeType;

  @override
  String toString() => 'ShareContent($type)';
}
