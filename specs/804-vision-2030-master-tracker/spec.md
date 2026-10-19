# Feature Specification: VISION 2030 — zuraffa as the AI-native app factory (master tracker, issue #804)

**Feature Branch**: `spec/804-vision-2030-master-tracker`

**Created**: 2026-10-18

**Status**: Draft

**Input**: Issue [#804](https://github.com/arrrrny/zuraffa/issues/804) — "🧭 VISION 2030: zuraffa as the AI-native app factory — master tracker". Labels: enhancement, foundational, vision, spec.

## Mission

Issue #804 is the single tracking issue for the 10-year horizon after the current hardening sweep (#754–#801): zuraffa becomes the operating system that AI agents build software inside — a governed universe where specs are executable, generation is provable, the framework verifies the agent, every operation speaks machine, and humans set policy while agents do the work. This spec captures that vision and the board of sub-issues that decompose it, so the intent layer (not prose comments) is the durable record in the repo.

Everything here is **evolution, not replacement**: it assumes #754–#801 land first, then climbs.

## The 10-year overnight success

Today zuraffa generates scaffolds and verifies TDD loops. The dream: **zuraffa becomes the operating system that AI agents build software inside** — where an agent doesn't just write code into a folder, it *inhabits a governed universe*:

- **Specs are executable** — the spec is the source of truth, code is a cache.
- **Generation is provable** — every artifact carries a verifiable receipt; nothing is trusted, everything is checked.
- **The framework verifies the agent** — not the agent hoping it's right.
- **Every operation speaks machine** — JSON schemas, event streams, stable exit codes.
- **Humans set policy, agents do the work** — approvals are policy gates, not duct tape.

The loop: `intent → spec → red → generate → green → refactor → prove → ship → observe → evolve` — autonomous end-to-end, with human checkpoints as first-class policy objects.

## Pillars

- **A. Proof-carrying generation** — receipts, replay, differential testing
- **B. Agent runtime** — agent shell, ZAP protocol, checkpoint policy
- **C. Trust engine** — mutation at scale, provenance SBOM, spec drift radar
- **D. Data dreams** — CRDT sync, schema evolution, on-device AI search
- **E. UI automation** — design tokens, agent-renderable UI
- **F. Performance & ecosystem** — budgets as code, plugin registry, self-hosting
- **G. Meta-intelligence** — retro mining, community corpus, the One Command

## The board (sub-issues)

- [ ] #805 — 🧪 Generator differential testing: same spec, N generator versions, behavioral diff
- [ ] #806 — ⏪ `zfa replay`: deterministically re-execute any feature's TDD history
- [ ] #807 — 🧴 Proof-carrying generation: every artifact ships a verifiable receipt
- [ ] #808 — 🤖 `zfa agent shell`: a long-lived agent runtime with leases, budgets, and role missions
- [ ] #809 — 📜 Zuraffa Agent Protocol (ZAP): an open interop spec for agent↔framework integration
- [ ] #810 — 🚦 Human checkpoints as policy: approval gates + a sign-off ledger
- [ ] #811 — 🧪 Mutation testing at scale: coverage-guided selection + per-PR mutation diff gates
- [ ] #812 — 🏷 Repo-wide provenance SBOM: CI fails code without origin
- [ ] #813 — 📡 Spec drift radar: `zfa spec diff` two-way spec↔code divergence detection
- [ ] #814 — 🔄 CRDT sync engine + `zfa sync simulate` chaos fuzzing
- [ ] #815 — 🚚 Schema evolution guard: entity diffs → migrations + compatibility scores
- [ ] #816 — 🔎 On-device hybrid search: generated SQLite + vector index for local AI
- [ ] #817 — 🎨 Design tokens → code: `zfa theme import` with a11y contrast gates
- [ ] #818 — 👁 Agent-renderable UI v2: a verifiable screen-description vocabulary
- [ ] #819 — 💰 Budgets as code: perf/size/startup budgets enforced in CI
- [ ] #820 — 🧩 Plugin registry: `zfa plugin search/install` with signed capability manifests
- [ ] #821 — ♻ Self-hosting loop: every zuraffa plugin born through zuraffa's own TDD loop
- [ ] #823 — ⛏ `zfa retro`: mine closed bugs into auto-proposed regression tests
- [ ] #824 — 🌍 Community failure corpus: anonymized TDD loop data sharing
- [ ] #825 — ✨ The One Command: `zfa dream` — intent to app with human checkpoints

## Relationship to the current sweep

Issues #754–#801 make today's promises real: unified machine contract (#778), error layer (#788), transactional generation + undo (#787), doctor (#793), MCP v2 (#791). This board is the horizon *after* that: assume those land, then climb.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Vision is durable in the repo (Priority: P1)

A contributor (human or agent) joining the repo in a fresh context window reads `specs/804-vision-2030-master-tracker/spec.md` and learns the 2030 vision, the seven pillars, the board of sub-issues, and the relationship to the current hardening sweep — without re-reading issue #804 on GitHub.

**Why this priority**: the issue's literal ask is to track the dream in-repo; the spec is the intent layer.

**Independent Test**: open the spec file and confirm it contains the vision statement, the seven pillars (A–G), and links to all sub-issues #805–#825 (excluding #822, which is not part of this board).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repo MUST contain `specs/804-vision-2030-master-tracker/spec.md` capturing the VISION 2030 statement, the five "governed universe" bullets, the intent loop, the seven pillars, the full sub-issue board, and the relationship to #754–#801.
- **FR-002**: The spec MUST link each sub-issue by number so the board stays navigable.
- **FR-003**: The spec MUST state that everything here is evolution, not replacement, and assumes #754–#801 land first.

## Success Criteria

- **SC-001**: A reader can reconstruct the 2030 vision and its decomposition from the spec alone.
- **SC-002**: No code, generated artifact, or test is changed by this spec — it is an intent-layer document only.
EOF
echo done