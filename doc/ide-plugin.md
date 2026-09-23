---
title: IDE plugin
description: Run agent_lints inside dart analyze, flutter analyze and your editor.
---

# IDE plugin

agent_lints ships an analyzer plugin built on the official
`analysis_server_plugin` API (Dart 3.10+). The same YAML, the same engine, the
same violations, shown as regular diagnostics.

## Enable

In the **root** `analysis_options.yaml` (plugins cannot be enabled from nested
options files):

```yaml
plugins:
  agent_lints: ^0.1.0
```

Alternatives:

```yaml
plugins:
  agent_lints:
    git: { url: https://github.com/pedromassango/agent_lints, ref: main }  # unreleased main
  agent_lints:
    path: ../agent_lints         # a local checkout while developing agent_lints itself
```

Then restart the analysis server:

- VS Code: command palette, "Dart: Restart Analysis Server".
- Android Studio / IntelliJ: the restart icon in the Dart Analysis tool window,
  or reopen the project.
- Command line: nothing to do, `dart analyze` starts fresh.

The analysis server generates a small package that depends on the plugin,
resolves it with pub, and compiles it. The first run takes a few seconds, and
needs network access for a git or pub source.

The `plugins:` entry does **not** require agent_lints in `pubspec.yaml`. That
matters when a code generator in your project pins an older `analyzer` than
agent_lints needs: the plugin still works. See
[Troubleshooting](troubleshooting.md#analyzer-version-conflict).

## What you get

- Every rule id is a diagnostic code. `dart analyze --format=machine` prints it
  in upper case (`NO_RAW_COLORS`); `--format=json` keeps `no_raw_colors`.
- Severity comes from the rule's `severity` in `agent_lints.yaml`.
- The tooltip shows the whole message on one line, then a correction built from
  `use_instead`, `suggest`, `docs` and
  ``Run explain to learn more: `dart run agent_lints explain <rule>` ``.
- Declarations (`class`, `function`, `variable`, `naming`) are underlined at
  their name; `file` rules at the first line.
- `// ignore: agent_lints/<rule>` and `// ignore_for_file: agent_lints/<rule>`
  are honoured by the server itself. The `agent_lints/` prefix is required
  here (the CLI also accepts the bare id).
- An invalid `agent_lints.yaml` is reported once per file as
  `agent_lints_config_error` with the first problem; run
  `dart run agent_lints validate` for all of them.

## Override a severity from analysis_options.yaml

```yaml
plugins:
  agent_lints:
    version: ^0.1.0
    diagnostics:
      small_widget_files: error   # error | warning | info | ignore
```

## How the plugin finds your config

Each analyzed file uses the nearest `agent_lints.yaml` above it, so a
monorepo can have one config per package. The file is re-read when its
modification time changes; a file is re-analyzed when you edit it (or after a
server restart), so a YAML edit shows up on the next change to a Dart file.

At start-up the plugin also loads every config found by walking up from the
analysis server's working directory and up to four levels below it (skipping
`build`, `.dart_tool`, platform folders and hidden directories). This lets it
declare every rule id with its severity before the first file is analyzed;
without it the analysis server would show the first file's diagnostics as
INFO.

## Pin the plugin version

With `ref: main` the analysis server checks out `main` once and caches it. To
pick up a newer agent_lints, change `ref` to a commit or tag: any edit to the
`plugins:` section makes the server resolve and build again.

```yaml
      ref: 99adb72     # or a tag such as v0.1.0
```

## Performance

The plugin reuses the analysis server's resolved units, so its cost is the
matcher pass only. Rules subscribe to the node kinds they need; a project with
dozens of rules still runs one visitor per file.
