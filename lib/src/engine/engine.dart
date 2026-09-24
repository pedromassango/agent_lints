import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../config/config.dart';
import '../match/compiled_rule.dart';
import '../match/match_context.dart';
import '../match/matcher.dart';
import '../match/node_kind.dart';
import '../report/violation.dart';
import 'kind_visitor.dart';
import 'suppression.dart';

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

  /// Synthetic rule ids the engine itself reports.
  static const unusedIgnoreRule = 'unused_ignore';
  static const ignoreWithoutReasonRule = 'ignore_without_reason';

  /// Violations silenced by `// ignore:` comments across all calls, for
  /// auditing.
  final List<Violation> suppressed = [];

  List<Violation> analyzeUnit(
    ResolvedUnitResult result, {
    String? relativePath,
  }) => analyzeCompilationUnit(
    unit: result.unit,
    content: result.content,
    path: result.path,
    relativePath: relativePath,
  );

  /// Analyzes an already resolved [unit]. Used by the analyzer plugin, which
  /// receives units without a [ResolvedUnitResult].
  List<Violation> analyzeCompilationUnit({
    required CompilationUnit unit,
    required String content,
    required String path,
    String? relativePath,
  }) {
    final rel = relativePath ?? config.relativePath(path) ?? path;
    final raw = _analyze(unit: unit, content: content, path: path, rel: rel);
    final suppressions = Suppressions.parse(
      unit,
      unit.lineInfo,
      config.rules.map((r) => r.id).toSet(),
      content: content,
    );
    if (suppressions.comments.isEmpty) return raw;
    final kept = <Violation>[];
    for (final v in raw) {
      final ignore = suppressions.find(v.ruleId, v.line);
      if (ignore == null) {
        kept.add(v);
      } else {
        suppressed.add(v);
      }
    }
    for (final c in suppressions.comments) {
      if (config.requireIgnoreReason && c.used && (c.reason?.isEmpty ?? true)) {
        kept.add(
          _synthetic(
            ignoreWithoutReasonRule,
            Severity.warning,
            unit,
            content,
            path,
            rel,
            c,
            'ignore comment has no reason. Write `-- <why>` after the rule id.',
          ),
        );
      }
    }
    for (final c in suppressions.unused) {
      kept.add(
        _synthetic(
          unusedIgnoreRule,
          Severity.info,
          unit,
          content,
          path,
          rel,
          c,
          'ignore comment for ${c.rules.join(', ')} suppresses nothing; remove it.',
        ),
      );
    }
    kept.sort((a, b) => a.offset.compareTo(b.offset));
    return kept;
  }

  Violation _synthetic(
    String ruleId,
    Severity severity,
    CompilationUnit unit,
    String content,
    String path,
    String rel,
    IgnoreComment c,
    String message,
  ) {
    final loc = unit.lineInfo.getLocation(c.offset);
    final lineEnd = content.indexOf('\n', c.offset);
    final length = (lineEnd == -1 ? content.length : lineEnd) - c.offset;
    return Violation(
      ruleId: ruleId,
      severity: severity,
      path: path,
      relativePath: rel,
      offset: c.offset,
      length: length,
      line: loc.lineNumber,
      column: loc.columnNumber,
      endLine: loc.lineNumber,
      endColumn: loc.columnNumber + length,
      found: content.substring(c.offset, c.offset + length),
      message: message,
      shortMessage: message,
    );
  }

  List<Violation> _analyze({
    required CompilationUnit unit,
    required String content,
    required String path,
    required String rel,
  }) {
    final ctx = MatchContext(
      unit: unit,
      content: content,
      path: path,
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
    unit.accept(
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
    final start = ctx.lineInfo.getLocation(r.reportOffset);
    final end = ctx.lineInfo.getLocation(r.reportOffset + r.reportLength);
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
      offset: r.reportOffset,
      length: r.reportLength,
      line: start.lineNumber,
      column: start.columnNumber,
      endLine: end.lineNumber,
      endColumn: end.columnNumber,
      found: found,
      message: message,
      shortMessage: rule.message.renderShort(data),
      description: rule.description,
      hint: rule.hint?.render(data),
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
