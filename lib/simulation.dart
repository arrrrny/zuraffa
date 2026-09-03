// Public entry point for the zuraffa simulation flavor (spec 893,
// parent epic #908 Mock-First Realization, closes #914).
//
// Import as `package:zuraffa/simulation.dart`. Generated simulation DI
// bindings (`di/simulation/`) and `SimulationBoot` depend on this barrel;
// hand-written composition roots import it to check the flavor and to
// boot the app on certified mocks.
export 'src/simulation/simulation_flavor.dart';
