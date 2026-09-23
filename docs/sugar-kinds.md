---
title: Sugar kinds
description: banned, imports and naming, the three shorthands over match.
---

# Sugar kinds

Three rule kinds cover the rules teams write most often. `banned` and `naming`
expand to a `match:` block; `imports` is engine-native because it needs the
resolved target file of each import. `dart run agent_lints explain <rule>`
prints the compiled form of any of them.

## `banned`

"Do not use X." Accepts a string, a list, or `{ name, package, library }`.

```yaml
  no_opacity:
    banned: [Opacity, .withOpacity, Colors.red]
    use_instead: AppFade / Color.withValues / AppColors.*
    message: "{{name}} is banned. Use {{use_instead}}."

  no_palette:
    banned: { name: "Colors.*", package: [flutter, material_ui] }
    message: "{{name}} is a raw palette colour."
```

Expands to `match: { any: [ {new: ...}, {call: ...}, {ref: ...} ] }` with the
same filter, so constructors, calls and plain references are all caught.

## `imports`

Layering and dependency rules.

```yaml
  features_no_material:
    severity: error
    imports:
      from: [lib/features/**]              # files this applies to (adds to `files`)
      deny:                                # any of:
        - package:flutter/material.dart    #   a package: or dart: URI glob
        - lib/data/**                      #   a project path glob, matched against the RESOLVED target
        - relative                         #   any relative import
      except: [lib/features/**/theme/**]   # exempt files (adds to `exclude`)
      replace_with: package:app/ui/ui.dart # feeds {{use_instead}}
    message: "{{uri}} is not allowed here ({{denied}}). Import {{use_instead}}."
```

- URI globs are tested against the URI as written **and** the resolved library
  URI, so `package:flutter/**` also catches `import 'package:flutter/src/...'`.
- Path globs use the resolved file, so `'../data/repo.dart'` and
  `'package:app/data/repo.dart'` both hit `lib/data/**`.
- Export directives are matched too.
- Captures: `{{uri}}`, `{{package}}`, `{{resolved_path}}`, `{{package_path}}`,
  `{{denied}}` (the entry that matched), `{{use_instead}}`.

Common shapes:

```yaml
  http_only_in_network:
    imports: { deny: ["package:http/**", "package:dio/**"], except: [lib/network/**] }
    message: "Only lib/network may talk HTTP."

  no_relative_imports:
    imports: { deny: [relative] }
    message: "Use package imports: {{uri}} -> {{package_path}}"
```

## `naming`

Names must follow a pattern or a style.

```yaml
  screens_named_screen:
    files: [lib/screens/**]
    naming:
      target: class                          # class | function | variable | file
      where: { extends: StatefulWidget }     # body of that node kind, optional
      pattern: "*Screen"                     # glob, /regex/ or list
    message: "{{name}} must end with Screen."

  snake_case_files:
    naming: { target: file, style: snake_case }
    message: "File {{name}}.dart must be snake_case."
```

`style` is one of `snake_case`, `camelCase`, `PascalCase`,
`SCREAMING_SNAKE_CASE`. Give either `pattern` or `style`.

Expands to `match: { <target>: { ...where, name: { not: <pattern> } } }`, so the
rule fires for declarations whose name does **not** match. For `file` the base
name without `.dart` is tested.
