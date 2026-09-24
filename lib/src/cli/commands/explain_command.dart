import 'dart:io';

import 'package:args/command_runner.dart';

import '../../config/config.dart';
import '../../config/errors.dart';
import '../../config/loader.dart';
import '../../match/compiled_rule.dart';
import '../../match/matcher_compiler.dart';
import '../../match/matchers/args_matcher.dart';
import '../../report/message_template.dart';
import '../exit_codes.dart';
import '../project_files.dart';

/// Prints a rule's contract so an agent can self-serve, or the rule language
/// reference (`--kinds`).
class ExplainCommand extends Command<int> {
  ExplainCommand({required this.out, required this.err}) {
    argParser
      ..addOption('config', help: 'Path to agent_lints.yaml.')
      ..addFlag('all', negatable: false, help: 'Explain every rule.')
      ..addFlag(
        'kinds',
        negatable: false,
        help: 'Print the match: node kinds and their keys.',
      );
  }

  final StringSink out;
  final StringSink err;

  @override
  String get name => 'explain';

  @override
  String get description =>
      'Show what a rule checks, its message, placeholders and examples.';

  @override
  String get invocation => 'agent_lints explain <rule> | --all | --kinds';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args['kinds'] == true) {
      out.write(kindsReference());
      return ExitCodes.ok;
    }
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
    if (args['all'] == true) {
      for (final rule in config.rules) {
        out.write(explainRule(rule, config));
        out.writeln();
      }
      return ExitCodes.ok;
    }
    if (args.rest.isEmpty) {
      err.writeln('usage: $invocation');
      err.writeln('rules: ${config.rules.map((r) => r.id).join(', ')}');
      return ExitCodes.usage;
    }
    var code = ExitCodes.ok;
    for (final id in args.rest) {
      final rule = config.rules.where((r) => r.id == id).firstOrNull;
      if (rule == null) {
        err.writeln(
          'agent_lints: no rule "$id". '
          'Rules: ${config.rules.map((r) => r.id).join(', ')}',
        );
        code = ExitCodes.usage;
        continue;
      }
      out.write(explainRule(rule, config));
    }
    return code;
  }

  static String explainRule(CompiledRule rule, AgentLintsConfig config) {
    final b = StringBuffer();
    b.writeln(
      '${rule.id}  (${rule.severity.name})'
      '${rule.description == null ? '' : '  ${rule.description}'}',
    );
    _line(b, 'kind', rule.kind);
    final scope = [
      if (rule.files.isEmpty)
        config.include.map((g) => g.pattern).join(', ')
      else
        rule.files.map((g) => g.pattern).join(', '),
      if (rule.exclude.isNotEmpty)
        'except ${rule.exclude.map((g) => g.pattern).join(', ')}',
    ].join('  ');
    _line(b, 'scope', scope);
    _line(b, 'matches', rule.matcher.describe());
    _line(b, 'message', rule.message.source.trim());
    if (rule.useInstead != null) _line(b, 'use_instead', rule.useInstead!);
    if (rule.hint != null) _line(b, 'hint', rule.hint!.source);
    if (rule.docs != null) _line(b, 'docs', rule.docs!);
    if (rule.vars.isNotEmpty) {
      _line(
        b,
        'vars',
        rule.vars.entries.map((e) => '${e.key}=${e.value}').join(', '),
      );
    }
    _line(b, 'ignore', '// ignore: agent_lints/${rule.id} -- <reason>');
    if (rule.examplesBad.isNotEmpty || rule.examplesGood.isNotEmpty) {
      final lines = [
        for (final e in rule.examplesBad) 'bad   ${_oneLine(e)}',
        for (final e in rule.examplesGood) 'good  ${_oneLine(e)}',
      ];
      _line(b, 'examples', lines.first);
      for (final l in lines.skip(1)) {
        b.writeln('${''.padRight(14)}$l');
      }
    }
    return b.toString();
  }

  static String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static void _line(StringBuffer b, String key, String value) {
    final lines = value.split('\n');
    b.writeln('  ${key.padRight(12)}${lines.first}');
    for (final l in lines.skip(1)) {
      b.writeln('${''.padRight(14)}$l');
    }
  }

  /// The rule language reference, generated from the node specs so it never
  /// drifts from the code.
  static String kindsReference() {
    final b = StringBuffer();
    b.writeln(
      'A rule has ONE node key (or a combinator) plus rule fields. The node\'s',
    );
    b.writeln(
      'attributes, args: and context keys sit next to it under the rule name.',
    );
    b.writeln();
    for (final spec in MatcherCompiler.specs.values) {
      b.writeln('${spec.key.padRight(13)}${spec.description}');
      b.writeln(
        '${''.padRight(13)}${spec.shorthandKey} (bare value), '
        '${spec.bodyKeys.where((k) => k != spec.shorthandKey).join(', ')}'
        '${spec.acceptsArgs ? ', args' : ''}',
      );
    }
    b.writeln();
    b.writeln(
      'args:        <param>: present | absent | value | [values] | { ${ArgConstraint.keys.join(', ')} }',
    );
    b.writeln(
      '             keys are parameter names, positional indexes, "*" (some) or "**" (all)',
    );
    b.writeln(
      'context:     ${MatcherCompiler.contextKeys.join(', ')}  (each takes a matcher map, e.g. { new: Column })',
    );
    b.writeln(
      'combine:     ${MatcherCompiler.combinatorKeys.join(', ')}  (not only nested)',
    );
    b.writeln(
      'patterns:    exact | glob (*, ?) | /regex/ | [any, of] | { not: pattern } | { style: snake_case } | { not_style: .. }',
    );
    b.writeln('rule fields: ${ConfigLoader.ruleFieldKeys.join(', ')}');
    b.writeln();
    b.writeln(
      'placeholders: ${MessageTemplate.common.join(', ')}, vars.*, values.*, args.*',
    );
    return b.toString();
  }
}
