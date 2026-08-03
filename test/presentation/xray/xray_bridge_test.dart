import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:zuraffa/src/presentation/xray/xray_bridge.dart';
import 'package:zuraffa/src/presentation/xray/xray_bridge_server.dart';
import 'package:zuraffa/src/presentation/xray/xray_node_metadata.dart';
import 'package:zuraffa/src/presentation/xray/xray_scope.dart';

// ------------------------------------------------------------------
// Test helper — creates a Fake scope with the minimal interface
// needed by the bridge server.
// ------------------------------------------------------------------

/// Creates an [XRayScopeState] fake by leveraging [Fake] only on
/// the non-conflicting methods.
///
/// Because [XRayScopeState] extends [State] → [Diagnosticable],
/// `extends Fake implements XRayScopeState` causes a `toString`
/// override conflict. We work around this by not implementing the
/// full interface — the bridge server only accesses `viewId` and
/// `tree`, so we create a lightweight wrapper.
class TestScopeWrapper {
  final String viewId;
  final List<XRayNodeInfo> nodes;

  const TestScopeWrapper({
    required this.viewId,
    this.nodes = const [],
  });

  /// Serialize through [XRayTreeJson] directly (same path as
  /// [serializeXRayTree] but without requiring a real scope).
  XRayTreeJson toTreeJson() {
    return XRayTreeJson(
      activeView: viewId,
      nodes: nodes.map((info) {
        final meta = XRayMetadataRegistry.forNode(info.id);
        return XRayTreeNodeJson(
          id: info.id,
          enumName: info.enumName,
          actionName: meta?.actionName,
          isEnabled: meta?.isEnabled ?? true,
          state: meta?.stateJson,
        );
      }).toList(),
    );
  }
}

// ------------------------------------------------------------------
// Tests
// ------------------------------------------------------------------

