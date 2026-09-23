import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../config/config.dart';
import '../engine/engine.dart';
import '../report/violation.dart';
import 'config_cache.dart';

/// The single analyzer rule that runs every rule from `agent_lints.yaml`.
///
/// Each YAML rule id becomes a [LintCode] so `// ignore: agent_lints/<id>`
/// and per-code severity overrides in `analysis_options.yaml` work.
class AgentLintsRule extends MultiAnalysisRule {
  AgentLintsRule({ConfigCache? cache})
    : cache = cache ?? ConfigCache(),
      super(
        name: 'agent_lints',
        description: 'Project rules defined in agent_lints.yaml.',
      );

  final ConfigCache cache;

  /// Reported once per file when the YAML is invalid.
  static const configErrorCode = LintCode(
    'agent_lints_config_error',
    'agent_lints.yaml is invalid: {0}',
    correctionMessage: 'Run `dart run agent_lints validate` for all errors.',
    severity: DiagnosticSeverity.ERROR,
  );

  final Map<String, LintCode> _codes = {};

  LintCode codeFor(String ruleId, Severity severity) {
    return _codes.putIfAbsent(
      ruleId,
      () => LintCode(
        ruleId,
        '{0}',
        correctionMessage: '{1}',
        uniqueName: 'agent_lints.$ruleId',
        severity: switch (severity) {
          Severity.error => DiagnosticSeverity.ERROR,
          Severity.warning => DiagnosticSeverity.WARNING,
          _ => DiagnosticSeverity.INFO,
        },
      ),
    );
  }

  bool _discovered = false;

  /// Loads configs reachable from the working directory so every rule id has
  /// a code (with its severity) before the server analyzes the first file.
  void discoverConfigs([String? fromDir]) {
    _discovered = true;
    for (final project in cache.discover(fromDir ?? Directory.current.path)) {
      final config = project.config;
      if (config != null) warmUp(config);
    }
  }

  @override
  List<DiagnosticCode> get diagnosticCodes {
    if (!_discovered) discoverConfigs();
    return [configErrorCode, ..._codes.values];
  }

  /// Pre-creates codes for every rule so the server knows their severity
  /// before the first file is analyzed.
  void warmUp(AgentLintsConfig config) {
    for (final rule in config.rules) {
      codeFor(rule.id, rule.severity);
    }
    codeFor(Engine.unusedIgnoreRule, Severity.info);
    codeFor(Engine.ignoreWithoutReasonRule, Severity.warning);
  }

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = context.definingUnit.file.path;
    final project = cache.forFile(path);
    if (project == null) return;
    final engine = project.engine;
    if (engine == null) {
      registry.addCompilationUnit(this, _ConfigErrorVisitor(this, project));
      return;
    }
    warmUp(project.config!);
    registry.addCompilationUnit(this, _UnitVisitor(this, engine, context));
  }
}

/// Runs the engine over the whole unit once and reports each violation.
class _UnitVisitor extends SimpleAstVisitor<void> {
  _UnitVisitor(this.rule, this.engine, this.context);

  final AgentLintsRule rule;
  final Engine engine;
  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final unit = context.currentUnit ?? context.definingUnit;
    final violations = engine.analyzeCompilationUnit(
      unit: node,
      content: unit.content,
      path: unit.file.path,
    );
    for (final v in violations) {
      _report(v);
    }
  }

  void _report(Violation v) {
    rule.reportAtOffset(
      v.offset,
      v.length,
      diagnosticCode: rule.codeFor(v.ruleId, v.severity),
      arguments: [v.shortMessage, _correction(v)],
    );
  }

  static String _correction(Violation v) {
    final parts = <String>[
      if (v.useInstead != null) 'Use ${v.useInstead}.',
      if (v.suggest != null && v.suggest!.isNotEmpty) 'Suggest: ${v.suggest}.',
      if (v.docs != null) 'See ${v.docs}.',
      'Explain: dart run agent_lints explain ${v.ruleId}',
    ];
    return parts.join(' ');
  }
}

class _ConfigErrorVisitor extends SimpleAstVisitor<void> {
  _ConfigErrorVisitor(this.rule, this.project);

  final AgentLintsRule rule;
  final LoadedProject project;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final first = project.errors.first;
    rule.reportAtOffset(
      0,
      0,
      diagnosticCode: AgentLintsRule.configErrorCode,
      arguments: [first.format()],
    );
  }
}
