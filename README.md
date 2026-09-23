# agent_lints

**Write project rules that agents can verify.**

[![ci](https://github.com/pedromassango/agent_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/pedromassango/agent_lints/actions/workflows/ci.yml)

agent_lints is an agent-first linter for Dart and Flutter. You write the
conventions of your project in `agent_lints.yaml`; when a human or an agent
breaks one, the error says what is wrong, what to write instead and where to
look. Rules run from the CLI, in `dart analyze` and in your IDE. Works with
your existing code, no rewrite required.

## Quickstart

Hand this to your agent:

```
Read https://github.com/pedromassango/agent_lints/blob/main/docs/getting-started.md and set up agent_lints in this project.
```

Then add to `AGENTS.md`:

```
After making changes, run `dart run agent_lints` and fix all errors.
```

## Example

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
```

## Built for agents

`dart analyze` tells an agent that something is wrong. agent_lints tells it
what your project wanted instead:

- **found**: the exact code that broke the rule.
- **why**: the rule in your words, with the replacement spelled out.
- **suggest**: a snippet it can paste.
- **ignore**: the one comment that silences it, so it does not invent another.

Errors in the YAML get the same treatment: every problem at once, with the
line, the path and a did-you-mean. An agent can add a rule, run
`dart run agent_lints validate` and `dart run agent_lints test`, and know it
works before anyone reads the code.

Rules match the resolved AST, so aliases, re-exports and `package:material_ui`
versus `package:flutter` are handled for you. Layering, naming, arguments,
ancestors, file size and design tokens are all a few lines of YAML.

## Usage

```yaml
# pubspec.yaml
dev_dependencies:
  agent_lints:
    git: https://github.com/pedromassango/agent_lints
```

```
dart run agent_lints init      # writes agent_lints.yaml
dart run agent_lints           # checks the project; exit 1 on violations
dart run agent_lints test      # runs each rule's bad/good examples
```

For the IDE and `dart analyze`, enable the plugin in the root
`analysis_options.yaml` and restart the analysis server:

```yaml
plugins:
  agent_lints:
    git:
      url: https://github.com/pedromassango/agent_lints
      ref: main
```

If your project pins an older `analyzer` (through `freezed`,
`json_serializable`, ...), skip the pubspec entry: the plugin resolves on its
own, and the CLI installs with
`dart pub global activate --source git https://github.com/pedromassango/agent_lints`.

## Documentation

- [Getting started](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [Rule language](docs/rule-language.md)
- [Sugar kinds: banned, imports, naming](docs/sugar-kinds.md)
- [Placeholders](docs/placeholders.md)
- [CLI](docs/cli.md)
- [IDE plugin](docs/ide-plugin.md)
- [Suppressing violations](docs/suppressing.md)
- [Agent workflow](docs/agent-workflow.md)
- [Recipes](docs/recipes.md)
- [Troubleshooting](docs/troubleshooting.md)
- [How it works](docs/how-it-works.md)

## FAQ

**Do agents need to be told about it?** Mostly not. With the plugin enabled a
rule at `severity: error` shows up in `dart analyze` and the IDE like any
other error, so an agent that checks its work sees the violation, reads the
message and fixes it, the same way it fixes a type error. The `AGENTS.md`
line above covers the rest.

**Why not `custom_lint`?** It is the right tool for rules you want to write in
Dart. agent_lints is for rules you would rather write in five lines of YAML,
with output an agent can act on without reading your code.

## License

MIT
