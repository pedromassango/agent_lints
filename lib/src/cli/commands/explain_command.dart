import 'dart:io';

import 'package:args/command_runner.dart';

import '../../config/config.dart';
import '../../config/errors.dart';
import '../../config/loader.dart';
import '../../match/compiled_rule.dart';
import '../../match/matcher_compiler.dart';
import '../../match/matchers/args_matcher.dart';
import '../../match/matchers/call_matcher.dart';
import '../../match/matchers/declaration_matchers.dart';
import '../../match/matchers/file_matcher.dart';
import '../../match/matchers/import_matcher.dart';
import '../../match/matchers/literal_matcher.dart';
import '../../match/matchers/new_matcher.dart';
import '../../match/matchers/ref_matcher.dart';
import '../../match/matchers/variable_matcher.dart';
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
    if (rule.suggest != null) _line(b, 'suggest', rule.suggest!.source);
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

  /// The `match:` reference, generated from the matcher classes so it never
  /// drifts from the code.
  static String kindsReference() {
    final b = StringBuffer();
    b.writeln(
      'match: takes ONE node key plus optional context keys, or a combinator.',
    );
    b.writeln();
    final kinds = <String, (String, List<String>)>{
      'new': ('constructor calls', NewMatcher.keys),
      'call': ('method and function calls', CallMatcher.keys),
      'ref': (
        'references that are not calls (Colors.red, tear-offs)',
        RefMatcher.keys,
      ),
      'import': ('import / export directives', ImportMatcher.keys),
      'class': (
        'class / mixin / enum / extension declarations',
        ClassMatcher.keys,
      ),
      'function': (
        'function / method / constructor declarations',
        FunctionMatcher.keys,
      ),
      'variable': ('top-level variables, fields, locals', VariableMatcher.keys),
      'literal': (
        'int / double / string / bool / null / list / map literals',
        LiteralMatcher.keys,
      ),
      'file': ('the file itself, reported at line 1', FileMatcher.keys),
    };
    for (final e in kinds.entries) {
      b.writeln('${e.key.padRight(10)}${e.value.$1}');
      b.writeln('${''.padRight(10)}keys: ${e.value.$2.join(', ')}');
    }
    b.writeln();
    b.writeln(
      'args:     ${ArgConstraint.keys.join(', ')}  (per parameter name, index, "*" or "**")',
    );
    b.writeln(
      'context:  inside, not_inside, contains, not_contains  (inside supports direct: true)',
    );
    b.writeln(
      'combine:  ${MatcherCompiler.combinatorKeys.join(', ')}  (not only nested)',
    );
    b.writeln(
      'patterns: exact | glob (*, ?) | /regex/ | [any, of] | {not: pattern}',
    );
    b.writeln();
    b.writeln(
      'placeholders: ${MessageTemplate.common.join(', ')}, vars.*, values.*, args.*',
    );
    return b.toString();
  }
}
