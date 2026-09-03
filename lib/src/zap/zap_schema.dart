/// ZAP draft-07 JSON Schemas (spec 071, issue #809, FR-006).
///
/// The code is the SOURCE OF TRUTH; `zfa zap schema --export <dir>` writes
/// these maps to `schemas/*.schema.json` (committed under the spec dir),
/// and `zfa zap conform --drift-dir <dir>` fails on any drift between the
/// committed files and the code — the published contract can never go
/// stale silently.
///
/// Every envelope is CLOSED (`additionalProperties: false`): a
/// hallucinated field is a schema error with the field's path, not a
/// silent ignore. Schemas deliberately avoid draft-07 conditionals so
/// every draft-07 validator (including minimal third-party ones) can
/// enforce them; kind-specific requirements (e.g. `restore` needs
/// `stateId`) live in the typed layer.
library;

import 'zap_protocol.dart';

/// ISO-8601 UTC timestamp with a `Z` suffix (the canonical ZAP clock).
const String _tsPattern = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$';

/// Lowercase sha256 hex digest.
const String _digestPattern = r'^[a-f0-9]{64}$';

/// The draft-07 subset this implementation's schemas are limited to.
const String zapDraft = 'http://json-schema.org/draft-07/schema#';

/// Shared envelope properties for every message type.
Map<String, Object?> _envelopeProps(String type) => <String, Object?>{
  'zap': {
    'type': 'string',
    'enum': [zapProtocolVersion],
    'description':
        'ZAP protocol version ($zapProtocolVersion = the '
        'v0 slice of issue #809)',
  },
  'type': {
    'type': 'string',
    'enum': [type],
  },
  'id': {
    'type': 'string',
    'minLength': 1,
    'description': 'Unique message id (host: UUID v4)',
  },
  'ts': {
    'type': 'string',
    'pattern': _tsPattern,
    'description': 'ISO-8601 UTC with Z suffix',
  },
};

Map<String, Object?> _schema(
  String type,
  String title,
  List<String> required,
  Map<String, Object?> properties,
) => <String, Object?>{
  '\$schema': zapDraft,
  'title': 'ZAP $title (v$zapProtocolVersion)',
  'type': 'object',
  'additionalProperties': false,
  'required': required,
  'properties': properties,
};

const Map<String, Object?> _stepPhase = {
  'type': 'string',
  'enum': ['red', 'green', 'refactor', 'verify'],
};

