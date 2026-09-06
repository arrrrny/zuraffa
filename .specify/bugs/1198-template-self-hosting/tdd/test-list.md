# Test List: 1198-template-self-hosting

## Acceptance Behaviors

- [ ] A1: every generator template (usecase, service, repository, datasource,
      mock, di, view/skin, state, route) has a template-level TDD-loop suite
      against the shared fixture entity (Product) covering structural +
      compile + behavioral tiers.
- [ ] A2: a diff guard proves regenerated output for identical inputs is
      byte-stable, and writes a determinism receipt
      (`template.determinism.v1`) into the fixture's `.zfa/` home.
- [ ] A3: a downstream-compile gate emits ALL templates into one minimal
      Flutter package and asserts it analyzes clean (the #1189/#1190-class
      referee at template level).
- [ ] A4: templates that fail the loop BLOCK publish —
      `tools/template_publish_gate.sh` runs both lanes and is wired into
      CI (job `template_publish_gate`) and into the release workflow BEFORE
      the build/publish steps.
- [ ] A5: template defects surfaced by the loop are fixed at template level
      (RED → GREEN): the route template now satisfies the generated view's
      required repository constructor arg.

## Suite map

| Template | Suite (test/templates/self_hosting/) |
| -------- | ------------------------------------ |
| usecase | usecase_template_self_hosting_test.dart |
| service | service_template_self_hosting_test.dart |
| repository | repository_template_self_hosting_test.dart |
| datasource | datasource_template_self_hosting_test.dart |
| mock | mock_template_self_hosting_test.dart |
| di | di_template_self_hosting_test.dart |
| view/skin | view_template_self_hosting_test.dart (+ downstream gate) |
| state | state_template_self_hosting_test.dart |
| route | route_template_self_hosting_test.dart (+ downstream gate) |
| diff guard | per-template `diff guard` groups (determinism receipt) |
| downstream gate | downstream_compile_gate_test.dart (@Tags flutter) |
| publish blocking | publish_gate_test.dart + tools/template_publish_gate.sh |
