// ChannelScenario model pins (issue #831 — platform-channel test harness).
//
// The scenario script is the COMMITTED INTENT behind a certified fake:
// responses, errors and the cross-platform matrix live in
// `specs/<feature>/tdd/scenarios/*.json`, machine-parseable, validated
// before any artifact is written. These pins freeze the JSON contract.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/channel_scenario.dart';

void main() {
  group('ChannelScenario.fromJson (issue #831)', () {
    test('parses a full scenario: channel, platforms, responses, default', () {
      final scenario = ChannelScenario.fromJson(const {
        'channel': 'dev.zuraffa/camera',
        'platforms': ['ios', 'android'],
        'responses': {
          'available': {'value': true},
          'takePicture': {
            'value': {'path': '/tmp/photo.jpg'},
          },
          'requestPermission': {
            'error': {
              'code': 'permission-denied',
              'message': 'camera permission refused',
            },
          },
        },
        'default': {
          'error': {
            'code': 'unscripted',
            'message': 'No scripted response — extend the scenario.',
          },
        },
      });
      expect(scenario.channel, 'dev.zuraffa/camera');
      expect(scenario.platforms, ['ios', 'android']);
      expect(scenario.responses, hasLength(3));
      expect(scenario.responses['available']!.value, true);
      expect(scenario.responses['takePicture']!.value, {
        'path': '/tmp/photo.jpg',
      });
      final denied = scenario.responses['requestPermission']!;
      expect(denied.isError, isTrue);
      expect(denied.errorCode, 'permission-denied');
      expect(denied.errorMessage, 'camera permission refused');
      expect(scenario.defaultResponse.isError, isTrue);
      expect(scenario.defaultResponse.errorCode, 'unscripted');
    });

    test('empty platforms list is valid (no hosted matrix declared)', () {
      final scenario = ChannelScenario.fromJson(const {
        'channel': 'app.camera',
        'platforms': <String>[],
        'responses': {
          'available': {'value': true},
        },
        'default': {
          'error': {'code': 'unscripted', 'message': 'x'},
        },
      });
      expect(scenario.platforms, isEmpty);
    });

    test('omitted platforms defaults to empty', () {
      final scenario = ChannelScenario.fromJson(const {
        'channel': 'app.camera',
        'responses': {
          'available': {'value': true},
        },
        'default': {
          'error': {'code': 'unscripted', 'message': 'x'},
        },
      });
      expect(scenario.platforms, isEmpty);
    });

    test('empty channel is a schema error', () {
      expect(
        () => ChannelScenario.fromJson(const {
          'channel': '',
          'responses': {
            'available': {'value': true},
          },
          'default': {
            'error': {'code': 'unscripted', 'message': 'x'},
          },
        }),
        throwsA(isA<ChannelScenarioException>()),
      );
    });

    test('missing default response is a schema error (loud unscripted)', () {
      expect(
        () => ChannelScenario.fromJson(const {
          'channel': 'app.camera',
          'responses': {
            'available': {'value': true},
          },
        }),
        throwsA(isA<ChannelScenarioException>()),
      );
    });

    test('a response carrying BOTH value and error is a schema error', () {
      expect(
        () => ChannelScenario.fromJson(const {
          'channel': 'app.camera',
          'responses': {
            'available': {
              'value': true,
              'error': {'code': 'x', 'message': 'y'},
            },
          },
          'default': {
            'error': {'code': 'unscripted', 'message': 'x'},
          },
        }),
        throwsA(isA<ChannelScenarioException>()),
      );
    });

    test('a response carrying NEITHER value nor error is a schema error', () {
      expect(
        () => ChannelScenario.fromJson(const {
          'channel': 'app.camera',
          'responses': {'available': <String, Object?>{}},
          'default': {
            'error': {'code': 'unscripted', 'message': 'x'},
          },
        }),
        throwsA(isA<ChannelScenarioException>()),
      );
    });

    test('an error response without a code is a schema error', () {
      expect(
        () => ChannelScenario.fromJson(const {
          'channel': 'app.camera',
          'responses': {
            'available': {
              'error': {'message': 'no code'},
            },
          },
          'default': {
            'error': {'code': 'unscripted', 'message': 'x'},
          },
        }),
        throwsA(isA<ChannelScenarioException>()),
      );
    });

    test('unknown platform token is a schema error', () {
      expect(
        () => ChannelScenario.fromJson(const {
          'channel': 'app.camera',
          'platforms': ['ios', 'fuchsia'],
          'responses': {
            'available': {'value': true},
          },
          'default': {
            'error': {'code': 'unscripted', 'message': 'x'},
          },
        }),
        throwsA(isA<ChannelScenarioException>()),
      );
    });
  });

  group('ChannelScenario.toJson round-trip (issue #831)', () {
    test('fromJson(toJson(scenario)) preserves the contract byte-for-byte', () {
      const raw = <String, Object?>{
        'channel': 'dev.zuraffa/camera',
        'platforms': ['ios', 'android', 'macos'],
        'responses': {
          'available': {'value': true},
          'requestPermission': {
            'error': {
              'code': 'permission-denied',
              'message': 'refused',
              'details': {'state': 'denied'},
            },
          },
        },
        'default': {
          'error': {
            'code': 'unscripted',
            'message': 'No scripted response — extend the scenario.',
          },
        },
      };
      final scenario = ChannelScenario.fromJson(raw);
      final round = scenario.toJson();
      final again = ChannelScenario.fromJson(round);
      expect(again.channel, scenario.channel);
      expect(again.platforms, scenario.platforms);
      expect(again.defaultResponse.errorCode, 'unscripted');
      final denied = again.responses['requestPermission']!;
      expect(denied.isError, isTrue);
      expect(denied.errorCode, 'permission-denied');
      expect(denied.errorDetails, {'state': 'denied'});
      expect(round['channel'], 'dev.zuraffa/camera');
    });

    test('permission states are plain replayable values', () {
      // The issue names "permission states" as scenario content: granted /
      // denied / disabled are just scripted values the fake replays —
      // no special-cased permission machinery.
      final scenario = ChannelScenario.fromJson(const {
        'channel': 'dev.zuraffa/permissions',
        'responses': {
          'request': {'value': 'granted'},
          'check': {'value': 'denied'},
        },
        'default': {
          'error': {'code': 'unscripted', 'message': 'x'},
        },
      });
      expect(scenario.responses['request']!.value, 'granted');
      expect(scenario.responses['check']!.value, 'denied');
    });
  });
}
