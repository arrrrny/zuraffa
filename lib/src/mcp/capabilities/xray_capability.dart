// MCP Server 2.0 — xray.inspect / xray.triggerAction / xray.triggerMock.
//
// These capabilities are runtime-only (require a running Flutter app).
// The MCP server acts as a bridge to the XRay bridge server endpoint.
// When no app is running, the tools return a helpful error.

import 'dart:convert';
import 'dart:io';

/// X-Ray MCP capability — bridges to the running app's X-Ray bridge.
class XrayCapability {
  /// Default X-Ray bridge HTTP port.
  static const int defaultPort = 8372;

  final String? host;
  final int port;

  XrayCapability({this.host, this.port = defaultPort});

  String get _baseUrl => 'http://${host ?? '127.0.0.1'}:$port';

  /// Inspects the live X-Ray widget tree.
  Future<Map<String, dynamic>> inspect() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/xray/tree'));
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return {
          'success': true,
          'tree': jsonDecode(body),
          'error': null,
        };
      } else {
        return {
          'success': false,
          'tree': null,
          'error': 'X-Ray bridge returned ${response.statusCode}: $body',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'tree': null,
        'error': 'Cannot connect to X-Ray bridge at $_baseUrl. Is the app running with xray enabled?',
      };
    } on TimeoutException {
      return {
        'success': false,
        'tree': null,
        'error': 'X-Ray bridge request timed out at $_baseUrl',
      };
    } catch (e) {
      return {
        'success': false,
        'tree': null,
        'error': e.toString(),
      };
    } finally {
      client.close();
    }
  }

  /// Triggers a bound action on an X-Ray node.
  Future<Map<String, dynamic>> triggerAction({
    required String nodeId,
    Map<String, dynamic>? payload,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final body = jsonEncode({
        'nodeId': nodeId,
        if (payload != null) 'payload': payload,
      });
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/xray/action'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 10));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Action triggered on $nodeId',
          'response': jsonDecode(responseBody),
        };
      } else {
        return {
          'success': false,
          'message': 'Action failed: ${response.statusCode}',
          'response': responseBody,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'Cannot connect to X-Ray bridge at $_baseUrl. Is the app running?',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'X-Ray bridge request timed out at $_baseUrl',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    } finally {
      client.close();
    }
  }

  /// Triggers a mock injection via the Control Deck.
  Future<Map<String, dynamic>> triggerMock({
    required String mockName,
    dynamic payload,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final body = jsonEncode({
        'mockName': mockName,
        'payload': payload,
      });
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/xray/mock'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 10));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Mock "$mockName" triggered',
          'response': jsonDecode(responseBody),
        };
      } else {
        return {
          'success': false,
          'message': 'Mock trigger failed: ${response.statusCode}',
          'response': responseBody,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'Cannot connect to X-Ray bridge at $_baseUrl. Is the app running?',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'X-Ray bridge request timed out at $_baseUrl',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    } finally {
      client.close();
    }
  }
}
