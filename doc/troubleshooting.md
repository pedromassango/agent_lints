---
title: Troubleshooting
description: Analyzer version conflicts, plugin not loading, stale plugin builds, unexpected matches.
---

# Troubleshooting

## Analyzer version conflict

```
Because freezed >=2.5.3 depends on analyzer ^7.0.0 and every version of agent_lints
depends on analyzer ^14.0.0, ... version solving failed.
```

agent_lints follows the analyzer version of the current Dart SDK because the
plugin API (`analysis_server_plugin`) pins it exactly. Code generators often
lag behind. You have two options that do not touch `pubspec.yaml`:

1. The IDE plugin needs no pubspec entry. Enable it in `analysis_options.yaml`
   ([IDE plugin](ide-plugin.md)); the analysis server resolves it in its own
   package.
2. Install the CLI globally:
   ```
   dart pub global activate agent_lints
   agent_lints
   ```

## No diagnostics in the IDE

Check, in order:

1. `plugins:` is in the **root** `analysis_options.yaml`, not a nested one.
2. The analysis server was restarted after editing that section.
3. The IDE uses a Dart SDK 3.10 or newer (Android Studio: Preferences, Dart
   SDK path). Plugins are silently ignored on older SDKs.
4. `dart analyze` from a terminal in the project shows the rules. If it does
   and the IDE does not, the IDE is on a different SDK or has not restarted.
5. The plugin failed to build: the analyzer diagnostics page (VS Code:
   "Dart: Open Analyzer Diagnostics") lists plugin errors. A git source needs
   network access on first use.

## The IDE runs an old agent_lints

With `ref: main` the server caches the checkout it made the first time. Change
`ref` to a newer commit or tag; any change to the `plugins:` entry triggers a
new resolution and build.

## A rule fires as INFO on one file

The analysis server asks a rule for its diagnostic codes before it analyzes
the first file. agent_lints loads configs at start-up from the server's
working directory (and four levels below it) to avoid that; if your config is
somewhere else, the first file analyzed after a restart may show INFO once.
Editing that file re-analyzes it with the right severity.

## `dart pub get` runs `example/` and fails

If you vendor agent_lints and it has an `example/` Flutter app, resolve the
package with `dart pub get --no-example`.

## A name does not match

- `name:` matches resolved elements. Use `dart run agent_lints explain <rule>`
  to see the compiled matcher, then compare with the element: a method is
  `Class.member` on its **declaring** class (`State.setState`, not
  `_MyState.setState`); an unnamed constructor is `Class` or `Class.new`.
- `package:` is the **defining** package. `Color` is from `dart:ui`, not
  `flutter`. `Text` is from `flutter` even when imported through
  `package:material_ui`. Use lists: `package: [flutter, material_ui]`.
- Generated files (`*.g.dart`, `*.freezed.dart`, ...) are always excluded.
- The file is outside `include` (default `lib/**`) or excluded by the rule's
  `files` / `exclude`. `explain` prints the effective scope.
- The code does not resolve (missing `pub get`, broken import): unresolved
  calls match only by their written identifier and never by `package`.

## `in` / `not_in` do not flag a value

They compare **constant** values. `EdgeInsets.all(padding)` with a variable
never matches; `EdgeInsets.all(kPad)` with `const kPad = 10` does. This is
deliberate: the linter's job is literals and named constants, not runtime
values.

## `inside` misses a wrapper

`inside` is syntactic. If the child is built by a helper method, the wrapper
is not its ancestor. `direct: true` additionally requires the node to be an
argument of the ancestor with nothing but argument lists, list literals and
parentheses in between; a `Builder(builder: (_) => Child())` closure breaks
directness on purpose.

## Slow first run

The CLI creates an analysis context and resolves the project: a few seconds
for a large Flutter app, then tens of milliseconds per file. `--changed` and
`--files` restrict what is resolved. The IDE plugin reuses the server's
resolution and adds only the matcher pass.