void main() {
  tearDown(() {
    XRayActionRegistry.clear();
    XRayMockInjectorRegistry.clear();
    XRayMetadataRegistry.clear();
    XRayBridgeScopeHolder.reset();
  });

  group('XRayTreeNodeJson', () {
    test('toJson includes all fields', () {
      const node = XRayTreeNodeJson(
        id: 'ProductView.saveButton',
        enumName: 'saveButton',
        actionName: 'onSaveTapped',
        isEnabled: false,
        state: {'loading': true},
      );
      final json = node.toJson();
      expect(json['id'], 'ProductView.saveButton');
      expect(json['type'], 'saveButton');
      expect(json['boundAction'], 'onSaveTapped');
      expect(json['enabled'], false);
      expect(json['state'], {'loading': true});
    });

    test('toJson omits optional fields when null', () {
      const node = XRayTreeNodeJson(
        id: 'ProfileView.avatar',
        enumName: 'avatar',
      );
      final json = node.toJson();
      expect(json.containsKey('boundAction'), false);
      expect(json['enabled'], true);
      expect(json.containsKey('state'), false);
      expect(json.containsKey('parentId'), false);
    });

    test('toJson includes parentId when present', () {
      const node = XRayTreeNodeJson(
        id: 'ProductView.childButton',
        enumName: 'childButton',
        parentId: 'ProductView.parentContainer',
      );
      final json = node.toJson();
      expect(json['parentId'], 'ProductView.parentContainer');
    });
  });

  group('XRayTreeJson', () {
    test('toJson returns activeView and nodes list', () {
      final tree = XRayTreeJson(
        activeView: 'ProductView',
        nodes: const [
          XRayTreeNodeJson(id: 'ProductView.title', enumName: 'title'),
          XRayTreeNodeJson(
            id: 'ProductView.saveButton',
            enumName: 'saveButton',
            actionName: 'onSave',
          ),
        ],
      );

      final json = tree.toJson();
      expect(json['activeView'], 'ProductView');
      expect((json['nodes'] as List).length, 2);
      expect((json['nodes'] as List)[0]['id'], 'ProductView.title');
      expect((json['nodes'] as List)[1]['boundAction'], 'onSave');
    });

    test('toJson with empty nodes', () {
      final tree = XRayTreeJson(activeView: 'EmptyView', nodes: const []);
      final json = tree.toJson();
      expect(json['activeView'], 'EmptyView');
      expect(json['nodes'], []);
    });
  });

  group('XRayActionRegistry', () {
    test('register and invoke action', () {
      Map<String, dynamic>? receivedPayload;
      XRayActionRegistry.register('TestView.tapButton', (payload) {
        receivedPayload = payload;
      });

      final result = XRayActionRegistry.invoke(
          'TestView.tapButton', {'key': 'value'});
      expect(result, true);
      expect(receivedPayload, {'key': 'value'});
    });

    test('invoke with missing nodeId returns false', () {
      final result = XRayActionRegistry.invoke('NonExistent.node');
      expect(result, false);
    });

    test('invoke without payload uses empty map', () {
      Map<String, dynamic>? receivedPayload;
      XRayActionRegistry.register('TestView.node', (payload) {
        receivedPayload = payload;
      });

      XRayActionRegistry.invoke('TestView.node');
      expect(receivedPayload, isNotNull);
      expect(receivedPayload, {});
    });

    test('registeredIds returns all registered node IDs', () {
      XRayActionRegistry.register('A.b', (_) {});
      XRayActionRegistry.register('C.d', (_) {});

      final ids = XRayActionRegistry.registeredIds;
      expect(ids, containsAll(['A.b', 'C.d']));
    });

    test('unregister removes the action', () {
      XRayActionRegistry.register('TestView.node', (_) {});
      XRayActionRegistry.unregister('TestView.node');
      expect(XRayActionRegistry.invoke('TestView.node'), false);
    });
  });

  group('XRayMockInjectorRegistry', () {
    test('register and trigger mock', () {
      dynamic receivedPayload;
      XRayMockInjectorRegistry.register('Valid Product', (payload) {
        receivedPayload = payload;
      });

      final result =
          XRayMockInjectorRegistry.trigger('Valid Product', 'barcode123');
      expect(result, true);
      expect(receivedPayload, 'barcode123');
    });

    test('trigger with missing name returns false', () {
      final result = XRayMockInjectorRegistry.trigger('NonExistent');
      expect(result, false);
    });

    test('registeredNames returns all mock names', () {
      XRayMockInjectorRegistry.register('Mock A', (_) {});
      XRayMockInjectorRegistry.register('Mock B', (_) {});

      final names = XRayMockInjectorRegistry.registeredNames;
      expect(names, containsAll(['Mock A', 'Mock B']));
    });

    test('unregister removes the mock', () {
      XRayMockInjectorRegistry.register('Mock X', (_) {});
      XRayMockInjectorRegistry.unregister('Mock X');
      expect(XRayMockInjectorRegistry.trigger('Mock X'), false);
    });
  });

  group('XRayBridgeStream', () {
    test('emits diff events to listeners', () async {
      final events = <XRayTreeDiff>[];
      final sub = XRayBridgeStream.stream.listen(events.add);

      const diff = XRayTreeDiff(
        type: XRayBridgeEventType.added,
        nodeId: 'TestView.newNode',
      );

      XRayBridgeStream.emit(diff);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events.length, 1);
      expect(events[0].type, XRayBridgeEventType.added);
      expect(events[0].nodeId, 'TestView.newNode');

      await sub.cancel();
    });

    test('multiple listeners receive events', () async {
      final events1 = <XRayTreeDiff>[];
      final events2 = <XRayTreeDiff>[];
      final sub1 = XRayBridgeStream.stream.listen(events1.add);
      final sub2 = XRayBridgeStream.stream.listen(events2.add);

      XRayBridgeStream.emit(const XRayTreeDiff(
        type: XRayBridgeEventType.removed,
        nodeId: 'A.b',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events1.length, 1);
      expect(events2.length, 1);

      await sub1.cancel();
      await sub2.cancel();
    });

    test('diff toJson includes type and nodeId', () {
      const diff = XRayTreeDiff(
        type: XRayBridgeEventType.updated,
        nodeId: 'View.node',
        node: XRayTreeNodeJson(id: 'View.node', enumName: 'node'),
      );

      final json = diff.toJson();
      expect(json['type'], 'updated');
      expect(json['nodeId'], 'View.node');
      expect(json['node'], isNotNull);
      expect(json['node']['id'], 'View.node');
    });
  });

  // ----------------------------------------------------------------
  // Integration: server endpoints
  // ----------------------------------------------------------------

  group('XRayBridgeServer', () {
    late XRayBridgeServer server;
    late int port;

    setUp(() async {
      server = XRayBridgeServer(port: 0, localhostOnly: true);
      port = await server.start();
      expect(port, greaterThan(0));
    });

    tearDown(() async {
      await server.stop();
    });

    test('GET /xray/tree returns 503 when no scope is registered', () async {
      XRayBridgeScopeHolder.reset();

      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/xray/tree'));
      final response = await request.close();

      expect(response.statusCode, 503);
      final body = await _jsonBody(response);
      expect(body['error'], 'No active scope');

      client.close();
    });

    test('GET /xray/tree returns 503 when scope is unregistered (duplicate check)', () async {
      // This test verifies the same 503 path as the previous test.
      // We can't create a real XRayScopeState without a widget tree.
      // The 200 path is verified through the XRayTreeJson serialization tests above.
      // The bridge server calls serializeXRayTree which calls
      // scope.tree and scope.viewId — this is a pure data pass-through.
      //
      // For a full integration test with a mounted XRayScope, see the widget test directory.
      XRayBridgeScopeHolder.reset();
      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/xray/tree'));
      final response = await request.close();
      expect(response.statusCode, 503);
      client.close();
    });

    test('POST /xray/action invokes registered action', () async {
      Map<String, dynamic>? received;
      XRayActionRegistry.register('TestView.tapMe', (payload) {
        received = payload;
      });

      final client = HttpClient();
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:$port/xray/action'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'targetNode': 'TestView.tapMe',
        'payload': {'key': 'val'},
      }));
      final response = await request.close();

      expect(response.statusCode, 200);
      final body = await _jsonBody(response);
      expect(body['success'], true);
      expect(body['targetNode'], 'TestView.tapMe');
      expect(received, {'key': 'val'});

      client.close();
    });

    test('POST /xray/action with invalid nodeId returns 404', () async {
      final client = HttpClient();
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:$port/xray/action'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'targetNode': 'NonExistent.node',
        'payload': {},
      }));
      final response = await request.close();

      expect(response.statusCode, 404);
      final body = await _jsonBody(response);
      expect(body['error'], 'Node not found');
      expect(body['availableNodes'], isA<List>());

      client.close();
    });

    test('POST /xray/action without targetNode returns 400', () async {
      final client = HttpClient();
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:$port/xray/action'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'payload': {}}));
      final response = await request.close();

      expect(response.statusCode, 400);

      client.close();
    });

    test('POST /xray/control-deck triggers mock', () async {
      dynamic received;
      XRayMockInjectorRegistry.register('Expired Product', (payload) {
        received = payload;
      });

      final client = HttpClient();
      final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:$port/xray/control-deck'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'mockName': 'Expired Product',
        'payload': 'expired_data',
      }));
      final response = await request.close();

      expect(response.statusCode, 200);
      final body = await _jsonBody(response);
      expect(body['success'], true);
      expect(body['mockName'], 'Expired Product');
      expect(received, 'expired_data');

      client.close();
    });

    test('POST /xray/control-deck with invalid name returns 404', () async {
      final client = HttpClient();
      final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:$port/xray/control-deck'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'mockName': 'NonExistent'}));
      final response = await request.close();

      expect(response.statusCode, 404);
      final body = await _jsonBody(response);
      expect(body['error'], 'Mock not found');
      expect(body['availableMocks'], isA<List>());

      client.close();
    });

    test('POST /xray/control-deck without mockName returns 400', () async {
      final client = HttpClient();
      final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:$port/xray/control-deck'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({}));
      final response = await request.close();

      expect(response.statusCode, 400);

      client.close();
    });

    test('unknown endpoint returns 404', () async {
      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/xray/nonexistent'));
      final response = await request.close();

      expect(response.statusCode, 404);

      client.close();
    });

    test('auth token rejects unauthenticated requests', () async {
      await server.stop();
      server = XRayBridgeServer(
          port: 0, authToken: 'secret123', localhostOnly: true);
      port = await server.start();

      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/xray/tree'));
      final response = await request.close();

      expect(response.statusCode, 401);

      client.close();
    });

    test('server stop and restart works', () async {
      await server.stop();
      expect(server.isRunning, false);

      server = XRayBridgeServer(port: 0, localhostOnly: true);
      port = await server.start();
      expect(server.isRunning, true);
      expect(port, greaterThan(0));
    });
  });

  group('XRayBridgeServer WebSocket', () {
    late XRayBridgeServer server;
    late int port;

    setUp(() async {
      server = XRayBridgeServer(port: 0, localhostOnly: true);
      port = await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('WS returns 503 when no scope is registered', () async {
      XRayBridgeScopeHolder.reset();

      try {
        await WebSocket.connect('ws://127.0.0.1:$port/xray/ws')
            .timeout(const Duration(seconds: 2));
        fail('Should have thrown');
      } catch (e) {
        // The server rejects the upgrade with 503.
        // WebSocket.connect throws on non-101 responses.
        expect(e, isA<WebSocketException>());
      }
    });
  });

  // ----------------------------------------------------------------
  // E2E flow
  // ----------------------------------------------------------------

  group('E2E: inspect tree -> tap button -> verify state change', () {
    late XRayBridgeServer server;
    late int port;

    setUp(() async {
      server = XRayBridgeServer(port: 0, localhostOnly: true);
      port = await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('action invocation without mounted scope (partial flow)', () async {
      // NOTE: This test does NOT perform tree inspection because no XRayScope
      // is mounted in this unit test environment. It verifies action invocation
      // and state changes only. For a complete inspect -> action -> verify flow
      // with actual tree traversal, see widget tests with mounted XRayScope.

      bool buttonPressed = false;
      XRayActionRegistry.register('ProfileView.editProfileButton', (_) {
        buttonPressed = true;
      });

      final client = HttpClient();

      // Step 1: Attempt tree inspection (returns 503 since no scope is mounted)
      final treeRequest = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/xray/tree'));
      final treeResponse = await treeRequest.close();
      expect(treeResponse.statusCode, 503);

      // Step 2: Invoke registered action directly (works without scope)
      final actionRequest = await client
          .postUrl(Uri.parse('http://127.0.0.1:$port/xray/action'));
      actionRequest.headers.set('Content-Type', 'application/json');
      actionRequest.write(jsonEncode({
        'targetNode': 'ProfileView.editProfileButton',
        'payload': {},
      }));
      final actionResponse = await actionRequest.close();
      expect(actionResponse.statusCode, 200);

      // Step 3: Verify action callback was executed
      expect(buttonPressed, true);

      client.close();
    });
  });
}

Future<Map<String, dynamic>> _jsonBody(HttpClientResponse response) async {
  final body = await utf8.decoder.bind(response).join();
  return jsonDecode(body) as Map<String, dynamic>;
}
