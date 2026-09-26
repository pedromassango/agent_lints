import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config.dart';
import '../../config/errors.dart';
import '../../config/loader.dart';
import '../../engine/project_checker.dart';
import '../../match/compiled_rule.dart';
import '../exit_codes.dart';
import '../project_files.dart';

/// Runs each rule's `examples: { bad: [...], good: [...] }` snippets, so an
/// agent that just wrote a rule can prove it matches what it meant.
class TestCommand extends Command<int> {
  TestCommand({required this.out, required this.err}) {
    argParser
      ..addOption('config', help: 'Path to agent_lints.yaml.')
      ..addMultiOption('rule', help: 'Only test these rule ids.');
  }

  final StringSink out;
  final StringSink err;

  static const scratchDir = 'agent_lints_examples_tmp';

  @override
  String get name => 'test';

  @override
  String get description =>
      "Check every rule's examples: bad snippets must trigger it, good ones must not.";

  @override
  Future<int> run() async {
    final args = argResults!;
    final project = Project.find(configPath: args['config'] as String?);
    if (project == null) {
      err.writeln('agent_lints: no agent_lints.yaml found.');
      return ExitCodes.config;
    }
    final AgentLintsConfig config;
    try {
      config = ConfigLoader().load(
        content: File(project.configPath).readAsStringSync(),
        configPath: project.configPath,
        rootPath: project.rootPath,
        packageName: project.packageName,
      );
    } on ConfigException catch (e) {
      for (final error in e.errors) {
        out.writeln('[config] ${error.format()}');
      }
      return ExitCodes.config;
    }
    final only = (args['rule'] as List<String>).toSet();
    final rules = config.rules
        .where((r) => only.isEmpty || only.contains(r.id))
        .where((r) => r.examplesBad.isNotEmpty || r.examplesGood.isNotEmpty)
        .toList();
    if (rules.isEmpty) {
      out.writeln(
        'No rule has examples. Add `examples: { bad: [...], good: [...] }` to a rule.',
      );
      return ExitCodes.ok;
    }
    final report = await runExamples(config, rules);
    var failures = 0;
    for (final r in report) {
      final ok = r.failures.isEmpty;
      if (!ok) failures++;
      out.writeln(
        '${ok ? 'PASS' : 'FAIL'}  ${r.rule.id}  '
        '(${r.rule.examplesBad.length} bad, ${r.rule.examplesGood.length} good)',
      );
      for (final f in r.failures) {
        out.writeln('      $f');
      }
    }
    out.writeln();
    out.writeln(
      '${report.length - failures} of ${report.length} rules pass their examples.',
    );
    return failures == 0 ? ExitCodes.ok : ExitCodes.violations;
  }

  /// Writes the snippets into a scratch folder inside the project so they
  /// resolve against its dependencies, checks them, then deletes the folder.
  static Future<List<ExampleReport>> runExamples(
    AgentLintsConfig config,
    List<CompiledRule> rules,
  ) async {
    final dir = Directory(p.join(config.rootPath, scratchDir));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync();
    try {
      final files = <String, (CompiledRule, bool, int)>{};
      for (final rule in rules) {
        for (var i = 0; i < rule.examplesBad.length; i++) {
          final path = p.join(dir.path, '${rule.id}_bad_$i.dart');
          File(path).writeAsStringSync(rule.examplesBad[i]);
          files[p.normalize(path)] = (rule, true, i);
        }
        for (var i = 0; i < rule.examplesGood.length; i++) {
          final path = p.join(dir.path, '${rule.id}_good_$i.dart');
          File(path).writeAsStringSync(rule.examplesGood[i]);
          files[p.normalize(path)] = (rule, false, i);
        }
      }
      // Examples ignore file scoping: the rule must match on its own terms.
      final testConfig = AgentLintsConfig(
        rootPath: config.rootPath,
        configPath: config.configPath,
        packageName: config.packageName,
        files: [compileGlob('$scratchDir/**')],
        exclude: const [],
        failOn: config.failOn,
        requireIgnoreReason: config.requireIgnoreReason,
        docs: config.docs,
        values: config.values,
        rules: rules
            .map((r) => r.copyWith(files: const [], exclude: const []))
            .toList(),
      );
      final result = await ProjectChecker(
        testConfig,
      ).run(onlyFiles: files.keys.toSet());
      final reports = {for (final r in rules) r.id: ExampleReport(r)};
      for (final entry in files.entries) {
        final (rule, isBad, index) = entry.value;
        final hits = result.violations
            .where(
              (v) => p.normalize(v.path) == entry.key && v.ruleId == rule.id,
            )
            .toList();
        final others = result.violations
            .where(
              (v) => p.normalize(v.path) == entry.key && v.ruleId != rule.id,
            )
            .map((v) => v.ruleId)
            .toSet();
        if (isBad && hits.isEmpty) {
          reports[rule.id]!.failures.add(
            'bad[$index] did not trigger ${rule.id}'
            '${others.isEmpty ? '' : ' (it triggered: ${others.join(', ')})'}: '
            '${_oneLine(rule.examplesBad[index])}',
          );
        }
        if (!isBad && hits.isNotEmpty) {
          reports[rule.id]!.failures.add(
            'good[$index] triggered ${rule.id} at line ${hits.first.line}: '
            '${_oneLine(rule.examplesGood[index])}',
          );
        }
      }
      return reports.values.toList();
    } finally {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  }

  static String _oneLine(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 80 ? '${t.substring(0, 79)}…' : t;
  }
}

class ExampleReport {
  ExampleReport(this.rule);
  final CompiledRule rule;
  final List<String> failures = [];
}
