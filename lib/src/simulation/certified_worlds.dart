/// The certified default simulation worlds (bug #832, VISION §9).
///
/// `zfa simulate --scaffold` materializes these golden contracts into
/// `specs/<feature>/tdd/fixtures/` and hashes them into the cycle-log
/// evidence — fixture commitment is automated, never hand-written. Once
/// committed, the fixtures on disk are the contract: `SimulationWorld.load`
/// verifies every byte against the manifest hash and refuses tampered
/// worlds.
///
/// These defaults are deliberately deterministic: fixed users, recorded
/// golden GraphQL responses, recorded JSON fixtures, scripted faults, and
/// zero jitter latency. Re-scaffolding from the same certified world
/// always yields byte-identical fixtures.
library;

/// The five adapter families (bug #832).
const simulationFamilies = <String>[
  'firebase-auth',
  'vendure',
  'rest',
  'admob',
  'otel',
];

/// Fixture file each family materializes into.
const simulationFamilyFiles = <String, String>{
  'firebase-auth': 'auth-world.json',
  'vendure': 'vendure-golden.json',
  'rest': 'rest-world.json',
  'admob': 'admob-world.json',
  'otel': 'otel-world.json',
};

/// Certified Firebase Auth world: one clean credential path, one scripted
/// account-level error surface, no forced recent-login requirement.
const certifiedAuthWorld = <String, dynamic>{
  'family': 'firebase-auth',
  'initialUser': null,
  'users': [
    {
      'email': 'ada@example.com',
      'password': 's3cret!',
      'uid': 'u-ada-001',
      'displayName': 'Ada Lovelace',
    },
  ],
  'scriptedErrors': [
    {'email': 'disabled@example.com', 'code': 'user-disabled'},
  ],
  'deletionRequiresRecentLogin': false,
  'latencyMs': 0,
};

/// Certified Vendure world: recorded golden GraphQL responses for the
/// product query and the add-item-to-order mutation, plus a recorded
/// error surface for search.
const certifiedVendureWorld = <String, dynamic>{
  'family': 'vendure',
  'goldenQueries': {
    'product': {
      'data': {
        'product': {
          'id': '1',
          'name': 'Kayak',
          'description': 'Certified golden product record',
        },
      },
      'errors': null,
    },
  },
  'goldenMutations': {
    'addItemToOrder': {
      'data': {
        'addItemToOrder': {'id': '9', 'quantity': 1},
      },
      'errors': null,
    },
  },
  'scriptedErrors': {
    'search': [
      {'message': 'Insufficient stock', 'code': 'STOCK_ERROR'},
    ],
  },
  'latencyMs': 0,
};

/// Certified REST world covering the REST-family services: Market Fiyati
/// market quotes, Google Shopping search, generic list creation, and a
/// scripted unstable endpoint for fault-injection flows.
const certifiedRestWorld = <String, dynamic>{
  'family': 'rest',
  'fixtures': {
    'GET /v1/quote/USD-TRY': {
      'status': 200,
      'body': {
        'symbol': 'USD-TRY',
        'price': 41.2,
        'change': -0.15,
      },
    },
    'GET /v1/search?q=kayak': {
      'status': 200,
      'body': {
        'results': [
          {'title': 'Kayak 1', 'price': 2499.0},
          {'title': 'Kayak 2', 'price': 3199.0},
        ],
      },
    },
    'POST /v1/lists': {
      'status': 201,
      'body': {'id': 'list-1'},
    },
  },
  'scriptedFaults': {
    'GET /v1/unstable': 500,
  },
  'latencyMs': 0,
};

/// Certified AdMob world: deterministic happy path; failures are scripted
/// per-test via `AdMobAdapter.scriptLoadFailure` / `scriptShowFailure`.
const certifiedAdmobWorld = <String, dynamic>{
  'family': 'admob',
  'scriptedLoadFailure': null,
  'scriptedShowFailure': null,
  'latencyMs': 0,
};

/// Certified OpenTelemetry world: the capture-and-assert exporter records
/// spans produced through the real SDK pipeline; `expectedSpans` names
/// the spans a healthy certified run must observe.
const certifiedOtelWorld = <String, dynamic>{
  'family': 'otel',
  'service': 'zuraffa-simulation',
  'expectedSpans': ['usecase.PlaceOrder'],
};

/// The certified world for [family], or `null` for an unknown family.
Map<String, dynamic>? certifiedWorldFor(String family) => switch (family) {
      'firebase-auth' => certifiedAuthWorld,
      'vendure' => certifiedVendureWorld,
      'rest' => certifiedRestWorld,
      'admob' => certifiedAdmobWorld,
      'otel' => certifiedOtelWorld,
      _ => null,
    };
