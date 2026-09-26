## Unreleased

- `include:` merges other agent_lints files (paths, globs, `package:` URIs) the
  way `analysis_options.yaml` does: in order, later wins, the main file last.
  Split rules by area under `agent_lints/*.yaml` (#1).
- Breaking: the code-scope key is `files:` (top level and per rule); `include:`
  now means included config files.
- `explain` shows the `source` file of an included rule; `validate` reports the
  number of merged files.

## 0.2.0

Breaking: the rule form is flat (config `version: 2`). One node key per rule
(`use`, `constructor`, `call`, `ref`, `import`, `deny_imports`, `class`,
`function`, `variable`, `literal`, `file`); attributes, `args:` and context (`parent`,
`inside`, `not_inside`, `contains`, `not_contains`, `except`) are sibling
lines; no `match:` wrapper. `banned` is `use`, `imports` is `deny_imports`,
`naming` is a name pattern (`{ not: .. }`, `{ not_style: snake_case }`) on
the declaration, `files` is `include`.

- `constructor` replaces `new`; `from` is the package attribute (`package` still accepted); `from: flutter` also covers `material_ui`, `cupertino_ui` and `dart:ui`.
- `hint` replaces `suggest` (rule field, CLI label, JSON and SARIF keys, IDE correction).
- `args:` shorthands: `present`, `absent`, a value, a list.
- `message` is optional; defaults to a sentence built from `use_instead`.
- `explain --kinds` is generated from the node specs.

## 0.1.2

- README: context around the example.

## 0.1.1

- README: absolute documentation links so they work on pub.dev.

## 0.1.0

Initial release. Under active development: the rule language may still change before 1.0.

- Rules in `agent_lints.yaml`: `match:` (node kinds `new`, `call`, `ref`,
  `import`, `class`, `function`, `variable`, `literal`, `file`; `args`
  constraints; `inside` / `not_inside` / `contains` / `not_contains`;
  `any` / `all` / `not`), plus `banned`, `imports` and `naming` sugar.
- Messages with `{{placeholders}}`, `values:` lists with `{{allowed}}` and
  `{{closest}}`, `examples: { bad, good }`.
- CLI: `check` (agent / human / json / sarif output, `--changed`, `--files`,
  `--rule`, `--show-suppressed`), `validate`, `explain`, `test`, `init`.
- Analyzer plugin for `dart analyze`, `flutter analyze` and IDEs; every rule
  id is a diagnostic code with the configured severity.
- `file` matcher with line and code-line bounds; `explain`, `test` and `init`
  commands; documentation under `docs/`.
- `// ignore: agent_lints/<rule> -- reason` suppression, `unused_ignore` and
  `ignore_without_reason` reports.
