import 'package:analyzer/dart/ast/ast.dart';

import '../../engine/kind_visitor.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';

/// One `inside:` entry.
class InsideSpec {
  InsideSpec(this.matcher, {this.direct = false});
  final Matcher matcher;

  /// The matched node must be an argument of this ancestor, with only argument
  /// lists, named expressions, list literals and parentheses in between.
  final bool direct;
}

/// Wraps a node matcher with `inside` / `not_inside` / `contains` /
/// `not_contains` constraints.
class ContextMatcher extends Matcher {
  ContextMatcher(
    this.inner, {
    this.inside = const [],
    this.notInside = const [],
    this.contains = const [],
    this.notContains = const [],
  });

  final Matcher inner;
  final List<InsideSpec> inside;
  final List<InsideSpec> notInside;
  final List<Matcher> contains;
  final List<Matcher> notContains;

  static const keys = ['inside', 'not_inside', 'contains', 'not_contains'];

  @override
  Set<NodeKind> get anchors => inner.anchors;

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    final r = inner.match(node, ctx);
    if (r == null) return null;
    final captures = r.captures;
    for (final spec in inside) {
      final hit = _findAncestor(node, spec, ctx);
      if (hit == null) return null;
      captures['ancestor'] =
          hit.captures['name'] ?? ctx.sourceOf(hit.node, max: 40);
      for (final e in hit.captures.entries) {
        captures['ancestor.${e.key}'] = e.value;
      }
    }
    for (final spec in notInside) {
      if (_findAncestor(node, spec, ctx) != null) return null;
    }
    for (final m in contains) {
      if (_findDescendant(node, m, ctx) == null) return null;
    }
    for (final m in notContains) {
      if (_findDescendant(node, m, ctx) != null) return null;
    }
    return r;
  }

  static MatchResult? _findAncestor(
    AstNode node,
    InsideSpec spec,
    MatchContext ctx,
  ) {
    for (var n = node.parent; n != null; n = n.parent) {
      if (spec.direct) {
        if (n is ArgumentList ||
            n is NamedArgument ||
            n is ListLiteral ||
            n is SetOrMapLiteral ||
            n is MapLiteralEntry ||
            n is ParenthesizedExpression ||
            n is SpreadElement ||
            n is IfElement ||
            n is ForElement) {
          continue;
        }
        if (n is InstanceCreationExpression ||
            n is MethodInvocation ||
            n is FunctionExpressionInvocation) {
          return spec.matcher.match(n, ctx);
        }
        return null;
      }
      final r = spec.matcher.match(n, ctx);
      if (r != null) return r;
    }
    return null;
  }

  static MatchResult? _findDescendant(
    AstNode node,
    Matcher matcher,
    MatchContext ctx,
  ) {
    MatchResult? found;
    final visitor = KindVisitor((kind, n) {
      if (found != null || identical(n, node)) return;
      if (!matcher.anchors.contains(kind)) return;
      found = matcher.match(n, ctx);
    });
    node.visitChildren(visitor);
    return found;
  }

  @override
  String describe() {
    final parts = <String>[inner.describe()];
    for (final s in inside) {
      parts.add('inside${s.direct ? '(direct)' : ''} ${s.matcher.describe()}');
    }
    for (final s in notInside) {
      parts.add('not_inside ${s.matcher.describe()}');
    }
    for (final m in contains) {
      parts.add('contains ${m.describe()}');
    }
    for (final m in notContains) {
      parts.add('not_contains ${m.describe()}');
    }
    return parts.join(', ');
  }
}
