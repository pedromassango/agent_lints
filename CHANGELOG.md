## 0.1.0-dev

Initial development.

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
- `// ignore: agent_lints/<rule> -- reason` suppression, `unused_ignore` and
  `ignore_without_reason` reports.
