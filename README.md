# agent_lints

Agent-first custom lint for Dart and Flutter.

Your project rules live in one `agent_lints.yaml`. Humans and coding agents add
a rule by editing YAML, and the same tool checks the code from the CLI (with
output written for agents to self-correct in one pass) and inside
`dart analyze`, `flutter analyze` and your IDE through the official analyzer
plugin API.

```yaml
# agent_lints.yaml
version: 1
rules:
  no_print:
    severity: error
    match: { call: { name: print, package: dart:core } }
    use_instead: AppLog.d(...)
    suggest: "AppLog.d({{args.0}})"
    message: "`print` ships to release logs. Use {{use_instead}}."
```

```
$ dart run agent_lints
[error] no_print  lib/features/home/home_screen.dart:19:5
  found    print('home loaded')
  why      `print` ships to release logs. Use AppLog.d(...).
  suggest  AppLog.d('home loaded')
  ignore   // ignore: agent_lints/no_print -- <reason>

agent_lints: 1 error, 0 warnings, 0 info in 1 file  (14 files checked, 2.1s)
exit 1  (fail_on: warning). Run `dart run agent_lints explain <rule>` for the full contract.
```

## Documentation

The full documentation lives in [`docs/`](docs/index.md): [getting started](docs/getting-started.md), [configuration](docs/configuration.md), the [rule language](docs/rule-language.md), [sugar kinds](docs/sugar-kinds.md), [placeholders](docs/placeholders.md), the [CLI](docs/cli.md), the [IDE plugin](docs/ide-plugin.md), [suppressing violations](docs/suppressing.md), the [agent workflow](docs/agent-workflow.md), [recipes](docs/recipes.md), [troubleshooting](docs/troubleshooting.md) and [how it works](docs/how-it-works.md).

## Why

Teams write conventions in `AGENTS.md` or `CLAUDE.md` ("never use `print`",
"features must not import `package:http`") and agents ignore them. Enforcing a
rule with `custom_lint` or the analyzer plugin API means writing a Dart AST
visitor per rule. With `agent_lints` a rule is a few lines of YAML, matched
against the *resolved* AST, so `import 'package:flutter/material.dart' as m;
m.Text(...)` and `Text(...)` are the same thing and `package:material_ui` is
handled like `package:flutter`.

## Install

```yaml
# pubspec.yaml
dev_dependencies:
  agent_lints: ^0.1.0
```

Create `agent_lints.yaml` next to `pubspec.yaml`, then:

```
dart run agent_lints init               # starter agent_lints.yaml (+ --plugin --agents-md --claude-skill)
dart run agent_lints                    # check (default). Exit 1 when rules fail.
dart run agent_lints validate           # validate the YAML only, exit 0/2
dart run agent_lints explain <rule>     # the compiled contract of a rule; --kinds for the rule language
dart run agent_lints test               # run each rule's bad/good examples
dart run agent_lints --format json      # also: agent | human | sarif
dart run agent_lints --changed          # only files changed since the last commit
dart run agent_lints --files lib/a.dart --rule no_print
dart run agent_lints --show-suppressed  # audit // ignore comments
```

Output defaults to `human` on a terminal and `agent` when piped, so agents
calling it from a shell get the rich form.

### IDE and `dart analyze`

Enable the analyzer plugin in the **root** `analysis_options.yaml` (Dart 3.10+):

```yaml
plugins:
  agent_lints: ^0.1.0
```

Every rule id becomes a diagnostic code with the severity from the YAML, so
`// ignore: agent_lints/<rule>` works and `analysis_options.yaml` can override
a rule with `plugins: agent_lints: diagnostics: <rule>: error`. Restart the
analysis server after changing the `plugins:` section. The first analysis
compiles the plugin, which takes a few seconds.

The plugin finds `agent_lints.yaml` by walking up from the analysis server's
working directory (the project or workspace folder) and up to four levels
down, so monorepos with one config per package work. Edits to the YAML are
picked up when a file is next analyzed.

## The config file

```yaml
version: 1
include: [lib/**]              # default
exclude: [lib/generated/**]    # generated files (*.g.dart, *.freezed.dart, ...) are always excluded
fail_on: warning               # exit 1 at or above this severity
docs: docs/conventions.md      # default {{docs}}

values:                        # named lists, referenced as $name in rules
  spacing: [4, 8, 16, 24]
  radius: [{ value: 4, name: AppRadius.sm }, { value: 8, name: AppRadius.md }]

rules:
  <rule_id>:                   # snake_case; this is the diagnostic code
    match: { ... }             # exactly one of: match | banned | imports | naming
    severity: warning          # error | warning | info | off
    description: "one line"
    files: [lib/features/**]   # narrow this rule
    exclude: [lib/legacy/**]
    message: "..."             # required; supports {{placeholders}}
    use_instead: "..."
    suggest: "..."             # replacement snippet, placeholders allowed
    docs: docs/ui.md#buttons
    vars: { logger: AppLog }   # {{vars.logger}}
    examples:                  # checked by `dart run agent_lints test`
      bad: ["void f() { print(1); }"]
      good: ["void f() {}"]
```

