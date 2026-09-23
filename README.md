# agent_lint

Agent-first custom lint for Dart and Flutter.

Project rules live in a single `agent_lint.yaml`. Humans and coding agents add a
rule by editing YAML, and the same tool checks the code from the CLI (with output
written for agents to self-correct) and inside `dart analyze` / your IDE through
the official analyzer plugin API.

```yaml
# agent_lint.yaml
version: 1
rules:
  no_print:
    severity: error
    match: { call: { name: print, package: dart:core } }
    use_instead: AppLogger.d(...)
    message: "`print` ships to release logs. Use {{use_instead}}."
```

```
dart run agent_lint
```

Status: under active development, not yet published.
