---
title: Rule language
description: The match: reference. Node kinds, name resolution, argument constraints, context, combinators.
---

# Rule language: `match:`

A `match:` block is a **matcher**: a map with exactly one *node key* plus
optional *context keys*, or a *combinator*. Rules fire once per AST node the
matcher accepts.

```yaml
match:
  new:                                   # node key: which nodes to look at
    name: ListView
    args: { shrinkWrap: { present: false } }
  inside: { new: { name: Column }, direct: true }   # context key
```

```yaml
match:
  any:                                   # combinator
    - call: { name: print, package: dart:core }
    - call: { name: debugPrint, package: flutter }
```

Print the same reference from the installed version with
`dart run agent_lints explain --kinds`; it is generated from the code.

## String patterns

Every `name`, `uri`, `package`, `library`, `kind`, `prefix`, ... accepts:

| Form | Matches |
|---|---|
| `Text` | exactly that |
| `*Screen`, `EdgeInsets.*`, `package:flutter/**` | glob; `*` and `**` both match any characters, `?` one character |
| `/^_.*Impl$/` | Dart regular expression |
| `[a, b]` | any of the listed patterns |
| `{ not: pattern }` | negation |

## Name resolution

`name:` is compared with the **resolved element**, never with source text.
Each element offers several candidate spellings and the pattern must match one:

| Element | Candidates | Example patterns |
|---|---|---|
| constructor | `Class`, `Class.ctor` (`Class.new` for the unnamed one) | `EdgeInsets` (any constructor), `EdgeInsets.all`, `EdgeInsets.*`, `Container.new` |
| method, getter, setter, field | `member`, `Class.member`, `.member` | `setState`, `State.setState`, `.withOpacity` |
| top-level function or variable | `name` | `print`, `kDebugMode` |
| class, mixin, enum, extension | `Name` | `Colors` |

`Class` is the **declaring** class: `Navigator.of(ctx).push(...)` resolves to
`NavigatorState.push`. Prefixed imports (`m.Text`) and re-exports do not matter.
An unresolved name (dynamic call, broken import) falls back to the written
identifier.

### Origin filters

| Key | Compares with | Notes |
|---|---|---|
| `package` | the package that **defines** the element: `flutter`, `http`, `dart:core`, `dart:ui` | `project` means the analyzed package. Lists allowed: `package: [flutter, material_ui]`. |
| `library` | the defining library URI, e.g. `package:flutter/src/widgets/text.dart` | glob; use it to be precise about a `src/` file |

Flutter's `Color`, `Offset` and friends are defined in `dart:ui`, so a rule
about them says `package: [flutter, dart:ui]`.

### Type patterns

`type:`, `returns:`, `extends:`, `implements:`, `mixes_in:`, `on.type:` and
`args.<x>.type:` take a type pattern. A bare string checks the static type
**and its supertypes** (`type: Widget` accepts a `Text`). The map form adds
control:

```yaml
type: { name: Color, package: dart:ui }   # name plus defining package
type: { exact: Color }                    # no subtype walk
```

## Node kinds

### `new` — constructor calls

```yaml
new:
  name: GestureDetector          # pattern; also bare shorthand: `new: GestureDetector`
  package: [flutter, material_ui]
  library: package:flutter/src/**
  const: true                    # only `const` instantiations (false: only non-const)
  type: Widget                   # static type of the created object (subtype check)
  args: { ... }                  # see Arguments
```

### `call` — method and function invocations

```yaml
call:
  name: State.setState
  package: flutter
  on: { type: BuildContext }     # static type of the receiver
  on: { name: Navigator }        # receiver is a class or prefix reference with this name
  returns: Future                # static return type
  await: false                   # true = the call is awaited; false = it is not
  static: true                   # static method
  args: { ... }
```

`on:` also accepts a bare type pattern (`on: List`).

### `ref` — references that are not calls

`Colors.red`, `math.pi`, `Theme.of(context).colorScheme.primary`, a tear-off,
a bare class name.

```yaml
ref:
  name: "Colors.*"
  package: flutter
  type: Color
```

Method names inside an invocation, constructor names, labels and import
prefixes are not references.

### `import` — import and export directives

```yaml
import:
  uri: "package:http/**"         # the URI as written; bare shorthand: `import: "package:http/**"`
  package: http                  # resolved target package (`project` for this package)
  relative: true                 # URI without a scheme
  prefix: http                   # `as http`
  show: get                      # a name listed in `show`
  kind: import                   # import | export | any
  deferred: true
```

