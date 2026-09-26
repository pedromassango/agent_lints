---
title: Configuration
description: Every key of agent_lints.yaml, with defaults and semantics.
---

# Configuration: `agent_lints.yaml`

The file lives next to `pubspec.yaml`. All globs and paths are relative to
that directory and use `/` separators. The CLI finds it by walking up from the
current directory (or takes `--config <path>`); the IDE plugin finds the nearest
one above each analyzed file.

```yaml
version: 2
files: [lib/**]
exclude: [lib/generated/**]
fail_on: warning
require_ignore_reason: false
docs: doc/conventions.md

values:
  spacing: [4, 8, 12, 16, 24, 32]
  radius:
    - { value: 4, name: AppRadius.sm }
    - { value: 8, name: AppRadius.md }

rules:
  <rule_id>: { ... }
```

## Top-level keys

| Key | Type | Default | Meaning |
|---|---|---|---|
| `version` | int | required | Schema version. Only `2`. |
| `include` | path or list | `[]` | Other agent_lints files to merge in, like `include:` in `analysis_options.yaml`. Relative paths, globs, or `package:` URIs. See [Splitting rules across files](#splitting-rules-across-files). |
| `files` | glob or list | `[lib/**]` | Code to check. `bin/**` and `test/**` are opt-in. |
| `exclude` | glob or list | `[]` | Removed after `files`. The [always-excluded](#always-excluded) globs are added. |
| `fail_on` | `error` \| `warning` \| `info` | `warning` | The CLI exits 1 when any violation has this severity or higher. Nothing else changes. `--fail-on none` disables it for one run. |
| `require_ignore_reason` | bool | `false` | When true, an `// ignore:` comment without `-- reason` is itself reported as `ignore_without_reason` (warning). |
| `docs` | path or URL | none | Default value of `{{docs}}` for rules that do not set their own. |
| `values` | map | `{}` | Named lists referenced as `$name` in `in:` / `not_in:` constraints. See [values](#values). |
| `rules` | map | required | Rule id to rule body. |

Unknown keys are errors with a did-you-mean hint.

### Always excluded

Generated and build output never get checked, whatever `files` says:

```
**/*.g.dart  **/*.freezed.dart  **/*.gr.dart  **/*.pb.dart  **/*.pbenum.dart
**/*.pbjson.dart  **/*.pbserver.dart  **/*.mocks.dart  build/**  .dart_tool/**
agent_lints_examples_tmp/**
```

## Values

A values list gives numbers or strings a name so rules can say "must be one of
these" and messages can print the list and the nearest entry.

```yaml
values:
  spacing:
    - 4                                  # bare number or string
    - { value: 8, name: AppSpacing.sm }  # with a symbolic name
    - { value: 16, name: AppSpacing.md }
```

Used in a rule:

```yaml
    constructor: EdgeInsets.all
    args: { value: { literal: num, not_in: $spacing } }
    message: "{{value}} is off scale. Allowed: {{allowed}}. Closest: {{closest}}."
    hint: "EdgeInsets.all({{closest.name}})"
```

- `$spacing` in `in:` / `not_in:` compares the argument's **constant value**, so
  `AppSpacing.sm` (a `static const` equal to 8) counts as 8. Non-constant
  arguments never match `in` / `not_in`.
- `{{allowed}}` renders `4, 8 (AppSpacing.sm), 16 (AppSpacing.md)`.
- `{{closest}}` renders the two nearest numeric entries; `{{closest.name}}` and
  `{{closest.value}}` the nearest one.
- `{{values.spacing}}` renders any list anywhere.

## Rule body

```yaml
rules:
  rule_id:                       # ^[a-z][a-z0-9_]*$ ; this becomes the diagnostic code
    use: print                   # exactly ONE node key (see rule-language.md)
    from: dart:core           # the node's attributes, as sibling lines
    args: { ... }                # argument constraints (new, call)
    parent: { constructor: Column }      # context: parent | inside | not_inside | contains | not_contains | except

    severity: warning            # error | warning | info | off
    description: "one line"      # shown by explain and in SARIF
    files: [lib/features/**]   # narrows the top-level include for this rule
    exclude: [lib/legacy/**]     # per-rule exclusions
    message: "..."               # optional; {{placeholders}} allowed
    use_instead: "..."           # what to write instead; feeds {{use_instead}} and the IDE correction
    hint: "..."               # a replacement snippet; placeholders allowed
    docs: docs/ui.md#buttons     # path or URL; feeds {{docs}}
    vars: { logger: AppLog }     # custom placeholders: {{vars.logger}}
    examples:                    # checked by `dart run agent_lints test`
      bad: ["..."]               # each must trigger this rule
      good: ["..."]              # each must not
```

| Field | Notes |
|---|---|
| `severity` | `off` disables the rule entirely. Default `warning`. |
| `files` / `exclude` | Globs relative to the project. `files` is intersected with the top-level `files`. |
| `message` | Defaults to `` `{{found}}` is not allowed here. `` plus `Use {{use_instead}}.` when `use_instead` is set. Multi-line strings are fine; the IDE shows them on one line, the CLI keeps line breaks. Unknown placeholders are config errors. |
| `examples` | Complete Dart snippets (with imports). They are written into a scratch folder inside the project so they resolve against its real dependencies. File scoping is ignored for them. |

## Splitting rules across files

`include:` works like `include:` in `analysis_options.yaml`: every included
file is a complete agent_lints config, and files are merged in list order with
later files overriding earlier ones and the including file overriding all of
them. Name a folder once with a glob:

```yaml
# agent_lints.yaml
version: 2
include: [agent_lints/*.yaml]
files: [lib/**]
rules:                               # rules can still live here too
  no_print: { use: print, from: dart:core }
```

```yaml
# agent_lints/ui.yaml
values:
  spacing: [4, 8, 16]
rules:
  no_raw_colors: { constructor: { name: Color, from: dart:ui } }
  spacing_on_scale:
    constructor: [EdgeInsets.all, EdgeInsets.symmetric]
    args: { "*": { literal: num, not_in: $spacing } }
```

- Entries are relative to the file that lists them: a path, a glob (matches
  sorted by path), or `package:name/path.yaml` resolved through
  `.dart_tool/package_config.json`. Included files may `include:` further
  files; cycles are errors.
- Merge, per section: `rules` by id (a later definition replaces the earlier
  one; `severity: off` in the main file switches an included rule off);
  `values` by name; `files`, `fail_on`, `docs`, `require_ignore_reason` take
  the last value set; `exclude` accumulates.
- `version` is required only in the main file. Errors report the file and
  line they come from. A glob that matches nothing is a warning.
- `dart run agent_lints explain <rule>` shows a `source` line for rules that
  come from an included file; `validate` reports how many files were merged.

## Rule ids

Rule ids are diagnostic codes. They appear in every output format, in
`// ignore: agent_lints/<id>` comments, and in `analysis_options.yaml` when you
override a severity for the plugin. Keep them lowercase snake_case.

## Validation

`dart run agent_lints validate` (and every `check`) loads the file and reports
**all** problems at once, each with `file:line:col`, the YAML path, and a hint:

```
[config] agent_lints.yaml:14:5 rules.no_print.packge: unknown key "packge" (did you mean "package"?)
[config] agent_lints.yaml:16:14 rules.no_print.message: unknown placeholder {{fil}} (did you mean {{file}}?)
```

Exit code 2, and nothing is checked until the file is fixed.
