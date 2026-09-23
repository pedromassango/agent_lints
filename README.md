# agent_lints

Agent-first custom lint for Dart and Flutter. Project rules live in one
`agent_lints.yaml`, written by humans or coding agents, and are checked from the
CLI, `dart analyze` and your IDE.

**Use it when** the conventions in your `AGENTS.md` / `CLAUDE.md` keep getting
ignored: "no `print`", "features must not import `package:http`", "widget files
stay under 100 lines", "colours come from `AppColors`". Each becomes a few lines
of YAML instead of a hand-written analyzer plugin.

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

  http_only_in_network:
    imports: { deny: ["package:http/**"], except: [lib/network/**] }
    message: "Only lib/network may talk HTTP."
```

```
$ dart run agent_lints
[error] no_print  lib/features/home/home_screen.dart:19:5
  found    print('home loaded')
  why      `print` ships to release logs. Use AppLog.d(...).
  suggest  AppLog.d('home loaded')
  ignore   // ignore: agent_lints/no_print -- <reason>

agent_lints: 1 error, 0 warnings, 0 info in 1 file  (14 files checked, 2.1s)
```

## Setup

1. Add the dependency (or install the CLI globally if your project pins an
   older `analyzer`):

   ```yaml
   dev_dependencies:
     agent_lints:
       git: https://github.com/pedromassango/agent_lints
   ```

2. Create the config and check the project:

   ```
   dart run agent_lints init
   dart run agent_lints
   ```

3. Show rules in the IDE and in `dart analyze` by enabling the plugin in the
   root `analysis_options.yaml`, then restart the analysis server:

   ```yaml
   plugins:
     agent_lints:
       git:
         url: https://github.com/pedromassango/agent_lints
         ref: main
   ```

4. Point your agents at it: `dart run agent_lints init --agents-md --claude-skill`.

## Documentation

Everything else is in [docs/index.md](docs/index.md): the
[rule language](docs/rule-language.md), [configuration](docs/configuration.md),
[CLI](docs/cli.md), [IDE plugin](docs/ide-plugin.md), [recipes](docs/recipes.md)
and [troubleshooting](docs/troubleshooting.md).

## License

MIT