## `match:` — the rule language

A matcher is a map with **one node key** plus optional context keys, or a
combinator (`any: [..]`, `all: [..]`, `not: {..}`). Every string accepts exact
text, a glob (`*Screen`, `package:flutter/**`), a regex (`/^_.*Impl$/`), a list
(any of), or `{ not: pattern }`.

| Node key | Matches | Body keys |
|---|---|---|
| `import` | import / export directives | `uri`, `package` (resolved), `relative`, `prefix`, `show`, `kind: import\|export\|any`, `deferred` |
| `call` | method and function calls | `name`, `package`, `library`, `on: {type, name}`, `returns`, `await`, `static`, `args` |
| `new` | constructor calls | `name`, `package`, `library`, `const`, `type`, `args` |
| `ref` | a reference that is not a call (`Colors.red`, a tear-off) | `name`, `package`, `library`, `type` |
| `function` | function / method / constructor declarations | `name`, `kind`, `returns`, `async`, `static`, `const`, `override`, `annotation` |
| `class` | class / mixin / enum / extension declarations | `name`, `kind`, `extends`, `implements`, `mixes_in`, `abstract`, `annotation`, `has`, `lacks` |
| `variable` | top-level variables, fields, locals | `name`, `scope: top_level\|field\|local`, `type`, `const`, `final`, `late`, `static`, `annotation`, `initializer` |
| `literal` | int / double / string / bool / null / list / map literals | `kind`, `value`, `in`, `not_in`, `min`, `max`, `source`, `interpolated` |
| `file` | the file itself (reported at line 1) | `name` (base name without `.dart`), `path`, `max_lines`, `min_lines`, `max_code_lines`, `min_code_lines` (violation when outside the bound; code lines exclude blank and comment-only lines) |

**Names resolve against elements**, never source text:

- `print` matches the function; `package: dart:core` pins it.
- `State.setState` matches the method on its *declaring* class. A bare
  `setState` matches that method on any receiver. `.withOpacity` also works.
- `EdgeInsets.all` is a named constructor; `EdgeInsets` matches every
  constructor of the class; `EdgeInsets.*` is a glob over both.
- `package: flutter` tests the package that *defines* the element. Use
  `package: [flutter, material_ui]` while migrating. `package: project` is the
  analyzed package.
- `type:` checks the static type and its supertypes (`type: Widget`). Use
  `type: { exact: Color }` to disable the subtype walk.

**Arguments** (`args:` on `call` / `new`) are keyed by parameter name, even
for positional arguments, or by index, `'*'` (some argument) or `'**'` (every
argument):

```yaml
args:
  onTap: { present: true }
  onPanUpdate: { present: false }
  value: { literal: num, not_in: $spacing }   # constant-evaluated; AppSpacing.sm counts as 8
  data:  { source: "/^'http/" }               # regex over the source text
  color: { ref: { name: "Colors.*" } }         # the argument is that reference
  decoration: { expr: { new: { name: BoxDecoration, args: { color: { present: true } } } } }
```

Constraints: `present`, `literal` (`int` `double` `num` `string` `bool` `null`
`list` `map` `any`), `value`, `in`, `not_in`, `min`, `max`, `type`, `source`,
`ref`, `expr`. `in` / `not_in` only match constant expressions, so variables are
never flagged.

**Context** keys sit next to the node key:

```yaml
match:
  new: { name: ListView, args: { shrinkWrap: { present: false } } }
  inside: { new: { name: Column }, direct: true }   # direct = an argument of that widget
  not_inside: { function: { name: build } }
  contains: { call: { name: setState } }
  not_contains: { new: { name: SafeArea } }
```

`inside` walks up the syntax tree, so a widget returned from a helper method is
not an ancestor.

## Sugar kinds

Three shorthands cover the rules teams write most. `explain` (coming) prints
what they expand to.

```yaml
  no_opacity:
    banned: [Opacity, .withOpacity]          # string, list or {name, package}
    message: "{{name}} is banned."           # = any: [new, call, ref]

  features_no_material:                      # layering: engine-native
    imports:
      from: [lib/features/**]                # files this applies to
      deny:                                  # package/dart uri globs, `relative`,
        - package:flutter/material.dart      # or project path globs (resolved
        - lib/data/**                        # through relative imports too)
        - relative
      except: [lib/features/**/theme/**]
      replace_with: package:app/ui/ui.dart   # feeds {{use_instead}}
    message: "{{uri}} is not allowed here ({{denied}}). Import {{use_instead}}."

  screens_named_screen:                      # naming: pattern or style
    naming:
      target: class                          # class | function | variable | file
      where: { extends: StatelessWidget }    # body of that node kind
      pattern: "*Screen"                     # or style: snake_case | camelCase | PascalCase | SCREAMING_SNAKE_CASE
    files: [lib/screens/**]
    message: "{{name}} must end with Screen."
```

