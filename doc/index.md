---
title: agent_lints
description: Agent-first custom lint for Dart and Flutter. Project rules in YAML, checked from the CLI, dart analyze and your IDE.
---

# agent_lints

**Project rules in one YAML file. Written by humans or coding agents. Enforced everywhere.**

Teams write conventions in `AGENTS.md` or `CLAUDE.md` ("never use `print`",
"features must not import `package:http`", "widget files stay small") and then
watch agents and humans ignore them. Enforcing one of those rules used to mean
writing a Dart AST visitor with `custom_lint` or the analyzer plugin API.

With agent_lints a rule is a few lines of YAML in `agent_lints.yaml`:

```yaml
version: 2
rules:
  no_print:
    severity: error
    use: print
    from: dart:core
    use_instead: AppLog.d(...)
    hint: "AppLog.d({{args.0}})"
    message: "`print` ships to release logs. Use {{use_instead}}."
```

The same rule is checked in three places:

| Where | How | What you see |
|---|---|---|
| Command line | `dart run agent_lints` | Blocks written for agents to self-correct: what was found, why, what to write instead, how to suppress. Also JSON, SARIF and a one-line human format. |
| `dart analyze` / `flutter analyze` | Analyzer plugin | Each rule id is a diagnostic code with the severity from the YAML. |
| IDE (VS Code, Android Studio, IntelliJ) | Same plugin | Squiggles and tooltips with the message and a `dart run agent_lints explain <rule>` hint. |

Rules match the **resolved** AST, not source text. `import 'package:flutter/material.dart' as m; m.Text(...)`
and `Text(...)` are the same thing to a rule, and `package:material_ui`
is handled like `package:flutter`.

## Where to go next

- [Getting started](getting-started.md): install, first rule, IDE setup, in five minutes.
- [Configuration](configuration.md): every key of `agent_lints.yaml`, including `include:` to split rules across files.
- [Rule language](rule-language.md): node keys, attributes, arguments, context, patterns.
- [Placeholders](placeholders.md): everything a message can interpolate.
- [CLI](cli.md): commands, flags, output formats, exit codes.
- [IDE plugin](ide-plugin.md): `dart analyze` and editor integration.
- [Suppressing violations](suppressing.md): `// ignore:` comments.
- [Agent workflow](agent-workflow.md): how a coding agent writes, tests and obeys rules.
- [Recipes](recipes.md): ready-made rules for Flutter projects.
- [Troubleshooting](troubleshooting.md): analyzer version conflicts, plugin not loading, stale builds.
- [How it works](how-it-works.md): architecture and extension points.
- [Releasing](releasing.md): how a version reaches pub.dev.

## Status

Under active development. Package: <https://pub.dev/packages/agent_lints>. Source: <https://github.com/pedromassango/agent_lints>. MIT license.
