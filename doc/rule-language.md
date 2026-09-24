---
title: Rule language
description: How a rule is written. Node keys, attributes, arguments, context, patterns.
---

# Rule language

A rule is a flat map under its id: **one node key** that says what to look at,
the node's **attributes**, an optional **`args:`** block, optional **context**
keys, and the rule fields (`message`, `severity`, ...). Nothing nests deeper
than three levels.

```yaml
rules:
  listview_in_column:
    new: ListView                      # node key: constructor calls named ListView
    args: { shrinkWrap: absent }       # argument constraint
    parent: { new: Column }            # context: direct child of a Column
    message: "ListView directly inside {{ancestor}} needs shrinkWrap: true."
```

`dart run agent_lints explain --kinds` prints this reference from the
installed version; it is generated from the code.

## Node keys

Exactly one per rule. A bare value is the node's main attribute (its name, or
the URI for `import`); a map sets several; `any` means "no constraint on the
name". Attributes can also be written as sibling lines, which keeps rules flat:

```yaml
    new: { name: GestureDetector, package: flutter }   # same as:
    new: GestureDetector
    package: flutter
```

| Key | Matches | Attributes |
|---|---|---|
| `use` | any use of a symbol: constructor, call or reference | `name`, `package`, `library` |
| `new` | constructor calls | `name`, `package`, `library`, `const`, `type`, `args` |
| `call` | method and function calls | `name`, `package`, `library`, `on`, `returns`, `await`, `static`, `args` |
| `ref` | references that are not calls (`Colors.red`, tear-offs) | `name`, `package`, `library`, `type` |
| `import` | import / export directives | `uri`, `package`, `relative`, `prefix`, `show`, `kind: import\|export\|any`, `deferred` |
| `deny_imports` | imports of the listed entries: `package:`/`dart:` URI globs, project path globs (`lib/data/**`, resolved through relative imports), or `relative` | `deny`, `replace_with` |
| `class` | class / mixin / enum / extension declarations | `name`, `kind`, `extends`, `implements`, `mixes_in`, `abstract`, `annotation`, `has`, `lacks` |
| `function` | function / method / constructor / getter / setter declarations | `name`, `kind`, `returns`, `async`, `static`, `const`, `override`, `annotation` |
| `variable` | top-level variables, fields, locals | `name`, `scope: top_level\|field\|local`, `type`, `const`, `final`, `late`, `static`, `annotation`, `initializer` |
| `literal` | int / double / string / bool / null / list / map literals | `kind`, `value`, `in`, `not_in`, `min`, `max`, `source`, `interpolated` |
| `file` | the file itself, reported at line 1 | `name` (base name without `.dart`), `path`, `max_lines`, `min_lines`, `max_code_lines`, `min_code_lines` |

Most rules want `use`. Reach for `new` / `call` / `ref` when you need `args`,
`on`, `await` or `type`.

## Patterns

Every name-like attribute (`name`, `uri`, `package`, `library`, `kind`,
`prefix`, `show`, `annotation`, ...) accepts:

| Form | Matches |
|---|---|
| `Text` | exactly that |
| `*Screen`, `EdgeInsets.*`, `package:flutter/**` | glob; `*` and `**` match any characters, `?` one |
| `/^_.*Impl$/` | Dart regular expression |
| `[a, b]` | any of |
| `{ not: pattern }` | anything else |
| `{ style: snake_case }`, `{ not_style: PascalCase }` | identifier style: `snake_case`, `camelCase`, `PascalCase`, `SCREAMING_SNAKE_CASE` |

## Name resolution

Names are compared with the **resolved element**, never with source text, so
aliases (`m.Text`), re-exports and barrel files do not matter. Each element
offers several spellings and the pattern must match one:

| Element | Spellings |
|---|---|
| constructor | `Class`, `Class.ctor` (`Class.new` for the unnamed one) |
| method, getter, setter, field | `member`, `Class.member`, `.member` |
| top-level function or variable | `name` |
| class, mixin, enum, extension | `Name` |

`Class` is the **declaring** class: `Navigator.of(ctx).push(...)` is
`NavigatorState.push`. An unresolved name (dynamic call, broken import) falls
back to the identifier as written.

### `package` and `library`

`package` is the package that **defines** the element (`flutter`, `http`,
`dart:core`, `dart:ui`; `project` for the analyzed package). Lists are common:
`package: [flutter, material_ui]`. `Color` and `Offset` live in `dart:ui`.
`library` is a glob over the defining library URI
(`package:flutter/src/widgets/**`) for when a `src/` file matters.

