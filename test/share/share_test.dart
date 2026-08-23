import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Share built-in: port contract, in-memory recorder, facade validation.
void main() {
  group('SharePort — in-memory adapter', () {
    test('records share requests in order', () async {
      final port = InMemoryShareAdapter();

      await port.share(const ShareRequest(text: 'Hello', subject: 'S'));
      await port.share(const ShareRequest(files: ['/tmp/a.pdf']));

      expect(port.requests, hasLength(2));
      expect(port.requests.first.text, 'Hello');
      expect(port.requests.first.subject, 'S');
      expect(port.requests.last.files, ['/tmp/a.pdf']);
    });

    test('an empty payload is a typed error', () async {
      final port = InMemoryShareAdapter();

      await expectLater(
        port.share(const ShareRequest()),
        throwsA(
          isA<ShareException>().having(
            (e) => e.code,
            'code',
            'nothing_to_share',
          ),
        ),
      );
      expect(port.requests, isEmpty, reason: 'rejected shares record nothing');
    });
  });

  group('ShareService', () {
    test('shareText/shareFiles compose the request for the port',
        () async {
      final port = InMemoryShareAdapter();
      final service = ShareService(port: port);

      await service.shareText('Look!', subject: 'News');
      await service.shareFiles(['/a.pdf', '/b.pdf'], text: 'Two files');

      expect(port.requests.first, const ShareRequest(text: 'Look!', subject: 'News'));
      expect(
        port.requests.last,
        const ShareRequest(text: 'Two files', files: ['/a.pdf', '/b.pdf']),
      );
    });

    test('empty text with no files fails fast through the facade',
        () async {
      final service = ShareService();

      await expectLater(
        () => service.share(text: '', files: []),
        throwsA(isA<ShareException>()),
      );
    });

    test('registerShareDependencies wires port + service', () async {
      final getIt = GetIt.asNewInstance();
      registerShareDependencies(getIt);

      await getIt<ShareService>().shareText('di');
      expect(
        (getIt<SharePort>() as InMemoryShareAdapter).requests,
        hasLength(1),
      );
    });
  });
}
