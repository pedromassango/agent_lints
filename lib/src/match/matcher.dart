import 'package:analyzer/dart/ast/ast.dart';

import 'match_context.dart';
import 'node_kind.dart';

/// Result of a successful match: the node to report and captured values that
/// feed message placeholders.
class MatchResult {
  MatchResult(this.node, [Map<String, String>? captures])
    : captures = captures ?? {};

  final AstNode node;
  final Map<String, String> captures;

  MatchResult merge(MatchResult other) =>
      MatchResult(node, {...captures, ...other.captures});
}

/// A compiled rule condition evaluated against AST nodes.
abstract class Matcher {
  /// Node kinds this matcher can succeed on. Used to subscribe the rule to the
  /// right visitor hooks. Empty for pure constraints.
  Set<NodeKind> get anchors;

  /// Returns a result when [node] satisfies this matcher, else null. Matchers
  /// must return null for nodes of a kind they do not handle.
  MatchResult? match(AstNode node, MatchContext ctx);

  /// One-line description for `explain`.
  String describe();
}
