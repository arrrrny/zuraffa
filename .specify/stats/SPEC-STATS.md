# Spec Stats Dashboard: zuraffa

*Generated: 2026-08-28T18:31:54.622Z | Repo: zuraffa | TDD: installed*

## Portfolio Summary

| Stage | Count |
|-------|-------|
| specified | 25 |
| planned | 1 |
| implementing | 5 |
| complete | 8 |

**Overall**: 39 specs

## At a Glance

┌─────┬────────────────────────────────┬──────────────┬──────────────┐
│ #   │ feature                        │ stage        │ progress     │
├─────┼────────────────────────────────┼──────────────┼──────────────┤
│ 002 │ add-toggle-method              │ specified    │ —            │
│ 003 │ speckit-cli-commands           │ implementing │ 35% (22/62)  │
│ 004 │ fix-zuraffa-gen                │ complete     │ 100% (58/58) │
│ 005 │ speckit-extension-enhancements │ specified    │ —            │
│ 006 │ fix-polymorphic-mock-data      │ complete     │ 100% (25/25) │
│ 007 │ zuraffa-v5-foundation          │ complete     │ 100% (71/71) │
│ 008 │ mock-json-method               │ complete     │ 100% (28/28) │
│ 009 │ cache-adapter-command          │ implementing │ 92% (23/25)  │
│ 010 │ offline-first-sync             │ complete     │ 100% (59/59) │
│ 011 │ usecase-hook-system            │ implementing │ 97% (30/31)  │
│ 012 │ api-plugin                     │ implementing │ 81% (42/52)  │
│ 013 │ plugin-usecase-abstraction     │ implementing │ 97% (34/35)  │
│ 014 │ pure-dart-core-split           │ specified    │ —            │
│ 015 │ benchmark-plugin               │ planned      │ —            │
│ 016 │ fix-make-test-no-id            │ complete     │ 100% (19/19) │
│ 017 │ tui-plugin                     │ complete     │ 100% (52/52) │
│ 018 │ cli-plugin                     │ complete     │ 100% (38/38) │
│ 019 │ generic-session-plugin         │ specified    │ —            │
│ 020 │ skeleton-plugin-bones          │ specified    │ —            │
│ 021 │ gym-agent-rewrite-exercise     │ specified    │ —            │
│ 022 │ gym-real-exercises             │ specified    │ —            │
│ 023 │ agent-plugin-ui-render         │ specified    │ —            │
│ 024 │ shadcn-plugin-ui-vocabulary    │ specified    │ —            │
│ 025 │ v6-package-sdk                 │ specified    │ —            │
│ 026 │ agent-kernel-mission           │ specified    │ —            │
│ 027 │ agent-policy-shell             │ specified    │ —            │
│ 028 │ agent-runtime-plugin           │ specified    │ —            │
│ 029 │ agent-plugin-mcp-wrappers      │ specified    │ —            │
│ 030 │ feature-flag-system            │ specified    │ —            │
│ 031 │ scaffold-todo-example          │ specified    │ —            │
│ 032 │ migrate-pubdev-packages        │ specified    │ —            │
│ 033 │ route-decorator-nav            │ specified    │ —            │
│ 034 │ xray-control-deck              │ specified    │ —            │
│ 035 │ mcp-xray-bridge                │ specified    │ —            │
│ 036 │ xray-visual-overlay            │ specified    │ —            │
│ 037 │ graphql-core-schema-cache      │ specified    │ —            │
│ 038 │ controlled-widget-fragment     │ specified    │ —            │
│ 039 │ twin-turbo-xray-epic           │ specified    │ —            │
│ 040 │ v6-twin-turbo-moonshot         │ specified    │ —            │
└─────┴────────────────────────────────┴──────────────┴──────────────┘


## TDD Deep Stats

┌─────┬────────────────────────────────┬────┬────┬──────┬──────┬────────────┬──────────┐
│ #   │ feature                        │ A  │ U  │ char │ DONE │ loop       │ tasks.md │
├─────┼────────────────────────────────┼────┼────┼──────┼──────┼────────────┼──────────┤
│ 002 │ add-toggle-method              │ 6  │ 9  │ 0    │ 0    │ full       │ absent   │
│ 003 │ speckit-cli-commands           │ 0  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 004 │ fix-zuraffa-gen                │ 0  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 005 │ speckit-extension-enhancements │ 0  │ 0  │ 0    │ 0    │ outer-only │ absent   │
│ 006 │ fix-polymorphic-mock-data      │ 8  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 007 │ zuraffa-v5-foundation          │ 0  │ 0  │ 0    │ 0    │ outer-only │ absent   │
│ 008 │ mock-json-method               │ 0  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 009 │ cache-adapter-command          │ 0  │ 0  │ 0    │ 0    │ outer-only │ absent   │
│ 010 │ offline-first-sync             │ 0  │ 0  │ 0    │ 0    │ outer-only │ absent   │
│ 011 │ usecase-hook-system            │ 0  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 012 │ api-plugin                     │ 0  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 013 │ plugin-usecase-abstraction     │ 0  │ 0  │ 0    │ 0    │ outer-only │ updated  │
│ 014 │ pure-dart-core-split           │ 0  │ 0  │ 0    │ 0    │ outer-only │ absent   │
│ 015 │ benchmark-plugin               │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 016 │ fix-make-test-no-id            │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 017 │ tui-plugin                     │ 0  │ 0  │ 0    │ 0    │ outer-only │ absent   │
│ 018 │ cli-plugin                     │ 6  │ 48 │ 0    │ 0    │ full       │ absent   │
│ 019 │ generic-session-plugin         │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 020 │ skeleton-plugin-bones          │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 021 │ gym-agent-rewrite-exercise     │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 022 │ gym-real-exercises             │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 023 │ agent-plugin-ui-render         │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 024 │ shadcn-plugin-ui-vocabulary    │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 025 │ v6-package-sdk                 │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 026 │ agent-kernel-mission           │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 027 │ agent-policy-shell             │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 028 │ agent-runtime-plugin           │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 029 │ agent-plugin-mcp-wrappers      │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 030 │ feature-flag-system            │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 031 │ scaffold-todo-example          │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 032 │ migrate-pubdev-packages        │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 033 │ route-decorator-nav            │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 034 │ xray-control-deck              │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 035 │ mcp-xray-bridge                │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 036 │ xray-visual-overlay            │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 037 │ graphql-core-schema-cache      │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 038 │ controlled-widget-fragment     │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 039 │ twin-turbo-xray-epic           │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│ 040 │ v6-twin-turbo-moonshot         │ 0  │ 0  │ 0    │ 0    │ absent     │ -        │
│     │ total                          │ 20 │ 57 │ 0    │ 0    │            │          │
└─────┴────────────────────────────────┴────┴────┴──────┴──────┴────────────┴──────────┘


- `A` acceptance behaviors, `U` unit behaviors, `char` characterization behaviors, `DONE` behaviors in `DONE` state.
- `loop`: `full` (outer + inner derived), `outer-only` (acceptance only), `inside-out`, or `absent` (no TDD list).
- `tasks.md`: `updated` (TDD markers present) or `absent`.
