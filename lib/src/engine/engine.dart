import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../config/config.dart';
import '../match/compiled_rule.dart';
import '../match/match_context.dart';
import '../match/matcher.dart';
import '../match/node_kind.dart';
import '../report/violation.dart';
import 'kind_visitor.dart';

/// Runs every enabled rule over resolved compilation units.
class Engine {
  Engine(this.config) {
    for (final rule in config.rules) {
      if (!rule.enabled) continue;
      for (final kind in rule.matcher.anchors) {
        _byKind.putIfAbsent(kind, () => []).add(rule);
      }
    }
  }

  final AgentLintsConfig config;
  final Map<NodeKind, List<CompiledRule>> _byKind = {};

  /// Node kinds at least one rule listens to.
  Set<NodeKind> get activeKinds => _byKind.keys.toSet();

  List<Violation> analyzeUnit(
    ResolvedUnitResult result, {
    String? relativePath,
  }) {
    final rel = relativePath ?? config.relativePath(result.path) ?? result.path;
    final ctx = MatchContext(
      result: result,
      relativePath: rel,
      rootPath: config.rootPath,
      packageName: config.packageName,
      values: config.values,
    );
    final active = <NodeKind, List<CompiledRule>>{};
    for (final e in _byKind.entries) {
      final rules = e.value.where((r) => r.appliesTo(rel)).toList();
      if (rules.isNotEmpty) active[e.key] = rules;
    }
    if (active.isEmpty) return const [];
    final violations = <Violation>[];
    final seen = <String>{};
    result.unit.accept(
      KindVisitor((kind, node) {
        final rules = active[kind];
        if (rules == null) return;
        for (final rule in rules) {
          final r = rule.matcher.match(node, ctx);
          if (r == null) continue;
          final key = '${rule.id}@${r.node.offset}';
          if (!seen.add(key)) continue;
          violations.add(buildViolation(rule, r, ctx));
        }
      }),
    );
    violations.sort((a, b) => a.offset.compareTo(b.offset));
    return violations;
  }

  Violation buildViolation(CompiledRule rule, MatchResult r, MatchContext ctx) {
    final node = r.node;
    final start = ctx.lineInfo.getLocation(node.offset);
    final end = ctx.lineInfo.getLocation(node.end);
    final found = ctx.sourceOf(node);
    final data = <String, String>{
      ...rule.vars.map((k, v) => MapEntry('vars.$k', v)),
      for (final v in ctx.values.entries) 'values.${v.key}': v.value.render(),
      'rule': rule.id,
      'severity': rule.severity.name,
      'file': ctx.relativePath,
      'line': '${start.lineNumber}',
      'col': '${start.columnNumber}',
      'found': found,
      if (rule.useInstead != null) 'use_instead': rule.useInstead!,
      if (rule.docs != null) 'docs': rule.docs!,
      if (rule.description != null) 'description': rule.description!,
      'ignore': '// ignore: agent_lints/${rule.id} -- <reason>',
      ..._enclosing(node),
      ...r.captures,
    };
    final message = rule.message.render(data);
    return Violation(
      ruleId: rule.id,
      severity: rule.severity,
      path: ctx.path,
      relativePath: ctx.relativePath,
      offset: node.offset,
      length: node.length,
      line: start.lineNumber,
      column: start.columnNumber,
      endLine: end.lineNumber,
      endColumn: end.columnNumber,
      found: found,
      message: message,
      shortMessage: rule.message.renderShort(data),
      description: rule.description,
      suggest: rule.suggest?.render(data),
      useInstead: rule.useInstead,
      docs: rule.docs,
      captures: r.captures,
    );
  }

  static Map<String, String> _enclosing(AstNode node) {
    final out = <String, String>{};
    for (var n = node.parent; n != null; n = n.parent) {
      if (!out.containsKey('enclosing_function')) {
        if (n is MethodDeclaration) out['enclosing_function'] = n.name.lexeme;
        if (n is FunctionDeclaration) out['enclosing_function'] = n.name.lexeme;
        if (n is ConstructorDeclaration) {
          out['enclosing_function'] = n.name?.lexeme ?? 'new';
        }
      }
      if (n is ClassDeclaration) {
        out['enclosing_class'] = n.namePart.typeName.lexeme;
        break;
      }
      if (n is MixinDeclaration) {
        out['enclosing_class'] = n.name.lexeme;
        break;
      }
      if (n is ExtensionDeclaration) {
        out['enclosing_class'] = n.name?.lexeme ?? '';
        break;
      }
    }
    return out;
  }
}
