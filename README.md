# agent_lints

**Write project rules that agents can verify.**

[![pub package](https://img.shields.io/pub/v/agent_lints.svg)](https://pub.dev/packages/agent_lints)
[![ci](https://github.com/pedromassango/agent_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/pedromassango/agent_lints/actions/workflows/ci.yml)

agent_lints is an agent-first linter for Dart and Flutter. You write the
conventions of your project in `agent_lints.yaml`; when a human or an agent
breaks one, the error says what is wrong, what to write instead and where to
look. Rules run from the CLI, in `dart analyze` and in your IDE. Works with
your existing code, no rewrite required.

## Quickstart

Hand this to your agent:

```
Read https://github.com/pedromassango/agent_lints/blob/main/doc/getting-started.md and set up agent_lints in this project.
```

Then add to `AGENTS.md`:

```
After making changes, run `dart run agent_lints` and fix all errors.
```

## Example

A rule that bans `print` in favour of the project's logger. The `match:` block
says what to look for (a call to `print` from `dart:core`); the other fields
are what a violator gets told.

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

Running the linter on a project that calls `print` prints one block per
violation, with the code it found, the rule's message, a snippet to paste and
the comment that would silence it:

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
  agent_lints: ^0.1.0
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
  agent_lints: ^0.1.0
```

If your project pins an older `analyzer` (through `freezed`,
`json_serializable`, ...), skip the pubspec entry: the plugin resolves on its
own, and the CLI installs with `dart pub global activate agent_lints`.

## Documentation

- [Getting started](https://github.com/pedromassango/agent_lints/blob/main/doc/getting-started.md)
- [Configuration](https://github.com/pedromassango/agent_lints/blob/main/doc/configuration.md)
- [Rule language](https://github.com/pedromassango/agent_lints/blob/main/doc/rule-language.md)
- [Sugar kinds: banned, imports, naming](https://github.com/pedromassango/agent_lints/blob/main/doc/sugar-kinds.md)
- [Placeholders](https://github.com/pedromassango/agent_lints/blob/main/doc/placeholders.md)
- [CLI](https://github.com/pedromassango/agent_lints/blob/main/doc/cli.md)
- [IDE plugin](https://github.com/pedromassango/agent_lints/blob/main/doc/ide-plugin.md)
- [Suppressing violations](https://github.com/pedromassango/agent_lints/blob/main/doc/suppressing.md)
- [Agent workflow](https://github.com/pedromassango/agent_lints/blob/main/doc/agent-workflow.md)
- [Recipes](https://github.com/pedromassango/agent_lints/blob/main/doc/recipes.md)
- [Troubleshooting](https://github.com/pedromassango/agent_lints/blob/main/doc/troubleshooting.md)
- [How it works](https://github.com/pedromassango/agent_lints/blob/main/doc/how-it-works.md)
- [Releasing](https://github.com/pedromassango/agent_lints/blob/main/doc/releasing.md)

## FAQ

**Do agents need to be told about it?** Mostly not. With the plugin enabled a
rule at `severity: error` shows up in `dart analyze` and the IDE like any
other error, so an agent that checks its work sees the violation, reads the
message and fixes it, the same way it fixes a type error. The `AGENTS.md`
line above covers the rest.

**Why this over a skill or an `AGENTS.md` rule?** Instructions are advice.
An agent can skip them, forget them halfway through a long task, or decide the
case at hand is an exception. A lint rule is checked by a program on the code
that was actually written, every time, and reported as an error the agent has
to clear before its work is done. Keep the skill for the why and the taste;
put the must-haves in `agent_lints.yaml`.

**Why not `custom_lint`?** It is the right tool for rules you want to write in
Dart. agent_lints is for rules you would rather write in five lines of YAML,
with output an agent can act on without reading your code.

## License

MIT