/// Schema registry — exactly the five wire types.
final Map<String, Map<String, Object?>> _schemas = {
  'mission': _schema(
    'mission',
    'Mission Envelope',
    [
      'zap',
      'type',
      'id',
      'ts',
      'missionId',
      'agent',
      'goal',
      'budget',
      'policy',
      'steps',
    ],
    {
      ..._envelopeProps('mission'),
      'missionId': {
        'type': 'string',
        'minLength': 1,
        'description':
            'Session key; later missions with the same id '
            'CONTINUE the session',
      },
      'agent': {
        'type': 'string',
        'minLength': 1,
        'description': 'Who is asking (framework name)',
      },
      'goal': {
        'type': 'string',
        'minLength': 1,
        'description': 'Human-readable intent',
      },
      'feature': {
        'type': 'string',
        'minLength': 1,
        'description': 'Optional zuraffa feature slug',
      },
      'budget': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['maxSteps'],
        'properties': {
          'maxSteps': {
            'type': 'integer',
            'minimum': 1,
            'description':
                'Session step budget; FIXED by the first '
                'mission (self-escalation is rejected)',
          },
        },
      },
      'policy': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['riskTier'],
        'properties': {
          'riskTier': {
            'type': 'string',
            'enum': ['standard', 'elevated', 'admin'],
          },
          'toolAllowlist': {
            'type': 'array',
            'minItems': 1,
            'uniqueItems': true,
            'items': {
              'type': 'string',
              'minLength': 1,
              'description':
                  'Allowed executable (first token of each '
                  'step command)',
            },
          },
        },
      },
      'steps': {
        'type': 'array',
        'minItems': 1,
        'description': 'Work requested; executed in order without a shell',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['id', 'command', 'phase'],
          'properties': {
            'id': {'type': 'string', 'minLength': 1},
            'command': {
              'type': 'string',
              'minLength': 1,
              'description':
                  'Whitespace-tokenized; first token must be '
                  'in the session allowlist',
            },
            'description': {'type': 'string'},
            'phase': _stepPhase,
            'timeoutSeconds': {'type': 'integer', 'minimum': 1, 'maximum': 600},
          },
        },
      },
    },
  ),
  'evidence': _schema(
    'evidence',
    'Evidence Packet',
    [
      'zap',
      'type',
      'id',
      'ts',
      'missionId',
      'stepId',
      'phase',
      'command',
      'exit',
      'digest',
      'at',
    ],
    {
      ..._envelopeProps('evidence'),
      'missionId': {'type': 'string', 'minLength': 1},
      'stepId': {'type': 'string', 'minLength': 1},
      'phase': _stepPhase,
      'command': {
        'type': 'string',
        'minLength': 1,
        'description': 'Echo of the executed command (a certified fact)',
      },
      'exit': {
        'type': 'integer',
        'description':
            'Real process exit code; 124 = timeout convention; '
            'can be negative on signals',
      },
      'digest': {
        'type': 'string',
        'pattern': _digestPattern,
        'description': 'sha256 hex of the captured combined output',
      },
      'at': {
        'type': 'string',
        'pattern': _tsPattern,
        'description': 'When the step completed',
      },
      'durationMs': {'type': 'integer', 'minimum': 0},
      'output': {
        'type': 'string',
        'description':
            'Capped preview (2000 chars); the digest covers '
            'the FULL output',
      },
    },
  ),
  'checkpoint': _schema(
    'checkpoint',
    'Checkpoint Message',
    ['zap', 'type', 'id', 'ts', 'missionId', 'kind'],
    {
      ..._envelopeProps('checkpoint'),
      'missionId': {'type': 'string', 'minLength': 1},
      'kind': {
        'type': 'string',
        'enum': ['save', 'restore', 'saved', 'restored'],
      },
      'stateId': {
        'type': 'string',
        'minLength': 1,
        'description': 'Required for restore; host-generated for save',
      },
      'digest': {
        'type': 'string',
        'pattern': _digestPattern,
        'description':
            'sha256 of the canonical snapshot (saved/restored '
            'replies)',
      },
      'steps': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Evidence count at snapshot time',
      },
      'at': {'type': 'string', 'pattern': _tsPattern},
    },
  ),
  'receipt': _schema(
    'receipt',
    'Receipt',
    [
      'zap',
      'type',
      'id',
      'ts',
      'missionId',
      'verdict',
      'exit',
      'chainDigest',
      'stepsExecuted',
      'stepsTotal',
      'checks',
      'at',
    ],
    {
      ..._envelopeProps('receipt'),
      'missionId': {'type': 'string', 'minLength': 1},
      'verdict': {
        'type': 'string',
        'enum': ['pass', 'fail'],
      },
      'exit': {
        'type': 'integer',
        'enum': [0, 1],
        'description': 'The receipt\'s exit (0 = pass, 1 = fail)',
      },
      'chainDigest': {
        'type': 'string',
        'pattern': _digestPattern,
        'description':
            'Head of the evidence chain — the client '
            'recomputes and compares (receipt verification)',
      },
      'stepsExecuted': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Session-cumulative executed steps',
      },
      'stepsTotal': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Session-cumulative accepted steps',
      },
      'checks': {
        'type': 'array',
        'minItems': 1,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['name', 'ok'],
          'properties': {
            'name': {'type': 'string', 'minLength': 1},
            'ok': {'type': 'boolean'},
            'detail': {'type': 'string'},
          },
        },
      },
      'at': {'type': 'string', 'pattern': _tsPattern},
    },
  ),
  'error': _schema(
    'error',
    'Error Envelope',
    ['zap', 'type', 'id', 'ts', 'code', 'message'],
    {
      ..._envelopeProps('error'),
      'code': {
        'type': 'string',
        'enum': [
          'schema',
          'version',
          'direction',
          'budget',
          'policy',
          'unknown-mission',
          'bad-checkpoint',
          'internal',
        ],
      },
      'message': {'type': 'string', 'minLength': 1},
      'inReplyTo': {
        'type': 'string',
        'minLength': 1,
        'description': 'The rejected message\'s id, when known',
      },
      'details': {
        'type': 'array',
        'items': {'type': 'string', 'minLength': 1},
        'description': 'Precise validation issues (JSON paths)',
      },
    },
  ),
};

/// Access to the five ZAP schemas (draft-07 maps).
abstract final class ZapSchema {
  /// The schema for [type]; throws [ArgumentError] for unknown types.
  static Map<String, Object?> forType(String type) {
    final schema = _schemas[type];
    if (schema == null) {
      throw ArgumentError.value(
        type,
        'type',
        'unknown ZAP message type (expected one of '
            '${_schemas.keys.join(', ')})',
      );
    }
    return schema;
  }

  /// All five schemas keyed by type (defensive copies of the maps).
  static Map<String, Map<String, Object?>> get all =>
      _schemas.map((type, schema) => MapEntry(type, {...schema}));

  /// The published wire types, in contract order.
  static List<String> get types => _schemas.keys.toList(growable: false);
}
