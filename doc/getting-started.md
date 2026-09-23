---
title: Getting started
description: Install agent_lints, write a first rule, see it in the CLI and in your IDE.
---

# Getting started

## 1. Install

agent_lints needs Dart 3.11 or newer (the analyzer plugin needs Dart 3.10, so any
supported Flutter stable works).

### As a dev dependency (CLI via `dart run`)

```yaml
# pubspec.yaml
dev_dependencies:
  agent_lints: ^0.1.0
```

```
dart pub get   # or flutter pub get
```

> **If `pub get` fails with an `analyzer` version conflict**, a code generator
> in your project (`freezed`, `json_serializable`, `build_runner`, ...) pins an
> older `analyzer` than agent_lints uses. You do not need the dev dependency:
> the IDE plugin resolves on its own (step 4), and the CLI can be installed
> globally. See [Troubleshooting](troubleshooting.md#analyzer-version-conflict).

### Globally (CLI without touching pubspec)

```
dart pub global activate agent_lints
agent_lints            # instead of `dart run agent_lints`
```

## 2. Create the config

```
dart run agent_lints init
```

This writes `agent_lints.yaml` next to `pubspec.yaml` with one enabled rule
(`no_print`) and commented starters you can uncomment. Options:

| Flag | Effect |
|---|---|
| `--plugin` | Adds the `plugins:` entry to the root `analysis_options.yaml` (step 4). `--plugin-path ../agent_lints` uses a local checkout. |
| `--agents-md` | Appends a short section to `AGENTS.md` and/or `CLAUDE.md` telling agents to run the linter and how to add rules. Idempotent. |
| `--claude-skill` | Writes `.claude/skills/agent-lints/SKILL.md` for Claude Code. |
| `--force` | Overwrite an existing `agent_lints.yaml`. |
| `--dir <path>` | Project directory (defaults to the current one). |

Or write the file by hand:

```yaml
# agent_lints.yaml
version: 1
include: [lib/**]
fail_on: warning

rules:
  no_print:
    severity: error
    description: Use the project logger instead of print
    match: { call: { name: print, package: dart:core } }
    use_instead: AppLog.d(...)
    suggest: "AppLog.d({{args.0}})"
    message: "`print` ships to release logs. Use {{use_instead}}."
    examples:
      bad: ["void f() { print('x'); }"]
      good: ["void f() {}"]
```

## 3. Run it

```
dart run agent_lints validate   # is the YAML valid? exit 0 or 2
dart run agent_lints test       # do the rule's examples behave? exit 0 or 1
dart run agent_lints            # check the project
```

Output when piped (what an agent sees):

```
[error] no_print  lib/features/home/home_screen.dart:19:5
  found    print('home loaded')
  why      `print` ships to release logs. Use AppLog.d(...).
  suggest  AppLog.d('home loaded')
  ignore   // ignore: agent_lints/no_print -- <reason>

agent_lints: 1 error, 0 warnings, 0 info in 1 file  (14 files checked, 2.1s)
exit 1  (fail_on: warning). Run `dart run agent_lints explain <rule>` for the full contract.
```

On a terminal the default is a one-line-per-issue format. Force either with
`--format agent` or `--format human`. See [CLI](cli.md).

## 4. See it in the IDE

Add the plugin to the **root** `analysis_options.yaml` (nested files cannot
enable plugins):

```yaml
plugins:
  agent_lints: ^0.1.0
```

To run the latest unreleased version instead, use a git source:

```yaml
plugins:
  agent_lints:
    git:
      url: https://github.com/pedromassango/agent_lints
      ref: main          # or a commit / tag
```

Restart the analysis server (VS Code: "Dart: Restart Analysis Server";
Android Studio / IntelliJ: the restart icon in the Dart Analysis window). The
first start builds the plugin and takes a few seconds. From then on
`dart analyze`, `flutter analyze` and the editor show every rule with its
configured severity. Details and caveats in [IDE plugin](ide-plugin.md).

## 5. Tell your agents

```
dart run agent_lints init --agents-md --claude-skill
```

adds the [agent workflow](agent-workflow.md) to your agent instructions:
run the linter after editing, fix from the `why` / `suggest` lines, add rules
in YAML, prove them with `test`.
