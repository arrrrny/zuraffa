00:00 +0: loading test/tier_integrity_test.dart
00:00 +0: the regression tier exists and is non-trivial
00:00 +1: B1: every regression-tier file carries the regression tag
00:00 +2: B2: dart_test.yaml defines the regression preset
00:00 +3: B3: every e2e-tagged file is selected by --preset=all
00:00 +4: B4: the dart_core fast lane excludes every e2e-tagged file
00:00 +5: B5: the fast-lane budget census — no untagged heavyweight suite rides the dart_core lane (#1632)
00:00 +5 -1: B5: the fast-lane budget census — no untagged heavyweight suite rides the dart_core lane (#1632) [E]
  Expected: empty
    Actual: [
              'test/skin/vm_tap_driver_test.dart — spawns external processes (carries: )',
              'test/package_sdk/plugin_scaffold_test.dart — spawns external processes (carries: )',
              'test/skew/bug_1197_two_end_matrix_test.dart — spawns external processes (carries: )',
              'test/core/generation/tracked_generated_output_guard_test.dart — spawns external processes (carries: )',
              'test/plugins/datasource/datasource_engine_compile_test.dart — compile/self-hosting gate (carries: )',
              'test/plugins/datasource/datasource_compile_test.dart — spawns external processes (carries: )',
              'test/plugins/repository/repository_compile_test.dart — spawns external processes (carries: )',
              'test/plugins/repository/repository_engine_compile_test.dart — compile/self-hosting gate (carries: )',
              'test/plugins/di/di_setup_execution_test.dart — spawns external processes (carries: )',
              'test/plugins/cache/cache_compile_test.dart — spawns external processes (carries: )',
              'test/plugins/slice/capabilities/slice_worktree_capability_test.dart — spawns external processes (carries: )',
              'test/plugins/slice/capabilities/slice_check_capability_test.dart — spawns external processes (carries: )',
              'test/plugins/slice/slice_command_worktree_check_test.dart — spawns external processes (carries: )',
              'test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart — spawns external processes (carries: )',
              'test/plugins/mock/mock_provider_engine_behavior_test.dart — spawns external processes (carries: )',
              'test/plugins/mock/mock_provider_builder_test.dart — spawns external processes (carries: )',
              'test/plugins/mock/mock_datasource_builder_1570_compile_test.dart — compile/self-hosting gate (carries: )',
              'test/plugins/mock/mock_provider_engine_compile_test.dart — compile/self-hosting gate (carries: )',
              'test/plugins/use_case/use_case_engine_compile_test.dart — compile/self-hosting gate (carries: )',
              'test/plugins/use_case/use_case_engine_behavior_test.dart — spawns external processes (carries: )',
              'test/plugins/state/state_compile_test.dart — spawns external processes (carries: )',
              'test/plugins/state/state_property_compile_test.dart — spawns external processes (carries: )',
              'test/plugins/sync/simulate_sync_capability_test.dart — spawns external processes (carries: )',
              'test/plugins/service/service_engine_compile_test.dart — compile/self-hosting gate (carries: )',
              ...
            ]
  fast-lane-eligible files that spawn external processes or run analyzer/compile self-hosting gates must carry `e2e` (process-spawning/temp-project suites, the #1510 semantics) or `slow` (in-process slow suites) — the untagged drift is what cancelled dart_core at its 30-minute ceiling (#1632):
  test/skin/vm_tap_driver_test.dart — spawns external processes (carries: )
  test/package_sdk/plugin_scaffold_test.dart — spawns external processes (carries: )
  test/skew/bug_1197_two_end_matrix_test.dart — spawns external processes (carries: )
  test/core/generation/tracked_generated_output_guard_test.dart — spawns external processes (carries: )
  test/plugins/datasource/datasource_engine_compile_test.dart — compile/self-hosting gate (carries: )
  test/plugins/datasource/datasource_compile_test.dart — spawns external processes (carries: )
  test/plugins/repository/repository_compile_test.dart — spawns external processes (carries: )
  test/plugins/repository/repository_engine_compile_test.dart — compile/self-hosting gate (carries: )
  test/plugins/di/di_setup_execution_test.dart — spawns external processes (carries: )
  test/plugins/cache/cache_compile_test.dart — spawns external processes (carries: )
  test/plugins/slice/capabilities/slice_worktree_capability_test.dart — spawns external processes (carries: )
  test/plugins/slice/capabilities/slice_check_capability_test.dart — spawns external processes (carries: )
  test/plugins/slice/slice_command_worktree_check_test.dart — spawns external processes (carries: )
  test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart — spawns external processes (carries: )
  test/plugins/mock/mock_provider_engine_behavior_test.dart — spawns external processes (carries: )
  test/plugins/mock/mock_provider_builder_test.dart — spawns external processes (carries: )
  test/plugins/mock/mock_datasource_builder_1570_compile_test.dart — compile/self-hosting gate (carries: )
  test/plugins/mock/mock_provider_engine_compile_test.dart — compile/self-hosting gate (carries: )
  test/plugins/use_case/use_case_engine_compile_test.dart — compile/self-hosting gate (carries: )
  test/plugins/use_case/use_case_engine_behavior_test.dart — spawns external processes (carries: )
  test/plugins/state/state_compile_test.dart — spawns external processes (carries: )
  test/plugins/state/state_property_compile_test.dart — spawns external processes (carries: )
  test/plugins/sync/simulate_sync_capability_test.dart — spawns external processes (carries: )
  test/plugins/service/service_engine_compile_test.dart — compile/self-hosting gate (carries: )
  test/plugins/service/service_compile_test.dart — spawns external processes (carries: )
  test/plugins/usecase/usecase_compile_test.dart — spawns external processes (carries: )
  test/plugins/usecase/usecase_command_grammar_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart — spawns external processes (carries: regression)
  test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart — spawns external processes (carries: regression)
  test/plugins/tdd/spec_1529_recert_wiring_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_924_verify_preflight_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_1520_refactor_scratch_tmpdir_test.dart — spawns external processes (carries: regression)
  test/plugins/tdd/bug_993_plan_entity_export_clash_test.dart — spawns external processes (carries: regression)
  test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart — spawns external processes (carries: )
  test/plugins/tdd/issue_1590_progress_liveness_test.dart — spawns external processes (carries: )
  test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart — spawns external processes (carries: )
  test/plugins/tdd/commands/run_command_bug_1471_test.dart — spawns external processes (carries: )
  test/plugins/tdd/commands/contract_kind_1007_test.dart — spawns external processes (carries: )
  test/plugins/tdd/commands/run_driver_timeout_receipt_test.dart — spawns external processes (carries: )
  test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart — spawns external processes (carries: )
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_1133_flutter_compact_transcript_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_912_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/plugins/tdd/issue_1482_run_preflight_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/refactor_passes_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/subprocess_timeout_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/test_list_reader_984_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/run_state_store_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/dependency_override_preflight_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/step_runner_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart — spawns external processes (carries: )
  test/plugins/tdd/services/pipeline_runner_test.dart — spawns external processes (carries: )
  test/plugins/tdd/bug_1500_wire_contract_subject_test.dart — spawns external processes (carries: )
  test/plugins/tdd/scratch_tmpdir_test.dart — spawns external processes (carries: regression)
  test/tier_integrity_test.dart — spawns external processes (carries: )
  test/simulation/simulate_command_test.dart — spawns external processes (carries: )
  test/simulation/worlds/simulate_worlds_command_test.dart — spawns external processes (carries: )
  test/simulation/simulation_flavor_test.dart — spawns external processes (carries: )
  test/simulation/adapter_parity_checker_test.dart — spawns external processes (carries: )
  test/cli/binary_staleness_test.dart — spawns external processes (carries: )
  test/cli/zfa_executable_test.dart — spawns external processes (carries: )
  test/cli/bug_1360_undeclared_option_crash_test.dart — spawns external processes (carries: )
  test/cli/standard/cli_plugin_generator_test.dart — spawns external processes (carries: )
  test/scripts/create_new_feature_branch_test.dart — spawns external processes (carries: )
  test/templates/self_hosting/datasource_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/route_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/state_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/mock_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/di_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/repository_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/publish_gate_test.dart — spawns external processes (carries: )
  test/templates/self_hosting/usecase_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/service_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/templates/self_hosting/view_template_self_hosting_test.dart — compile/self-hosting gate (carries: )
  test/commands/make_engine_plan_test.dart — spawns external processes (carries: )
  test/commands/project_root_autodetect_test.dart — spawns external processes (carries: )
  test/commands/entity_cli_exit_code_test.dart — spawns external processes (carries: )
  test/commands/make_pubsync_zuraffa_ensure_test.dart — spawns external processes (carries: )
  test/commands/make_default_tier_plan_test.dart — spawns external processes (carries: )
  test/commands/bug_1378_proof_prune_test.dart — spawns external processes (carries: )
  test/commands/engine_check_command_test.dart — spawns external processes (carries: )
  test/commands/entity_help_test.dart — spawns external processes (carries: )
  test/commands/entity_create_primitive_types_test.dart — spawns external processes (carries: )
  test/commands/entity_convergent_test.dart — spawns external processes (carries: )
  test/commands/entity_receipt_test.dart — spawns external processes (carries: )
  test/commands/proof_chain_command_test.dart — spawns external processes (carries: )
  test/commands/exit_code_sweep_1139_test.dart — spawns external processes (carries: )
  test/commands/xray_deck_cli_test.dart — spawns external processes (carries: )
  test/commands/build_command_tracked_outputs_test.dart — spawns external processes (carries: )
  test/commands/dead_positional_grammar_test.dart — spawns external processes (carries: )
  test/commands/proof_command_test.dart — spawns external processes (carries: )
  test/regression/issue_1132_slice_bare_exit_code_test.dart — spawns external processes (carries: regression)
  test/regression/issue_1188_gitignore_progress_md_test.dart — spawns external processes (carries: regression)
  test/regression/issue_942_entity_name_collides_framework_export_test.dart — spawns external processes (carries: regression)
  test/regression/issue_1385_1386_zero_artifact_honesty_test.dart — spawns external processes (carries: regression)
  test/regression/issue_1185_make_view_no_methods_test.dart — spawns external processes (carries: regression)
  test/regression/issue_1059_entity_cli_bare_exit_code_test.dart — spawns external processes (carries: regression)
  test/helpers/zfa_test_timeout_scale_test.dart — spawns external processes (carries: )
  
  package:matcher                      expect
  test/tier_integrity_test.dart 182:5  main.<fn>
  
00:00 +5 -1: B6: every regression-tagged file also carries slow (#1632)
00:00 +5 -2: B6: every regression-tagged file also carries slow (#1632) [E]
  Expected: empty
    Actual: [
              'test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart',
              'test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart',
              'test/plugins/tdd/make_command_declared_071_test.dart',
              'test/plugins/tdd/bug_1520_refactor_scratch_tmpdir_test.dart',
              'test/plugins/tdd/bug_993_plan_entity_export_clash_test.dart',
              'test/plugins/tdd/scratch_tmpdir_test.dart',
              'test/plugins/tdd/kernel_cache_age_guard_test.dart',
              'test/plugins/tdd/make_command_test.dart',
              'test/regression/issue_1132_slice_bare_exit_code_test.dart',
              'test/regression/issue_1173_engine_purity_test.dart',
              'test/regression/issue_1188_gitignore_progress_md_test.dart',
              'test/regression/issue_942_entity_name_collides_framework_export_test.dart',
              'test/regression/issue_1385_1386_zero_artifact_honesty_test.dart',
              'test/regression/issue_891_example_meta_resolution_test.dart',
              'test/regression/issue_1185_make_view_no_methods_test.dart',
              'test/regression/issue_359_route_shell_test.dart',
              'test/regression/issue_1059_entity_cli_bare_exit_code_test.dart'
            ]
  the tier's default-lane exclusion is the `slow` tag — a regression-only tag leaks the file into every default `dart test` (the documented dart_test.yaml invariant):
  test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart
  test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart
  test/plugins/tdd/make_command_declared_071_test.dart
  test/plugins/tdd/bug_1520_refactor_scratch_tmpdir_test.dart
  test/plugins/tdd/bug_993_plan_entity_export_clash_test.dart
  test/plugins/tdd/scratch_tmpdir_test.dart
  test/plugins/tdd/kernel_cache_age_guard_test.dart
  test/plugins/tdd/make_command_test.dart
  test/regression/issue_1132_slice_bare_exit_code_test.dart
  test/regression/issue_1173_engine_purity_test.dart
  test/regression/issue_1188_gitignore_progress_md_test.dart
  test/regression/issue_942_entity_name_collides_framework_export_test.dart
  test/regression/issue_1385_1386_zero_artifact_honesty_test.dart
  test/regression/issue_891_example_meta_resolution_test.dart
  test/regression/issue_1185_make_view_no_methods_test.dart
  test/regression/issue_359_route_shell_test.dart
  test/regression/issue_1059_entity_cli_bare_exit_code_test.dart
  
  package:matcher                      expect
  test/tier_integrity_test.dart 204:5  main.<fn>
  
00:00 +5 -2: Some tests failed.

Failing tests:
  test/tier_integrity_test.dart: B5: the fast-lane budget census — no untagged heavyweight suite rides the dart_core lane (#1632)
  test/tier_integrity_test.dart: B6: every regression-tagged file also carries slow (#1632)

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
