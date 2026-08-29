// Spec 035 — Track 4.4: XRayBridgeHandlers tests.
//
// Behaviors B05..B16.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_bridge_handlers.dart';

void main() {
  // Fake overlay state + control deck for handler tests.
  // The handlers use dynamic dispatch so we don't need the real
  // XRayOverlayState / XRayControlDeck classes (which live on the
  // spec 036 / 034 branches).
  late _FakeOverlay overlay;
  late _FakeControlDeck deck;
  late XRayBridgeHandlers handlers;

  setUp(() {
    overlay = _FakeOverlay();
    deck = _FakeControlDeck();
    handlers = XRayBridgeHandlers(
      overlayState: overlay,
      controlDeck: deck,
      isReleaseMode: false,
    );
  });

  group('handleTreeGet', () {
    test(
      'B05 — returns 200 with activeView + nodes when overlay non-empty',
      () {
        overlay.nodes = [
          {'id': 'n1', 'viewType': 'ProfileView'},
          {'id': 'n2', 'viewType': 'HomeView'},
        ];
        overlay.activeView = 'ProfileView';

        final r = handlers.handleTreeGet();
        expect(r.statusCode, 200);
        expect(r.body['activeView'], 'ProfileView');
        expect((r.body['nodes'] as List).length, 2);
      },
    );

    test('B06 — returns 200 with activeView=null + nodes=[] when empty', () {
      overlay.nodes = const [];
      overlay.activeView = null;

      final r = handlers.handleTreeGet();
      expect(r.statusCode, 200);
      expect(r.body['activeView'], isNull);
      expect(r.body['nodes'], isEmpty);
    });

    test('B14 — returns 404 in release mode', () {
      final release = XRayBridgeHandlers(
        overlayState: overlay,
        controlDeck: deck,
        isReleaseMode: true,
      );
      final r = release.handleTreeGet();
      expect(r.statusCode, 404);
      expect(r.body['error'], contains('release'));
    });
  });

  group('handleActionPost', () {
    test('B07 — returns 200 + invokes bound action when node has one', () {
      overlay.nodes = [
        {'id': 'n1', 'boundAction': 'onTap'},
      ];
      overlay.boundActionResult = {'navigated': true};

      final r = handlers.handleActionPost({'targetNode': 'n1'});
      expect(r.statusCode, 200);
      expect(r.body['success'], isTrue);
      expect(r.body['nodeId'], 'n1');
      expect(r.body['actionResult'], isNotNull);
    });

    test('B08 — returns 404 + availableNodeIds for unknown target', () {
      overlay.nodes = [
        {'id': 'n1'},
        {'id': 'n2'},
      ];

      final r = handlers.handleActionPost({'targetNode': 'unknown'});
      expect(r.statusCode, 404);
      expect(r.body['availableNodeIds'], containsAll(['n1', 'n2']));
    });

    test('B09 — returns 400 when node has no bound action', () {
      overlay.nodes = [
        {'id': 'n1'}, // no boundAction
      ];

      final r = handlers.handleActionPost({'targetNode': 'n1'});
      expect(r.statusCode, 400);
      expect(r.body['success'], isFalse);
    });

    test('B10 — returns 400 when targetNode missing from body', () {
      final r = handlers.handleActionPost({});
      expect(r.statusCode, 400);
      expect(r.body['error'], contains('targetNode'));
    });

    test('B10b — returns 400 when targetNode is empty string', () {
      final r = handlers.handleActionPost({'targetNode': ''});
      expect(r.statusCode, 400);
    });

    test('B10c — tolerates non-Map nodes in the tree (no crash)', () {
      // A malformed tree can contain non-Map entries (null / scalar /
      // nested list). The handler must skip them, not throw an uncaught
      // CastError, and still locate the one valid node.
      overlay.nodes = <dynamic>[
        'not-a-map',
        null,
        <dynamic>['also', 'not', 'a', 'map'],
        {'id': 'n1', 'boundAction': 'onTap'},
      ];
      overlay.boundActionResult = {'navigated': true};

      final r = handlers.handleActionPost({'targetNode': 'n1'});
      expect(r.statusCode, 200);
      expect(r.body['nodeId'], 'n1');
    });

    test('B10d — a tree with only malformed nodes yields unknownNode', () {
      overlay.nodes = <dynamic>['junk', null, 42];

      final r = handlers.handleActionPost({'targetNode': 'n1'});
      expect(r.statusCode, 404);
      expect(r.body['error'], contains('not found'));
    });

    test('B15 — returns 404 in release mode', () {
      final release = XRayBridgeHandlers(
        overlayState: overlay,
        controlDeck: deck,
        isReleaseMode: true,
      );
      final r = release.handleActionPost({'targetNode': 'n1'});
      expect(r.statusCode, 404);
    });
  });

  group('handleControlDeckPost', () {
    test('B11 — returns 200 + injected payload when mock registered', () {
      deck.mocks = {'A': 'payload-A'};

      final r = handlers.handleControlDeckPost({'mockName': 'A'});
      expect(r.statusCode, 200);
      expect(r.body['success'], isTrue);
      expect(r.body['mockName'], 'A');
      expect(r.body['injectedPayload'], 'payload-A');
    });

    test('B12 — returns 404 + availableMockNames for unknown mock', () {
      deck.mocks = {'A': 'p1', 'B': 'p2'};

      final r = handlers.handleControlDeckPost({'mockName': 'unknown'});
      expect(r.statusCode, 404);
      expect(r.body['availableMockNames'], containsAll(['A', 'B']));
    });

    test('B13 — returns 400 when mockName missing', () {
      final r = handlers.handleControlDeckPost({});
      expect(r.statusCode, 400);
      expect(r.body['error'], contains('mockName'));
    });

    test('B13b — returns 400 when mockName is empty string', () {
      final r = handlers.handleControlDeckPost({'mockName': ''});
      expect(r.statusCode, 400);
    });

    test('B16 — returns 404 in release mode', () {
      final release = XRayBridgeHandlers(
        overlayState: overlay,
        controlDeck: deck,
        isReleaseMode: true,
      );
      final r = release.handleControlDeckPost({'mockName': 'A'});
      expect(r.statusCode, 404);
    });
  });
}

/// Minimal fake of the spec 036 XRayOverlayState for handler tests.
///
/// `nodes` is `List<dynamic>` (not `List<Map>`) so tests can inject
/// malformed entries (null / scalar / nested list) to exercise the
/// handler's defensive skip behaviour.
class _FakeOverlay {
  List<dynamic> nodes = const <dynamic>[];
  String? activeView;
  Map<String, dynamic>? boundActionResult;

  Map<String, dynamic> toJson() => {'activeView': activeView, 'nodes': nodes};

  Map<String, dynamic>? inspect(String id) {
    if (boundActionResult == null) return null;
    return {'nodeId': id, 'actionResult': boundActionResult};
  }
}

/// Minimal fake of the spec 034 XRayControlDeck for handler tests.
class _FakeControlDeck {
  Map<String, String> mocks = {};
  List<String> get mockNames => mocks.keys.toList();
  String? inject(String name) {
    final v = mocks[name];
    return v;
  }
}