## Suppressing a violation

The comment syntax is the analyzer's, so the same comment will work for the
IDE plugin:

```dart
// ignore: agent_lints/no_print -- one-off migration script
print(report);
print(report); // ignore: no_print

// ignore_for_file: agent_lints/no_print
```

The `agent_lints/` prefix is optional on the CLI. A comment on its own line
covers the next line; a trailing comment covers its own line. Ignores that
suppress nothing are reported as `unused_ignore` (info). With
`require_ignore_reason: true`, an ignore without `-- reason` is reported as
`ignore_without_reason`.

## Placeholders

`{{rule}}` `{{severity}}` `{{file}}` `{{line}}` `{{col}}` `{{found}}`
`{{name}}` `{{short_name}}` `{{package}}` `{{library}}` `{{type}}`
`{{receiver}}` `{{uri}}` `{{resolved_path}}` `{{package_path}}` `{{denied}}` `{{lines}}` `{{code_lines}}` `{{arg}}` `{{value}}`
`{{args.<name|index>}}` `{{allowed}}` `{{closest}}` `{{closest.name}}`
`{{enclosing_class}}` `{{enclosing_function}}` `{{ancestor}}`
`{{use_instead}}` `{{docs}}` `{{description}}` `{{vars.x}}` `{{values.x}}`
`{{ignore}}`. An unknown placeholder is a config error.

## Examples

```yaml
rules:
  no_gesture_detector_for_taps:
    match:
      new:
        name: GestureDetector
        package: [flutter, material_ui]
        args: { onTap: { present: true }, onPanUpdate: { present: false } }
    use_instead: InkWell
    message: "GestureDetector with only onTap has no ripple or semantics. Use {{use_instead}}."

  features_no_material:
    severity: error
    files: [lib/features/**]
    match: { import: "package:flutter/material.dart" }
    message: "{{uri}} must not be imported from feature code. Import package:app/ui/ui.dart."

  http_only_in_network:
    exclude: [lib/network/**]
    match: { import: { package: [http, dio] } }
    message: "Only lib/network may talk HTTP."

  no_setstate_in_build:
    match:
      call: { name: State.setState }
      inside: { function: { name: build } }
    message: "setState inside build() causes rebuild loops."

  screens_end_with_screen:
    files: [lib/screens/**]
    match: { class: { extends: StatefulWidget, name: { not: "*Screen" } } }
    message: "{{name}} under lib/screens must end with Screen."

  const_widget_constructors:
    match: { class: { extends: StatelessWidget, lacks: { function: { kind: constructor, const: true } } } }
    message: "{{name}} needs a const constructor."

  spacing_on_scale:
    match:
      new:
        name: [EdgeInsets.all, EdgeInsets.symmetric, EdgeInsets.only]
        args: { "*": { literal: num, not_in: $spacing } }
    message: "{{value}} is off the spacing scale. Allowed: {{allowed}}. Closest: {{closest}}."
    suggest: "{{name}}({{arg}}: {{closest.name}})"

  small_widget_files:
    match:
      file: { max_code_lines: 100 }
      contains: { class: { extends: Widget } }
    message: "{{file}} has {{code_lines}} lines of code; widget files stay under 100. Split it into smaller widgets."
```

More in [`example/agent_lints.yaml`](example/agent_lints.yaml), which the
end-to-end tests run against the app in `example/`.

## The agent loop

1. `dart run agent_lints explain --kinds` prints the rule language, generated
   from the matcher code so it never drifts.
2. The agent edits `agent_lints.yaml`.
3. `dart run agent_lints validate` reports every problem with a position and a
   hint.
4. `dart run agent_lints test` proves the rule: each `examples.bad` snippet
   must trigger it and each `examples.good` must not. Snippets are real Dart
   files resolved against the project's dependencies, and file scoping is
   ignored for them.
5. `dart run agent_lints` on the code, then fix from the `why` / `suggest`
   lines.

`dart run agent_lints init --agents-md --claude-skill` writes this loop into
`AGENTS.md` / `CLAUDE.md` and a Claude Code skill so agents find it.

## Config errors are written for agents too

Every problem is reported at once, with the YAML path, position and a hint:

```
[config] agent_lints.yaml:14:7 rules.no_print.match.call.nmae: unknown key "nmae" (did you mean "name"?)
[config] agent_lints.yaml:16:14 rules.no_print.message: unknown placeholder {{fil}} (did you mean {{file}}?)
```

## Exit codes

`0` clean · `1` violations at or above `fail_on` · `2` invalid config ·
`3` analysis failure · `64` usage error.

## Status

Under active development. Coming next: the analyzer plugin (`dart analyze` and
IDE diagnostics), and the `init` / `explain` / `test` commands.

## License

MIT
