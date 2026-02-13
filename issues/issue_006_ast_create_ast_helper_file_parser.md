---
title: "[AST] Create AST Helper & File Parser"
phase: "AST Integration"
priority: "High"
estimated_hours: 12
labels: core, ast, integration
dependencies: None
---

## 📋 Task Overview

**Phase:** AST Integration
**Priority:** High
**Estimated Hours:** 12
**Dependencies:** None

## 📝 Description

Build utilities for parsing and manipulating Dart AST. AST (Abstract Syntax Tree) is a tree representation of code structure that allows safe code modification.

## ✅ Acceptance Criteria

- [ ] AstHelper can parse Dart files into AST
- [ ] Can find classes, methods, fields in AST
- [ ] Can add methods to existing classes
- [ ] Can extract all exports from a file
- [ ] Handles malformed files gracefully

## 📁 Files

### To Create
- `lib/src/core/ast/ast_helper.dart`
- `lib/src/core/ast/file_parser.dart`
- `lib/src/core/ast/ast_modifier.dart`
- `lib/src/core/ast/node_finder.dart`
- `test/core/ast/ast_helper_test.dart`

### To Modify


## 🧪 Testing Requirements

Test parsing, finding nodes, and modification.

## 💬 Notes

Critical for smart append mode.
