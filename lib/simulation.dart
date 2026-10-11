// Public entry point for the zuraffa simulation flavor (spec 893,
// parent epic #908 Mock-First Realization, closes #914).
//
// Import as `package:zuraffa/simulation.dart`. Generated simulation DI
// bindings (`di/simulation/`) and `SimulationBoot` depend on this barrel;
// hand-written composition roots import it to check the flavor and to
// boot the app on certified mocks.
//
// Spec 968 (simulation worlds): the `src/simulation/worlds/` barrel below
// exposes the scenario-world machinery — manifests, virtual clock,
// latency models, failure storms, the world runtime, the retry-with-
// backoff demo engine, certification, the differential gate, and run
// receipts — so temporal features are developed green inside committed,
// CI-verifiable worlds.
export 'src/simulation/simulation_flavor.dart';
export 'src/simulation/network_isolation_guard.dart';
export 'src/simulation/simulation_whitelist.dart';
export 'src/simulation/simulation_boot.dart';
export 'src/simulation/entity_fixture.dart';
export 'src/simulation/worlds/world_manifest.dart';
export 'src/simulation/worlds/virtual_clock.dart';
export 'src/simulation/worlds/latency_model.dart';
export 'src/simulation/worlds/failure_schedule.dart';
export 'src/simulation/worlds/world_runtime.dart';
export 'src/simulation/worlds/retry_sync_engine.dart';
export 'src/simulation/worlds/world_certification.dart';
export 'src/simulation/worlds/world_differential_gate.dart';
export 'src/simulation/worlds/world_store.dart';
export 'src/simulation/worlds/world_run_receipt.dart';
