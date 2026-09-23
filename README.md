# agent_lints

Agent-first custom lint for Dart and Flutter.

Your project rules live in one `agent_lints.yaml`. Humans and coding agents add
a rule by editing YAML, and the same tool checks the code from the CLI with
output written for agents to self-correct in one pass. An analyzer plugin for
`dart analyze` and IDEs is in progress.

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
dart run agent_lints            # check (default). Exit 1 when rules fail.
dart run agent_lints validate   # validate the YAML only, exit 0/2
dart run agent_lints --format json | agent | human
```

Output defaults to `human` on a terminal and `agent` when piped, so agents
calling it from a shell get the rich form.

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
    match: { ... }             # exactly one of: match | banned
    severity: warning          # error | warning | info | off
    description: "one line"
    files: [lib/features/**]   # narrow this rule
    exclude: [lib/legacy/**]
    message: "..."             # required; supports {{placeholders}}
    use_instead: "..."
    suggest: "..."             # replacement snippet, placeholders allowed
    docs: docs/ui.md#buttons
    vars: { logger: AppLog }   # {{vars.logger}}
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

**Sugar:** `banned: Opacity` (string, list or `{name, package}`) expands to
`any: [new, call, ref]` for that name.

## Placeholders

`{{rule}}` `{{severity}}` `{{file}}` `{{line}}` `{{col}}` `{{found}}`
`{{name}}` `{{short_name}}` `{{package}}` `{{library}}` `{{type}}`
`{{receiver}}` `{{uri}}` `{{resolved_path}}` `{{arg}}` `{{value}}`
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
```

More in [`example/agent_lints.yaml`](example/agent_lints.yaml), which the
end-to-end tests run against the app in `example/`.

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

Under active development. Coming next: inline suppression, `imports` and
`naming` sugar, `variable` / `literal` matchers, SARIF output, the analyzer
plugin, and `init` / `explain` commands.

## License

MIT
