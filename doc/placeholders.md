---
title: Placeholders
description: Everything a message, suggest or use_instead string can interpolate.
---

# Placeholders

`message`, `suggest` and `description` are templates. `{{name}}` is replaced
at report time; a placeholder that is unknown, or not declared under `vars:` /
`values:`, is a config error with a did-you-mean hint. A placeholder that has
no value for a particular hit renders as empty text.

## Always available

| Placeholder | Value |
|---|---|
| `{{rule}}` | rule id |
| `{{severity}}` | `error`, `warning`, `info` |
| `{{file}}` | project-relative path of the file |
| `{{line}}`, `{{col}}` | 1-based position |
| `{{found}}` | source of the matched node, comments and doc comments removed, whitespace collapsed, at most 120 characters |
| `{{enclosing_class}}`, `{{enclosing_function}}` | names of the declarations around the node |
| `{{use_instead}}`, `{{docs}}`, `{{description}}` | the rule's own fields (`docs` falls back to the top-level `docs`) |
| `{{ignore}}` | the ready-to-paste suppression comment |
| `{{vars.<k>}}` | custom strings from the rule's `vars:` |
| `{{values.<list>}}` | a values list rendered as `4, 8 (AppSpacing.sm), 16` |

## From the matched node

| Placeholder | Set by | Value |
|---|---|---|
| `{{name}}` | `use`, `new`, `call`, `ref`, `class`, `function`, `variable`, `file`, `import`, `deny_imports` | resolved qualified name (`EdgeInsets.all`, `State.setState`, `HomeScreen`); the URI for imports |
| `{{short_name}}` | same | the last segment (`all`, `setState`) |
| `{{package}}`, `{{library}}` | `new`, `call`, `ref`, `import` | defining package / library URI |
| `{{type}}` | `new`, `call`, `ref`, `variable`, `literal` | static type |
| `{{kind}}` | `class`, `function`, `variable`, `literal` | `class` / `mixin` / `method` / `constructor` / `top_level` / `int` ... |
| `{{receiver}}` | `call` | source of the receiver expression |
| `{{uri}}` | `import`, `deny_imports` | the import URI as written |
| `{{resolved_path}}` | `import`, `deny_imports` | project path of the imported file, when inside the project |
| `{{package_path}}` | `import`, `deny_imports` | `package:app/...` form of that path |
| `{{denied}}` | `deny_imports` | the entry that matched |
| `{{lines}}`, `{{code_lines}}` | `file` | line counts |
| `{{ancestor}}` | `parent`, `inside` | name (or source) of the ancestor that matched |

## From arguments

| Placeholder | Value |
|---|---|
| `{{args.<name>}}`, `{{args.<index>}}` | source of each argument of a matched `new` / `call`, keyed by parameter name and position; available even without an `args:` block |
| `{{arg}}` | the parameter name that satisfied an `args:` constraint |
| `{{value}}` | its constant value (`10`, `'x'`, `true`) or its source when not constant |
| `{{allowed}}` | the values list used by `in` / `not_in`, rendered |
| `{{closest}}` | the two nearest entries of that list to `{{value}}` |
| `{{closest.name}}`, `{{closest.value}}` | the nearest entry's name (or value) and value |

## Writing good messages

A violation should be a complete lesson for whoever reads it, human or agent:

1. What was found: `{{found}}` or `{{name}}`.
2. Why it is a problem: one sentence.
3. What to write instead: `{{use_instead}}`, a `suggest` snippet, or the
   allowed values.
4. Where to change things if the rule is too strict: a file path or `{{docs}}`.

The IDE shows the message on one line followed by the correction (built from
`use_instead`, `suggest`, `docs` and the explain command), so the first
sentence should stand on its own. Keep file paths out of the message when the
IDE already shows them; put them in `docs` or `use_instead` instead.
