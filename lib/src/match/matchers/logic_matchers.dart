import 'package:analyzer/dart/ast/ast.dart';

import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';

/// `any: [..]` — first branch that matches wins.
class AnyMatcher extends Matcher {
  AnyMatcher(this.branches);
  final List<Matcher> branches;

  @override
  Set<NodeKind> get anchors => branches.expand((b) => b.anchors).toSet();

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    for (final b in branches) {
      final r = b.match(node, ctx);
      if (r != null) return r;
    }
    return null;
  }

  @override
  String describe() => 'any(${branches.map((b) => b.describe()).join(' | ')})';
}

/// `all: [..]` — every branch must match the same node.
class AllMatcher extends Matcher {
  AllMatcher(this.branches);
  final List<Matcher> branches;

  @override
  Set<NodeKind> get anchors => branches.first.anchors;

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    MatchResult? acc;
    for (final b in branches) {
      final r = b.match(node, ctx);
      if (r == null) return null;
      acc = acc == null ? r : acc.merge(r);
    }
    return acc;
  }

  @override
  String describe() => 'all(${branches.map((b) => b.describe()).join(' & ')})';
}

/// `not: {..}` — only valid nested (inside `expr`, `inside`, ...).
class NotMatcher extends Matcher {
  NotMatcher(this.inner);
  final Matcher inner;

  @override
  Set<NodeKind> get anchors => const {};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) =>
      inner.match(node, ctx) == null ? MatchResult(node) : null;

  @override
  String describe() => 'not(${inner.describe()})';
}