Captures `{{uri}}`, `{{package}}`, `{{resolved_path}}` (project path of the
target when inside the project) and `{{package_path}}`
(`package:app/x.dart` form of that path). For layering rules prefer the
[`imports` sugar](sugar-kinds.md#imports).

### `class` — class, mixin, enum, extension declarations

```yaml
class:
  name: "*Screen"
  kind: class                    # class | mixin | enum | extension
  extends: StatefulWidget        # walks the superclass chain
  implements: Comparable         # any supertype
  mixes_in: TickerProvider*
  abstract: true
  annotation: immutable          # has @immutable
  has:   { function: { name: build, override: true } }   # some member matches
  lacks: { function: { kind: constructor, const: true } } # no member matches
```

`has` / `lacks` take a matcher (or a list) evaluated against each member;
`function` and `variable` matchers work there. Diagnostics are anchored on the
class name.

### `function` — function, method, constructor, getter, setter declarations

```yaml
function:
  name: build
  kind: method                   # method | function | constructor | getter | setter | local
  returns: Widget
  async: true                    # async or async*
  static: true
  const: true                    # const constructor
  override: true                 # has @override
  annotation: visibleForTesting
```

### `variable` — top-level variables, fields, locals

```yaml
variable:
  name: "*Provider"
  scope: top_level               # top_level | field | local
  type: ProviderBase
  const: true
  final: false
  late: true
  static: true
  annotation: riverpod
  initializer: { new: { name: Text } }   # matcher on the initializer expression
```

### `literal` — int, double, string, bool, null, list, map literals

```yaml
literal:
  kind: string                   # int | double | num | string | bool | null | list | map | set | any
  value: 0
  in: $spacing                   # or an inline list
  not_in: [4, 8, 16]
  min: 0
  max: 100
  source: "/^'https?:/"          # regex over the literal's source text (quotes included)
  interpolated: false            # string with ${}
```

Import and export URIs are not reported as string literals.

### `file` — the file itself

Reported at line 1. Combine with `contains:` to describe "files that hold X".

```yaml
file:
  name: "*_screen"               # base name without .dart
  path: "lib/features/**"
  max_lines: 300                 # violation when the file has MORE lines
  min_lines: 5                   # violation when it has FEWER
  max_code_lines: 100            # same, counting only lines with code
  min_code_lines: 1
```

Code lines are lines holding at least one token that is not a comment: blank
lines and comment-only lines do not count; a multi-line string counts every line
it spans. Captures `{{lines}}` and `{{code_lines}}`.

## Arguments: `args:`

On `new` and `call`. Keys are **parameter names** (positional arguments are
matched to their parameter name through the resolved signature), a positional
index (`0`, `1`), `"*"` (at least one argument satisfies) or `"**"` (every
argument satisfies).

```yaml
args:
  onTap: { present: true }                      # passed at the call site
  onPanUpdate: { present: false }               # not passed
  value: { literal: num, not_in: $spacing }     # a numeric literal not on the list
  data: { source: "/^'http/" }                  # regex over the argument source
  color: { ref: { name: "Colors.*" } }          # the argument is such a reference
  decoration:
    expr: { new: { name: BoxDecoration, args: { color: { present: true } } } }
```

| Constraint | Meaning |
|---|---|
| `present` | `true`: the argument must be passed; `false`: it must not |
| `literal` | the argument is a literal of that kind (`int`, `double`, `num`, `string`, `bool`, `null`, `list`, `map`, `set`, `any`) |
| `value` | constant value equals |
| `in` / `not_in` | constant value is / is not in the list (`$name` or inline). Non-constant arguments never match |
| `min` / `max` | numeric constant bounds |
| `type` | static type (subtype check unless `exact`) |
| `source` | regex over the argument's source text |
| `ref` | the argument matches this `ref` body |
| `expr` | the argument matches this full nested matcher |

All constraints of one argument are ANDed. On success `{{arg}}` is the
parameter name and `{{value}}` the constant value (or source). Every argument
of the call is also available as `{{args.<name>}}` and `{{args.<index>}}`,
whether or not `args:` is used.

## Context keys

Sit next to the node key. All must hold.

```yaml
match:
  new: { name: ListView }
  inside: { new: { name: Column }, direct: true }
  not_inside: { function: { name: build } }
  contains: { call: { name: setState } }
  not_contains: { new: { name: SafeArea } }
```

| Key | Meaning |
|---|---|
| `inside` | some ancestor matches. Accepts a list; each entry needs its own ancestor. Captures `{{ancestor}}`. |
| `direct: true` (inside an `inside` entry) | the matched node is an *argument* of that ancestor, with only argument lists, named arguments, list literals, spreads and parentheses in between. This is the "wrapper" test: `Padding(child: AppButton())`. |
| `not_inside` | no ancestor matches |
| `contains` | some descendant matches |
| `not_contains` | no descendant matches |

`inside` and `contains` are **syntactic**: they walk the tree of this file. A
widget returned from a helper method is not an ancestor of what that method
builds.

## Combinators

```yaml
match:
  any: [ {call: print}, {call: debugPrint} ]   # first branch that matches wins
match:
  all: [ {new: {type: Widget}}, {new: {const: false}} ]  # every branch on the same node
args:
  body: { expr: { not: { new: { name: SafeArea } } } }   # negation, nested only
```

`not` cannot be the root of a rule (it would match every other node).

## Examples

```yaml
rules:
  no_setstate_in_build:
    match:
      call: { name: State.setState }
      inside: { function: { name: build } }
    message: "setState inside build() causes rebuild loops."

  listview_in_column:
    match:
      new: { name: ListView, args: { shrinkWrap: { present: false } } }
      inside: { new: { name: Column }, direct: true }
    message: "ListView directly inside {{ancestor}} needs shrinkWrap: true or an Expanded wrapper."

  const_widget_constructors:
    match:
      class:
        extends: StatelessWidget
        lacks: { function: { kind: constructor, const: true } }
    message: "{{name}} needs a const constructor."

  providers_in_provider_files:
    exclude: ["lib/**/*_provider.dart"]
    match: { variable: { scope: top_level, type: { name: ProviderBase, package: riverpod } } }
    message: "Provider {{name}} must live in a *_provider.dart file."

  small_widget_files:
    match:
      file: { max_code_lines: 100 }
      contains: { class: { extends: Widget } }
    message: "{{code_lines}} lines of code in a widget file; the limit is 100."
```

More in [Recipes](recipes.md).
