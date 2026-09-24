---
title: CLI
description: Commands, flags, output formats and exit codes of dart run agent_lints.
---

# CLI

```
dart run agent_lints [check] [flags]
dart run agent_lints validate
dart run agent_lints explain <rule> | --all | --kinds
dart run agent_lints test
dart run agent_lints init
```

`check` is the default: `dart run agent_lints --format json` works. Installed
globally, replace `dart run agent_lints` with `agent_lints`.

## `check`

Resolves every selected Dart file and runs the rules.

| Flag | Meaning |
|---|---|
| `--format agent\|human\|json\|sarif` | Output format. Default: `human` on a terminal, `agent` when piped or captured. |
| `--config <path>` | Use this `agent_lints.yaml`; its directory becomes the project root. |
| `--files a.dart,b.dart` | Only these files (project-relative or absolute). Repeatable. |
| `--changed` | Only `.dart` files modified, staged or untracked since the last git commit. Needs a git repository. |
| `--rule id` | Only these rule ids. Repeatable. |
| `--fail-on error\|warning\|info\|none` | Overrides the config's `fail_on` for this run. |
| `--show-suppressed` | Also list violations silenced by `// ignore` comments. |

### `agent` format

One block per violation, fixed keys in a fixed order, keys without a value are
omitted, no colour. Multi-line messages keep their line breaks under `why`.

```
[error] no_print  lib/features/home/home_screen.dart:19:5
  found    print('home loaded')
  why      `print` ships to release logs. Use AppLog.d(...).
  suggest  AppLog.d('home loaded')
  docs     doc/logging.md
  ignore   // ignore: agent_lints/no_print -- <reason>

[warning] spacing_on_scale  lib/features/cart/cart_tile.dart:12:18
  found    const EdgeInsets.symmetric(horizontal: 10)
  why      10 passed to EdgeInsets.symmetric(horizontal) is off the spacing scale. Allowed: 4, 8 (AppSpacing.sm), 16 (AppSpacing.md). Closest: 8 (AppSpacing.sm), 4.
  suggest  EdgeInsets.symmetric(horizontal: AppSpacing.sm)
  ignore   // ignore: agent_lints/spacing_on_scale -- <reason>

agent_lints: 1 error, 1 warning, 0 info in 2 files  (148 files checked, 1.9s, 2 suppressed)
exit 1  (fail_on: warning). Run `dart run agent_lints explain <rule>` for the full contract.
```

Config problems come first as `[config] ...` lines and nothing is checked.

### `human` format

One line per violation, first sentence of the message, like `dart analyze`:

```
lib/features/home/home_screen.dart:19:5 • error • `print` ships to release logs. • no_print
1 issue found. Run `dart run agent_lints --format agent` for suggestions.
```

### `json` format

```json
{
  "version": 1,
  "tool": { "name": "agent_lints", "version": "0.1.0" },
  "summary": { "errors": 1, "warnings": 0, "infos": 0, "files_checked": 148,
               "files_with_issues": 1, "duration_ms": 1900, "exit_code": 1, "suppressed": 0 },
  "config_errors": [],
  "violations": [
    {
      "rule": "no_print", "severity": "error", "description": "...",
      "file": "lib/features/home/home_screen.dart",
      "range": { "start": { "line": 19, "column": 5, "offset": 412 },
                 "end":   { "line": 19, "column": 25, "offset": 432 } },
      "found": "print('home loaded')",
      "message": "...", "short": "...",
      "use_instead": "AppLog.d(...)", "suggest": "AppLog.d('home loaded')",
      "docs": "doc/logging.md",
      "ignore": "// ignore: agent_lints/no_print -- <reason>",
      "context": { "name": "print", "package": "dart:core",
                   "enclosing_class": "_HomeScreenState", "enclosing_function": "initState" }
    }
  ],
  "suppressed": []
}
```

`suppressed` is present only with `--show-suppressed`.

### `sarif` format

SARIF 2.1.0 for GitHub code scanning and other importers. Rules from the config
become `tool.driver.rules` (with `description`, `docs` as `helpUri`, default
level); each violation becomes a result with `ruleId`, `level`, a physical
location relative to the project (`uriBaseId: %SRCROOT%`), the rendered
message plus `Suggest: ...`, and `properties.suggest` / `properties.ignore`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | no violation at or above `fail_on` |
| 1 | violations at or above `fail_on` |
| 2 | `agent_lints.yaml` is invalid; nothing was checked |
| 3 | the project could not be analyzed |
| 4 | internal error |
| 64 | usage error |

## `validate`

Loads the config, prints every error with position and hint, exits 0 or 2. The
fast loop while editing rules; no code is analyzed.

```
agent_lints.yaml is valid: 10 rules (10 enabled), 1 values list.
```

## `explain`

```
dart run agent_lints explain no_print        # one or more rule ids
dart run agent_lints explain --all
dart run agent_lints explain --kinds         # the rule language, generated from the code
```

```
no_print  (error)  Use the app logger instead of print
  kind        call
  scope       lib/**  except lib/core/log.dart
  matches     call name=print package=dart:core
  message     `print` ships to release logs. Use {{use_instead}}.
  use_instead AppLog.d(...) from package:app/core/log.dart
  suggest     AppLog.d({{args.0}})
  ignore      // ignore: agent_lints/no_print -- <reason>
  examples    bad   void f() { print('x'); }
              good  void f() {}
```

`matches` is the compiled matcher.

## `test`

Runs every rule's `examples`. Each `bad` snippet must trigger the rule; each
`good` snippet must not. Snippets are written as real files into
`agent_lints_examples_tmp/` inside the project (deleted afterwards), so they
resolve against the project's dependencies. File scoping is ignored for them.

```
PASS  no_print  (1 bad, 1 good)
FAIL  taps  (1 bad, 1 good)
      good[0] triggered taps at line 2: final w = GestureDetector(onTap: () {});

1 of 2 rules pass their examples.
```

Exit 0 when all pass, 1 otherwise. `--rule id` limits which rules run.

## `init`

See [Getting started](getting-started.md#2-create-the-config).
