---
title: How it works
description: Architecture of agent_lints and where to extend it.
---

# How it works

```
agent_lints.yaml ──► ConfigLoader ──► CompiledRule[] (id, severity, Matcher, MessageTemplate, scope)
                                              │
Dart file ──► analyzer (resolved AST) ──► Engine: one visitor pass per file
                                              │   dispatcher: node kind → rules
                                              │   Matcher.match(node) → captures
                                              ▼
                                        Violation[] ──► suppression (// ignore) ──► formatter / plugin
```

## Config

`ConfigLoader` reads the YAML with `package:yaml`, keeping source spans so
every error carries `file:line:col` and a dotted path. Errors are collected,
not thrown at the first one. A rule is a flat map: the loader takes the rule
fields and hands the rest to the matcher compiler. Message templates are
validated against the placeholder catalogue at load time.

## Matchers

`MatcherCompiler` turns a rule map into a tree of `Matcher` objects. Each
node key has a `NodeSpec` (its attributes, what a bare value means, how to
build it); sibling attributes are merged into the node's body; context keys
wrap the node matcher in a `ContextMatcher`; `any` / `all` / `not` are
combinators; `except` is `all` plus `not`. A matcher declares the
`NodeKind`s it can succeed on and returns a `MatchResult` (node, captures,
optional token to anchor the diagnostic) or null.

Adding a node kind is one matcher class with a `static const keys` list and
one `NodeSpec` in the compiler. The self-check config in the repo enforces the
`keys` constant so `explain --kinds` and the validator stay complete.

## Resolution helpers

`ResolvedName.of(element)` produces the candidate spellings a `name:` pattern
is matched against and the defining library URI. `TypePattern` walks
`allSupertypes`. `constantValueOf` evaluates literals and `const` references
through the analyzer's constant evaluator. No `package:analyzer/src` imports
are used, so analyzer upgrades stay mechanical.

## Engine

`Engine` groups enabled rules by node kind and runs a single
`RecursiveAstVisitor` per file (`KindVisitor`, also reused by `contains:`).
Every hit is rendered immediately: placeholders come from the rule's static
fields, the file position, the enclosing declarations and the matcher's
captures. Then `Suppressions` parses `// ignore` comments from the token
stream and filters, reporting unused and reason-less ignores as synthetic
violations.

The engine takes a `CompilationUnit`, its content and path. The CLI feeds it
`ResolvedUnitResult`s from an `AnalysisContextCollection`; the plugin feeds it
the units the analysis server already resolved.

## Front ends

- **CLI** (`bin/agent_lints.dart`): `check`, `validate`, `explain`, `test`,
  `init`. Formatters render a `RunResult` as agent blocks, one-liners, JSON or
  SARIF.
- **Plugin** (`lib/main.dart`): one `MultiAnalysisRule` named `agent_lints`.
  It finds the nearest `agent_lints.yaml` for each file (cached by
  modification time), creates a `LintCode` per rule id with the configured
  severity, and reports with the rendered message as the problem text and a
  correction built from `use_instead`, `suggest`, `docs` and the explain
  command. Configs are discovered eagerly at start so codes exist before the
  first file is analyzed.

## Testing

Unit tests build a throwaway project on disk with stub `flutter`,
`material_ui` and `http` packages so matchers resolve real elements without a
Flutter SDK. End-to-end tests (tag `e2e`) run the CLI and `dart analyze` (with
the plugin enabled through a path reference) against the Flutter app in
`example/` and compare with `example/expected_violations.json`.
