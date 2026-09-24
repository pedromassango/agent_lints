import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../exit_codes.dart';
import '../project_files.dart';
import '../version.dart';

/// Scaffolds `agent_lints.yaml` and, on request, the plugin entry in
/// `analysis_options.yaml`, an AGENTS.md block and a Claude Code skill.
class InitCommand extends Command<int> {
  InitCommand({required this.out, required this.err}) {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing agent_lints.yaml.',
      )
      ..addFlag(
        'plugin',
        negatable: false,
        help: 'Add `plugins: agent_lints` to the root analysis_options.yaml.',
      )
      ..addOption(
        'plugin-path',
        help: 'Use a local path for the plugin instead of the pub version.',
      )
      ..addFlag(
        'agents-md',
        negatable: false,
        help: 'Append a short agent_lints section to AGENTS.md (or CLAUDE.md).',
      )
      ..addFlag(
        'claude-skill',
        negatable: false,
        help: 'Write .claude/skills/agent-lints/SKILL.md.',
      )
      ..addOption(
        'dir',
        help: 'Project directory (defaults to the current one).',
      );
  }

  final StringSink out;
  final StringSink err;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Create a starter agent_lints.yaml in this project.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final root = p.absolute(args['dir'] as String? ?? Directory.current.path);
    if (!File(p.join(root, 'pubspec.yaml')).existsSync()) {
      err.writeln(
        'agent_lints: run init from the directory that holds pubspec.yaml.',
      );
      return ExitCodes.usage;
    }
    final packageName = Project.readPackageName(root) ?? 'app';
    final usesFlutter = _usesFlutter(root);

    final configFile = File(p.join(root, Project.configFileName));
    if (configFile.existsSync() && args['force'] != true) {
      out.writeln(
        '${Project.configFileName} already exists (use --force to overwrite).',
      );
    } else {
      configFile.writeAsStringSync(
        starterYaml(packageName: packageName, usesFlutter: usesFlutter),
      );
      out.writeln('wrote ${Project.configFileName}');
    }

    if (args['plugin'] == true) {
      final msg = addPluginToAnalysisOptions(
        root,
        pluginPath: args['plugin-path'] as String?,
      );
      out.writeln(msg);
    }
    if (args['agents-md'] == true) {
      out.writeln(appendAgentsBlock(root));
    }
    if (args['claude-skill'] == true) {
      final file = File(
        p.join(root, '.claude', 'skills', 'agent-lints', 'SKILL.md'),
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(skillMarkdown);
      out.writeln('wrote ${p.relative(file.path, from: root)}');
    }
    out.writeln('next: dart run agent_lints validate && dart run agent_lints');
    return ExitCodes.ok;
  }

  static bool _usesFlutter(String root) {
    try {
      final doc = loadYaml(
        File(p.join(root, 'pubspec.yaml')).readAsStringSync(),
      );
      if (doc is YamlMap) {
        final deps = doc['dependencies'];
        return deps is YamlMap && deps.containsKey('flutter');
      }
    } on YamlException {
      return false;
    }
    return false;
  }

  static String starterYaml({
    required String packageName,
    required bool usesFlutter,
  }) {
    final pkg = usesFlutter ? 'flutter' : 'project';
    return '''
# agent_lints.yaml — project rules for humans and coding agents.
# Run:  dart run agent_lints            (check)
#       dart run agent_lints validate   (check this file only)
#       dart run agent_lints explain <rule> | --kinds
#       dart run agent_lints test       (run each rule's examples)
version: 2
include: [lib/**]
fail_on: warning

# Named lists you can reference as \$name in rules ({{allowed}} / {{closest}}).
values:
  spacing: [4, 8, 12, 16, 24, 32]

rules:
  no_print:
    severity: error
    description: Use the project logger instead of print
    call: print
    from: dart:core
    use_instead: AppLog.d(...)
    suggest: "AppLog.d({{args.0}})"
    message: "`print` ships to release logs. Use {{use_instead}}."
    examples:
      bad: ["void f() { print('x'); }"]
      good: ["void f() { debugPrint('x'); } void debugPrint(String s) {}"]

  # --- Starters (uncomment and adapt) -----------------------------------
  #
  # no_gesture_detector_for_taps:
  #   constructor: GestureDetector
  #   from: $pkg
  #   args: { onTap: present, onPanUpdate: absent }
  #   use_instead: InkWell (ripple + semantics)
  #   message: "GestureDetector with only onTap has no ripple or semantics. Use {{use_instead}}."
  #
  # features_no_material:              # layering
  #   severity: error
  #   deny_imports: [package:flutter/material.dart]
  #   include: [lib/features/**]
  #   replace_with: package:$packageName/ui/ui.dart
  #   message: "{{uri}} must not be imported from feature code. Import {{use_instead}}."
  #
  # http_only_in_network:
  #   deny_imports: ["package:http/**", "package:dio/**"]
  #   exclude: [lib/network/**]
  #   message: "Only lib/network may talk HTTP."
  #
  # no_setstate_in_build:
  #   call: State.setState
  #   inside: { function: build }
  #   message: "setState inside build() causes rebuild loops."
  #
  # screens_named_screen:              # naming
  #   class: { extends: StatefulWidget }
  #   name: { not: "*Screen" }
  #   include: [lib/screens/**]
  #   message: "{{name}} under lib/screens must end with Screen."
  #
  # spacing_on_scale:                  # design tokens
  #   constructor: [EdgeInsets.all, EdgeInsets.symmetric, EdgeInsets.only]
  #   args: { "*": { literal: num, not_in: \$spacing } }
  #   message: "{{value}} is off the spacing scale. Allowed: {{allowed}}. Closest: {{closest}}."
  #
  # small_widget_files:
  #   file: { max_code_lines: 100 }
  #   contains: { class: { extends: Widget } }
  #   message: "{{code_lines}} lines of code in a widget file; the limit is 100."
  #
  # no_hardcoded_urls:
  #   literal: string
  #   source: "/^'https?:/"
  #   exclude: [lib/config/**]
  #   message: "URL literal {{found}} belongs in lib/config/endpoints.dart."
''';
  }

  /// Adds `plugins: agent_lints: ...` to the root analysis_options.yaml,
  /// creating the file when missing. Returns a one-line status.
  static String addPluginToAnalysisOptions(String root, {String? pluginPath}) {
    final file = File(p.join(root, 'analysis_options.yaml'));
    final content = file.existsSync() ? file.readAsStringSync() : '';
    final editor = YamlEditor(content.trim().isEmpty ? '{}' : content);
    final doc = loadYaml(content);
    final hasPlugins = doc is YamlMap && doc['plugins'] is YamlMap;
    final hasOurs =
        hasPlugins && (doc['plugins'] as YamlMap).containsKey('agent_lints');
    final Object spec = pluginPath != null
        ? {'path': pluginPath}
        : '^${packageVersion.replaceFirst('-dev', '')}';
    if (hasOurs) {
      return 'analysis_options.yaml already enables the agent_lints plugin';
    }
    if (hasPlugins) {
      editor.update(['plugins', 'agent_lints'], spec);
    } else {
      editor.update(['plugins'], {'agent_lints': spec});
    }
    file.writeAsStringSync(editor.toString());
    final nested = Directory(root)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where(
          (f) =>
              p.basename(f.path) == 'analysis_options.yaml' &&
              f.path != file.path &&
              !f.path.contains('${p.separator}.dart_tool${p.separator}') &&
              !f.path.contains('${p.separator}build${p.separator}'),
        )
        .length;
    return 'enabled the agent_lints plugin in analysis_options.yaml '
        '(restart the analysis server)'
        '${nested == 0 ? '' : '. Note: $nested nested analysis_options.yaml found; '
                  'plugins only work from the root file.'}';
  }

  static const agentsBlockStart = '<!-- agent_lints:start -->';
  static const agentsBlockEnd = '<!-- agent_lints:end -->';

  static const agentsBlock =
      '''
$agentsBlockStart
## Project lint rules (agent_lints)

Project conventions are enforced by `agent_lints.yaml`. Before finishing a
change run `dart run agent_lints` and fix every reported block; each one names
the rule, why it fired, and what to write instead. To add a convention, add a
rule to `agent_lints.yaml` (`dart run agent_lints explain --kinds` prints the
rule language), then run `dart run agent_lints validate` and
`dart run agent_lints test`. Suppress a hit only with a reason:
`// ignore: agent_lints/<rule> -- why`.
$agentsBlockEnd
''';

  /// Appends [agentsBlock] to AGENTS.md and/or CLAUDE.md, replacing an older
  /// block in place. Creates AGENTS.md when neither exists.
  static String appendAgentsBlock(String root) {
    final candidates = [
      'AGENTS.md',
      'CLAUDE.md',
    ].map((n) => File(p.join(root, n))).where((f) => f.existsSync()).toList();
    if (candidates.isEmpty) candidates.add(File(p.join(root, 'AGENTS.md')));
    final touched = <String>[];
    for (final file in candidates) {
      final existing = file.existsSync() ? file.readAsStringSync() : '';
      final start = existing.indexOf(agentsBlockStart);
      final end = existing.indexOf(agentsBlockEnd);
      final String updated;
      if (start != -1 && end != -1) {
        updated = existing.replaceRange(
          start,
          end + agentsBlockEnd.length,
          agentsBlock.trim(),
        );
      } else {
        updated = '${existing.trimRight()}\n\n$agentsBlock';
      }
      file.writeAsStringSync(updated.trimLeft());
      touched.add(p.basename(file.path));
    }
    return 'updated ${touched.join(' and ')}';
  }

  static const skillMarkdown = '''
---
name: agent-lints
description: Check Dart/Flutter code against this project's rules in agent_lints.yaml. Run after editing Dart files and before committing; also use to add or change a project rule.
---

# agent_lints

## Check your work

```
dart run agent_lints
```

Each block is one violation:

```
[error] no_print  lib/features/home/home_screen.dart:19:5
  found    print('home loaded')
  why      `print` ships to release logs. Use AppLog.d(...).
  suggest  AppLog.d('home loaded')
  ignore   // ignore: agent_lints/no_print -- <reason>
```

Fix the code as `why` / `suggest` say, then re-run until exit code 0. Only
suppress with the printed `ignore` comment and a real reason.

Useful flags: `--changed` (files touched since the last commit),
`--files a.dart`, `--rule no_print`, `--format json`.

## Add or change a rule

1. `dart run agent_lints explain --kinds` prints the rule language.
2. Edit `agent_lints.yaml`. A rule is one node key (`use`, `new`, `call`,
   `class`, `deny_imports`, `file`, ...) with its attributes, `args:` and
   context (`parent`, `inside`, `contains`, `except`) as sibling lines, plus
   `message:` (with `{{placeholders}}`), `severity`, `include`, `exclude`,
   `use_instead`, `suggest`, `docs` and `examples: { bad: [..], good: [..] }`.
3. `dart run agent_lints validate` reports every YAML problem with a hint.
4. `dart run agent_lints test` runs the rule's examples: bad snippets must
   trigger it, good ones must not.
5. `dart run agent_lints explain <rule>` shows the compiled contract.
''';
}