### Types

`type`, `returns`, `extends`, `implements`, `mixes_in`, `on.type` and
`args.<x>.type` take a type pattern. A bare string checks the static type
**and its supertypes** (`type: Widget` accepts a `Text`). `{ exact: Color }`
disables the subtype walk; `{ name: Color, package: dart:ui }` adds the
package.

## Arguments: `args:`

On `new` and `call`. Keys are **parameter names** (positional arguments are
matched to their parameter through the resolved signature), a positional
index, `"*"` (some argument) or `"**"` (every argument).

```yaml
    args:
      onTap: present                      # passed at the call site
      onPanUpdate: absent                 # not passed
      horizontal: 16                      # constant value equals
      value: [4, 8, 16]                   # constant value is one of
      padding: { literal: num, not_in: $spacing }
      data: { source: "/^'http/" }
      color: { ref: { name: "Colors.*" } }
      decoration: { expr: { new: BoxDecoration, args: { color: present } } }
```

Map form constraints, all ANDed:

| Key | Meaning |
|---|---|
| `present` | `true` / `false` |
| `literal` | the argument is a literal of that kind (`int`, `double`, `num`, `string`, `bool`, `null`, `list`, `map`, `set`, `any`) |
| `value` | constant value equals |
| `in` / `not_in` | constant value is / is not in the list (`$name` or inline); non-constant arguments never match |
| `min` / `max` | numeric bounds |
| `type` | static type |
| `source` | regex over the source text |
| `ref` | the argument is a reference matching this `ref` body |
| `expr` | the argument matches this nested matcher |

`{{arg}}` is the parameter that satisfied a constraint, `{{value}}` its value,
and every argument is available as `{{args.<name>}}` / `{{args.<index>}}`.

## Context

Sibling keys that constrain where the node sits. Each takes a matcher map
(the same flat grammar: one node key plus attributes) or a list of them.

| Key | Meaning |
|---|---|
| `parent` | the node is an argument of this ancestor, with only argument lists, list literals and parentheses in between: `Padding(child: AppButton())` |
| `inside` | some ancestor matches, at any distance. Captures `{{ancestor}}` |
| `not_inside` | no ancestor matches |
| `contains` | some descendant matches |
| `not_contains` | no descendant matches |
| `except` | the node must not also match this: "X except Y" |

`parent`, `inside` and `contains` are **syntactic**: a widget returned from a
helper method is not an ancestor of what that method builds.

## Combinators

```yaml
    any: [ { use: print }, { use: debugPrint } ]     # first branch that matches
    all: [ { new: any, type: Widget }, { new: any, const: false } ]
    args: { body: { expr: { not: { new: SafeArea } } } }   # not: nested only
```

`not` cannot be the root of a rule: a lint fires on a node, so anchor on the
node and negate a property (`name: { not: "*Screen" }`, `absent`, `not_in`,
`not_inside`, `except`).

## Rule fields

| Field | Notes |
|---|---|
| `severity` | `error` \| `warning` \| `info` \| `off` (default `warning`) |
| `message` | optional; defaults to `` `{{found}}` is not allowed here. Use {{use_instead}}. `` |
| `use_instead`, `suggest`, `docs`, `description`, `vars` | see [placeholders](placeholders.md) |
| `include`, `exclude` | file globs for this rule |
| `examples` | `bad:` and `good:` snippets for `dart run agent_lints test` |

## Examples

```yaml
rules:
  no_print:
    use: print
    package: dart:core
    use_instead: AppLog.d(...)

  no_setstate_in_build:
    call: State.setState
    inside: { function: build }
    message: "setState inside build() causes rebuild loops."

  no_palette_colors:
    use: "Colors.*"
    package: [flutter, material_ui]
    except: { use: Colors.transparent }
    use_instead: Theme.of(context).colorScheme

  features_no_material:
    deny_imports: [package:flutter/material.dart]
    include: [lib/features/**]
    replace_with: package:app/ui/ui.dart

  screens_named_screen:
    class: { extends: StatefulWidget }
    name: { not: "*Screen" }
    include: [lib/screens/**]
    message: "{{name}} must end with Screen."

  const_widget_constructors:
    class: { extends: StatelessWidget }
    lacks: { function: { kind: constructor, const: true } }
    message: "{{name}} needs a const constructor."

  small_widget_files:
    file: { max_code_lines: 100 }
    contains: { class: { extends: Widget } }
    message: "{{code_lines}} lines of code in a widget file; the limit is 100."
```

More in [Recipes](recipes.md).
