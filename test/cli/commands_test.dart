import 'dart:io';

import 'package:agent_lints/src/cli/commands/init_command.dart';
import 'package:agent_lints/src/cli/commands/test_command.dart';
import 'package:agent_lints/src/cli/runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_project.dart';

Future<(int, String, String)> run(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await AgentLintsRunner(out: out, err: err).run(args);
  return (code, out.toString(), err.toString());
}

void main() {
  group('explain', () {
    late TestProject project;
    setUp(() async {
      project = await TestProject.create(
        yaml: '''
version: 1
rules:
  no_print:
    severity: error
    description: Use the logger
    files: [lib/features/**]
    match: { call: { name: print, package: dart:core } }
    use_instead: AppLog.d
    suggest: "AppLog.d({{args.0}})"
    docs: docs/logging.md
    message: "no print. Use {{use_instead}}."
    examples:
      bad: ["void f() { print(1); }"]
      good: ["void f() {}"]
''',
        files: {},
      );
    });
    tearDown(() => project.dispose());

    test('prints the rule contract', () async {
      final (code, out, _) = await run([
        'explain',
        'no_print',
        '--config',
        p.join(project.root.path, 'agent_lints.yaml'),
      ]);
      expect(code, 0);
      expect(out, '''
no_print  (error)  Use the logger
  kind        match
  scope       lib/features/**
  matches     call name=print package=dart:core
  message     no print. Use {{use_instead}}.
  use_instead AppLog.d
  suggest     AppLog.d({{args.0}})
  docs        docs/logging.md
  ignore      // ignore: agent_lints/no_print -- <reason>
  examples    bad   void f() { print(1); }
              good  void f() {}
''');
    });

    test('unknown rule lists the available ones', () async {
      final (code, _, err) = await run([
        'explain',
        'nope',
        '--config',
        p.join(project.root.path, 'agent_lints.yaml'),
      ]);
      expect(code, 64);
      expect(err, contains('no rule "nope". Rules: no_print'));
    });

    test('--kinds prints the reference generated from the matchers', () async {
      final (code, out, _) = await run(['explain', '--kinds']);
      expect(code, 0);
      expect(out, contains('new       constructor calls'));
      expect(out, contains('keys: name, package, library, const, type, args'));
      expect(out, contains('args:     present, literal, value, in, not_in'));
      expect(out, contains('placeholders: rule, severity, file'));
    });
  });

  group('test command', () {
    test('bad examples must trigger, good ones must not', () async {
      final project = await TestProject.create(
        yaml: '''
version: 1
rules:
  no_print:
    files: [lib/features/**]
    match: { call: { name: print, package: dart:core } }
    message: no print
    examples:
      bad: ["void f() { print(1); }"]
      good: ["void f() {}"]
  taps:
    match: { new: { name: GestureDetector, args: { onTap: { present: true } } } }
    message: no taps
    examples:
      bad:
        - |
          import 'package:flutter/material.dart';
          final w = GestureDetector(onTap: () {});
      good:
        - |
          import 'package:flutter/material.dart';
          final w = GestureDetector(onTap: () {}); // wrongly listed as good
''',
        files: {},
      );
      try {
        final config = project.loadConfig();
        final reports = await TestCommand.runExamples(config, config.rules);
        expect(reports.map((r) => r.rule.id), ['no_print', 'taps']);
        expect(
          reports[0].failures,
          isEmpty,
          reason: 'file scoping must not apply',
        );
        expect(
          reports[1].failures.single,
          startsWith('good[0] triggered taps at line 2'),
        );
        expect(
          Directory(
            p.join(project.root.path, TestCommand.scratchDir),
          ).existsSync(),
          isFalse,
        );
      } finally {
        await project.dispose();
      }
    });
  });

  group('init', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('agent_lints_init_');
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: my_app\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
    });
    tearDown(() => dir.delete(recursive: true));

    test('writes a valid starter config and refuses to overwrite', () async {
      final (code, out, _) = await run(['init', '--dir', dir.path]);
      expect(code, 0);
      expect(out, contains('wrote agent_lints.yaml'));
      final yaml = File(
        p.join(dir.path, 'agent_lints.yaml'),
      ).readAsStringSync();
      expect(yaml, contains('package: [flutter, material_ui]'));
      expect(yaml, contains('package:my_app/ui/ui.dart'));
      expect(configErrors(yaml), isEmpty);
      final (again, out2, _) = await run(['init', '--dir', dir.path]);
      expect(again, 0);
      expect(out2, contains('already exists'));
    });

    test(
      '--plugin patches analysis_options.yaml, keeping existing content',
      () async {
        File(
          p.join(dir.path, 'analysis_options.yaml'),
        ).writeAsStringSync('include: package:lints/recommended.yaml\n');
        await run([
          'init',
          '--dir',
          dir.path,
          '--plugin',
          '--plugin-path',
          '../agent_lints',
        ]);
        final options = File(
          p.join(dir.path, 'analysis_options.yaml'),
        ).readAsStringSync();
        expect(options, contains('include: package:lints/recommended.yaml'));
        expect(options, contains('plugins:'));
        expect(options, contains('agent_lints:'));
        expect(options, contains('path: ../agent_lints'));
        expect(
          InitCommand.addPluginToAnalysisOptions(dir.path),
          contains('already enables'),
        );
      },
    );

    test(
      '--agents-md appends an idempotent block and --claude-skill writes the skill',
      () async {
        File(p.join(dir.path, 'CLAUDE.md')).writeAsStringSync('# My app\n');
        await run(['init', '--dir', dir.path, '--agents-md', '--claude-skill']);
        await run(['init', '--dir', dir.path, '--agents-md']);
        final claude = File(p.join(dir.path, 'CLAUDE.md')).readAsStringSync();
        expect(claude, startsWith('# My app'));
        expect(InitCommand.agentsBlockStart.allMatches(claude), hasLength(1));
        expect(File(p.join(dir.path, 'AGENTS.md')).existsSync(), isFalse);
        final skill = File(
          p.join(dir.path, '.claude/skills/agent-lints/SKILL.md'),
        );
        expect(skill.readAsStringSync(), startsWith('---\nname: agent-lints'));
      },
    );
  });
}
