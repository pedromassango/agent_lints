import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config.dart';
import '../../config/errors.dart';
import '../../config/loader.dart';
import '../../engine/project_checker.dart';
import '../../report/formatters/agent_formatter.dart';
import '../../report/formatters/formatter.dart';
import '../../report/formatters/human_formatter.dart';
import '../../report/formatters/json_formatter.dart';
import '../../report/formatters/sarif_formatter.dart';
import '../../report/run_result.dart';
import '../exit_codes.dart';
import '../project_files.dart';

class CheckCommand extends Command<int> {
  CheckCommand({required this.out, required this.err}) {
    argParser
      ..addOption(
        'format',
        allowed: ['agent', 'human', 'json'],
        help:
            'Output format. Defaults to human on a terminal, agent otherwise.',
      )
      ..addOption('config', help: 'Path to agent_lints.yaml.')
      ..addMultiOption(
        'files',
        help: 'Only check these files (project-relative or absolute).',
      )
      ..addMultiOption('rule', help: 'Only run these rule ids.')
      ..addFlag(
        'changed',
        negatable: false,
        help: 'Only check files changed or added since the last git commit.',
      )
      ..addFlag(
        'show-suppressed',
        negatable: false,
        help: 'Also list violations silenced by // ignore comments.',
      )
      ..addOption(
        'fail-on',
        allowed: ['error', 'warning', 'info', 'none'],
        help: 'Exit 1 at or above this severity. Overrides the config.',
      );
  }

  final StringSink out;
  final StringSink err;

  @override
  String get name => 'check';

  @override
  String get description => 'Check the project against agent_lints.yaml.';

  @override
  List<String> get aliases => const ['lint'];

  @override
  Future<int> run() async {
    final args = argResults!;
    final formatName =
        args['format'] as String? ?? (stdout.hasTerminal ? 'human' : 'agent');
    Formatter formatter = switch (formatName) {
      'json' => JsonFormatter(),
      'human' => HumanFormatter(),
      _ => AgentFormatter(),
    };
    final project = Project.find(configPath: args['config'] as String?);
    if (project == null) {
      err.writeln(
        'agent_lints: no agent_lints.yaml found. '
        'Run `dart run agent_lints init` to create one.',
      );
      return ExitCodes.config;
    }
    final stopwatch = Stopwatch()..start();
    final warnings = <ConfigError>[];
    final AgentLintsConfig config;
    try {
      config = ConfigLoader(warnings: warnings.add).load(
        content: File(project.configPath).readAsStringSync(),
        configPath: project.configPath,
        rootPath: project.rootPath,
        packageName: project.packageName,
      );
    } on ConfigException catch (e) {
      out.write(
        formatter.format(
          RunResult(
            violations: const [],
            filesChecked: 0,
            duration: stopwatch.elapsed,
            failOn: Severity.warning,
            configPath: project.configPath,
            configErrors: e.errors,
          ),
        ),
      );
      return ExitCodes.config;
    }
    if (formatName == 'sarif') formatter = SarifFormatter(rules: config.rules);
    final failOnArg = args['fail-on'] as String?;
    final failOn = failOnArg == null
        ? config.failOn
        : failOnArg == 'none'
        ? Severity.off
        : Severity.byName[failOnArg]!;
    final onlyRules = (args['rule'] as List<String>).toSet();
    final effective = onlyRules.isEmpty
        ? config
        : AgentLintsConfig(
            rootPath: config.rootPath,
            configPath: config.configPath,
            packageName: config.packageName,
            include: config.include,
            exclude: config.exclude,
            failOn: config.failOn,
            requireIgnoreReason: config.requireIgnoreReason,
            docs: config.docs,
            values: config.values,
            rules: config.rules.where((r) => onlyRules.contains(r.id)).toList(),
          );

    final only = (args['files'] as List<String>)
        .map((f) => p.normalize(p.absolute(p.join(project.rootPath, f))))
        .toSet();
    if (args['changed'] == true) {
      final changed = await _gitChangedFiles(project.rootPath);
      if (changed == null) {
        err.writeln('agent_lints: --changed needs a git repository.');
        return ExitCodes.usage;
      }
      only.addAll(changed);
      if (only.isEmpty) {
        out.write(
          formatter.format(
            RunResult(
              violations: const [],
              filesChecked: 0,
              duration: stopwatch.elapsed,
              failOn: failOn,
              configPath: project.configPath,
            ),
          ),
        );
        return ExitCodes.ok;
      }
    }
    final RunResult result;
    try {
      result = await ProjectChecker(
        effective,
      ).run(onlyFiles: only, failOn: failOn, warnings: warnings);
    } on Object catch (e) {
      err.writeln('agent_lints: analysis failed: $e');
      return ExitCodes.analysis;
    }
    out.write(formatter.format(result));
    return result.exitCode;
  }

  /// Modified, staged and untracked `.dart` files, absolute. Null outside git.
  static Future<Set<String>?> _gitChangedFiles(String root) async {
    Future<List<String>> git(List<String> a) async {
      final r = await Process.run('git', a, workingDirectory: root);
      if (r.exitCode != 0) throw ProcessException('git', a, r.stderr as String);
      return (r.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    try {
      final top = (await git(['rev-parse', '--show-toplevel'])).single;
      final files = [
        ...await git(['diff', '--name-only', 'HEAD']),
        ...await git(['ls-files', '--others', '--exclude-standard']),
      ];
      return files
          .where((f) => f.endsWith('.dart'))
          .map((f) => p.normalize(p.join(top, f)))
          .toSet();
    } on ProcessException {
      return null;
    }
  }
}
