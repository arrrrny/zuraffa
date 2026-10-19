import 'package:test/test.dart';
import 'package:zikzak_share_handler/zikzak_share_handler.dart';

class _FakeDatasource implements ShareHandlerDatasource {
  _FakeDatasource(this.result, this.available);
  final ShareResult result;
  final bool available;

  @override
  Future<ShareResult> share(ShareContent content) async => result;

  @override
  Future<bool> canShare() async => available;
}

void main() {
  group('ShareContent', () {
    test('text factory sets type and payload', () {
      final c = ShareContent.text('hello', title: 't', subject: 's');
      expect(c.type, ShareContentType.text);
      expect(c.text, 'hello');
      expect(c.title, 't');
      expect(c.subject, 's');
      expect(c.url, isNull);
      expect(c.filePath, isNull);
    });
    test('url factory', () {
      final c = ShareContent.url('https://x', title: 't');
      expect(c.type, ShareContentType.url);
      expect(c.url, 'https://x');
    });
    test('file factory', () {
      final c = ShareContent.file('/tmp/f.png', mimeType: 'image/png');
      expect(c.type, ShareContentType.file);
      expect(c.filePath, '/tmp/f.png');
      expect(c.mimeType, 'image/png');
    });
  });

  group('ShareResult', () {
    test('success', () {
      const r = ShareResult.success();
      expect(r.isSuccess, isTrue);
      expect(r.isCancelled, isFalse);
      expect(r.isError, isFalse);
    });
    test('cancelled', () {
      const r = ShareResult.cancelled();
      expect(r.isCancelled, isTrue);
    });
    test('error carries message', () {
      const r = ShareResult.error('boom');
      expect(r.isError, isTrue);
      expect(r.errorMessage, 'boom');
    });
  });

  group('ShareHandlerRepository', () {
    test('delegates share and canShare', () async {
      final ds = _FakeDatasource(const ShareResult.success(), true);
      final repo = ShareHandlerRepository(ds);
      final res = await repo.share(ShareContent.text('hi'));
      expect(res.isSuccess, isTrue);
      expect(await repo.canShare(), isTrue);
    });
  });

  group('UnsupportedShareHandlerDatasource', () {
    test('returns error and false', () async {
      const ds = UnsupportedShareHandlerDatasource();
      final res = await ds.share(ShareContent.text('hi'));
      expect(res.isError, isTrue);
      expect(await ds.canShare(), isFalse);
    });
  });
}
