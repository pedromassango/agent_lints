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
