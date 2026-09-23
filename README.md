# agent_lints

[![ci](https://github.com/pedromassango/agent_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/pedromassango/agent_lints/actions/workflows/ci.yml)

agent_lints turns the conventions in your `AGENTS.md` into lint rules. Rules are
written in YAML, by humans or coding agents, and enforced from the CLI,
`dart analyze` and your IDE. See the [documentation](docs/index.md).

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

Rules match the resolved AST, so imports, prefixes and `package:material_ui`
versus `package:flutter` are handled for you. Layering (`imports`), naming
(`naming`), arguments, ancestors, file size and more are covered in the
[rule language](docs/rule-language.md); ready-made rules are in the
[recipes](docs/recipes.md).

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

To see rules in the IDE and in `dart analyze`, enable the plugin in the root
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

## FAQ

**How do agents use it?** `dart run agent_lints init --agents-md --claude-skill`
adds the loop to your agent instructions: run, fix from the `why` / `suggest`
lines, add rules in YAML, prove them with `test`. See
[agent workflow](docs/agent-workflow.md).

**Why not `custom_lint`?** It is a great way to write rules in Dart. agent_lints
is for rules you would rather write in five lines of YAML, with output an
agent can act on without reading your code.

## License

MIT
