---
title: Recipes
description: Ready-made rules for Flutter and Dart projects. Copy, adapt, run `dart run agent_lints test`.
---

# Recipes

Every recipe is a complete rule. Copy it under `rules:` and adjust names and
paths. Run `dart run agent_lints validate` and `dart run agent_lints test`
after pasting.

## Logging and debugging

```yaml
  no_print:
    severity: error
    use: print
    from: dart:core
    use_instead: AppLog.d(...)
    hint: "AppLog.d({{args.0}})"
    message: "`print` ships to release logs. Use {{use_instead}}."

  no_future_delayed_in_prod:
    constructor: Future.delayed
    from: dart:async
    message: "Future.delayed in production code hides timing bugs. Inject a clock or use a stream."
```

## Flutter pitfalls

```yaml
  no_setstate_in_build:
    severity: error
    call: State.setState
    inside: { function: build }
    message: "setState inside build() causes rebuild loops. Move it to a handler or initState."

  listview_in_column:
    constructor: ListView
    args: { shrinkWrap: absent }
    parent: { constructor: Column }
    message: "ListView directly inside {{ancestor}} needs shrinkWrap: true or an Expanded wrapper."

  no_gesture_detector_for_taps:
    constructor: GestureDetector
    from: flutter
    args: { onTap: present, onPanUpdate: absent }
    use_instead: InkWell (ripple + semantics)
    hint: "InkWell(onTap: {{args.onTap}}, child: ...)"
    message: "GestureDetector with only onTap has no ripple or semantics. Use {{use_instead}}."

  const_widget_constructors:
    class: { extends: StatelessWidget }
    lacks: { function: { kind: constructor, const: true } }
    message: "{{name}} needs a const constructor: `const {{name}}({super.key})`."

  scaffold_body_safearea:
    severity: info
    constructor: Scaffold
    args: { body: { expr: { not: { constructor: SafeArea } } } }
    message: "Wrap the Scaffold body in SafeArea."
```

## Architecture and layering

```yaml
  features_no_material:
    severity: error
    deny_imports: [package:flutter/material.dart, package:material_ui/**]
    files: [lib/features/**]
    replace_with: package:app/ui/ui.dart
    message: "{{uri}} must not be imported from feature code. Import {{use_instead}}, which re-exports the approved widgets."

  http_only_in_network:
    severity: error
    deny_imports: ["package:http/**", "package:dio/**"]
    exclude: [lib/network/**]
    message: "Only lib/network may talk HTTP. Use ApiClient from lib/network/api_client.dart."

  no_relative_imports:
    deny_imports: [relative]
    message: "Use package imports: {{uri}} -> {{package_path}}"

  domain_has_no_flutter:
    severity: error
    deny_imports: ["package:flutter/**", "dart:ui"]
    files: [lib/domain/**]
    message: "lib/domain is pure Dart. {{uri}} does not belong here."

  providers_in_provider_files:
    variable: any
    scope: top_level
    type: { name: ProviderBase, from: riverpod }
    exclude: ["lib/**/*_provider.dart"]
    message: "Provider {{name}} must be declared in a *_provider.dart file."
```

## Naming

```yaml
  screens_named_screen:
    class: { extends: StatefulWidget }
    name: { not: "*Screen" }
    files: [lib/screens/**]
    message: "{{name}} under lib/screens must end with Screen."

  snake_case_files:
    file: { name: { not_style: snake_case } }
    message: "File {{name}}.dart must be snake_case."

  private_helpers_underscore:
    function: any
    kind: function
    name: { not: "/^_|^main$/" }
    files: [lib/features/**]
    message: "Top-level helper {{name}} in feature code should be private."
```

## Design tokens

```yaml
values:
  spacing:
    - 4
    - { value: 8, name: AppSpacing.sm }
    - { value: 16, name: AppSpacing.md }
    - { value: 24, name: AppSpacing.lg }

rules:
  no_raw_colors:
    severity: error
    constructor: Color
    from: dart:ui
    exclude: [lib/core/theme/**]
    use_instead: AppColors.* (lib/core/theme/app_colors.dart) or Theme.of(context).colorScheme
    message: "Raw {{found}}. Colours live in app_colors.dart; add a named colour there if none fits."

  no_palette_colors:
    use: "Colors.*"
    from: flutter
    except: { use: Colors.transparent }
    use_instead: Theme.of(context).colorScheme
    message: "{{name}} is a raw palette colour. Use {{use_instead}}."

  spacing_on_scale:
    constructor: [EdgeInsets.all, EdgeInsets.symmetric, EdgeInsets.only]
    from: flutter
    args: { "*": { literal: num, not_in: $spacing } }
    message: "{{value}} passed to {{name}}({{arg}}) is off the spacing scale. Allowed: {{allowed}}. Closest: {{closest}}."
    hint: "{{name}}({{arg}}: {{closest.name}})"

  no_raw_text_styles:
    constructor: TextStyle
    from: dart:ui
    files: [lib/features/**]
    use_instead: Theme.of(context).textTheme.* or AppTextStyles.*
    message: "Raw TextStyle in feature code. Use {{use_instead}}."

  no_adhoc_card:
    constructor: Container
    args: { decoration: { expr: { constructor: BoxDecoration, args: { color: present } } } }
    files: [lib/features/**]
    use_instead: AppCard
    message: "Ad-hoc surface: Container(decoration: BoxDecoration(color:)). Use {{use_instead}}; add a variant in lib/ui/card.dart if none fits."
```

## Size and hygiene

```yaml
  small_widget_files:
    file: { max_code_lines: 100 }
    contains: { class: { extends: Widget } }
    message: "{{code_lines}} lines of code in a widget file; the limit is 100. Extract sub-widgets into their own files."

  no_hardcoded_urls:
    literal: string
    source: "/^'https?:/"
    exclude: [lib/config/**]
    message: "URL literal {{found}} belongs in lib/config/endpoints.dart."

  no_hardcoded_ui_strings:
    severity: error
    constructor: Text
    from: flutter
    args: { data: { literal: string } }
    files: [lib/features/**]
    message: "User-facing string {{args.data}} must come from context.l10n.*"
```
