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
    match: { call: { name: print, package: dart:core } }
    use_instead: AppLog.d(...)
    suggest: "AppLog.d({{args.0}})"
    message: "`print` ships to release logs. Use {{use_instead}}."

  no_future_delayed_in_prod:
    match: { new: { name: Future.delayed, package: dart:async } }
    message: "Future.delayed in production code hides timing bugs. Inject a clock or use a stream."
```

## Flutter pitfalls

```yaml
  no_setstate_in_build:
    severity: error
    match:
      call: { name: State.setState }
      inside: { function: { name: build } }
    message: "setState inside build() causes rebuild loops. Move it to a handler or initState."

  listview_in_column:
    match:
      new: { name: ListView, args: { shrinkWrap: { present: false } } }
      inside: { new: { name: Column }, direct: true }
    message: "ListView directly inside {{ancestor}} needs shrinkWrap: true or an Expanded wrapper."

  no_gesture_detector_for_taps:
    match:
      new:
        name: GestureDetector
        package: [flutter, material_ui]
        args: { onTap: { present: true }, onPanUpdate: { present: false } }
    use_instead: InkWell (ripple + semantics)
    suggest: "InkWell(onTap: {{args.onTap}}, child: ...)"
    message: "GestureDetector with only onTap has no ripple or semantics. Use {{use_instead}}."

  const_widget_constructors:
    match:
      class:
        extends: StatelessWidget
        lacks: { function: { kind: constructor, const: true } }
    message: "{{name}} needs a const constructor: `const {{name}}({super.key})`."

  scaffold_body_safearea:
    severity: info
    match:
      new:
        name: Scaffold
        args: { body: { expr: { not: { new: { name: SafeArea } } } } }
    message: "Wrap the Scaffold body in SafeArea."
```

## Architecture and layering

```yaml
  features_no_material:
    severity: error
    imports:
      from: [lib/features/**]
      deny: [package:flutter/material.dart, package:material_ui/**]
      replace_with: package:app/ui/ui.dart
    message: "{{uri}} must not be imported from feature code. Import {{use_instead}}, which re-exports the approved widgets."

  http_only_in_network:
    severity: error
    imports: { deny: ["package:http/**", "package:dio/**"], except: [lib/network/**] }
    message: "Only lib/network may talk HTTP. Use ApiClient from lib/network/api_client.dart."

  no_relative_imports:
    imports: { deny: [relative] }
    message: "Use package imports: {{uri}} -> {{package_path}}"

  domain_has_no_flutter:
    severity: error
    imports: { from: [lib/domain/**], deny: ["package:flutter/**", "dart:ui"] }
    message: "lib/domain is pure Dart. {{uri}} does not belong here."

  providers_in_provider_files:
    exclude: ["lib/**/*_provider.dart"]
    match: { variable: { scope: top_level, type: { name: ProviderBase, package: riverpod } } }
    message: "Provider {{name}} must be declared in a *_provider.dart file."
```

## Naming

```yaml
  screens_named_screen:
    files: [lib/screens/**]
    naming: { target: class, where: { extends: StatefulWidget }, pattern: "*Screen" }
    message: "{{name}} under lib/screens must end with Screen."

  snake_case_files:
    naming: { target: file, style: snake_case }
    message: "File {{name}}.dart must be snake_case."

  private_helpers_underscore:
    files: [lib/features/**]
    naming:
      target: function
      where: { kind: function, annotation: { not: visibleForTesting } }
      pattern: "/^_|^main$/"
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
    exclude: [lib/core/theme/**]
    match: { new: { name: Color, package: [flutter, dart:ui] } }
    use_instead: AppColors.* (lib/core/theme/app_colors.dart) or Theme.of(context).colorScheme
    message: "Raw {{found}}. Colours live in app_colors.dart; add a named colour there if none fits."

  no_palette_colors:
    banned: { name: "Colors.*", package: [flutter, material_ui] }
    use_instead: Theme.of(context).colorScheme
    message: "{{name}} is a raw palette colour. Use {{use_instead}}."

  spacing_on_scale:
    match:
      new:
        name: [EdgeInsets.all, EdgeInsets.symmetric, EdgeInsets.only]
        package: [flutter, material_ui]
        args: { "*": { literal: num, not_in: $spacing } }
    message: "{{value}} passed to {{name}}({{arg}}) is off the spacing scale. Allowed: {{allowed}}. Closest: {{closest}}."
    suggest: "{{name}}({{arg}}: {{closest.name}})"

  no_raw_text_styles:
    files: [lib/features/**]
    match: { new: { name: TextStyle, package: [flutter, dart:ui] } }
    use_instead: Theme.of(context).textTheme.* or AppTextStyles.*
    message: "Raw TextStyle in feature code. Use {{use_instead}}."

  no_adhoc_card:
    files: [lib/features/**]
    match:
      new:
        name: Container
        args:
          decoration:
            expr: { new: { name: BoxDecoration, args: { color: { present: true } } } }
    use_instead: AppCard
    message: "Ad-hoc surface: Container(decoration: BoxDecoration(color:)). Use {{use_instead}}; add a variant in lib/ui/card.dart if none fits."
```

## Size and hygiene

```yaml
  small_widget_files:
    match:
      file: { max_code_lines: 100 }
      contains: { class: { extends: Widget } }
    message: "{{code_lines}} lines of code in a widget file; the limit is 100. Extract sub-widgets into their own files."

  no_hardcoded_urls:
    exclude: [lib/config/**]
    match: { literal: { kind: string, source: "/^'https?:/" } }
    message: "URL literal {{found}} belongs in lib/config/endpoints.dart."

  no_hardcoded_ui_strings:
    severity: error
    files: [lib/features/**]
    match: { new: { name: Text, package: flutter, args: { data: { literal: string } } } }
    message: "User-facing string {{args.data}} must come from context.l10n.*"
```
