import 'package:analyzer/dart/ast/ast.dart';

import '../../resolve/types.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import 'args_matcher.dart';
import 'element_filter.dart';

/// `new:` — instance creation expressions.
class NewMatcher extends Matcher {
  NewMatcher({required this.filter, this.isConst, this.type, this.args});

  final ElementFilter filter;
  final bool? isConst;
  final TypePattern? type;
  final ArgsMatcher? args;

  static const keys = [...ElementFilter.keys, 'const', 'type', 'args'];

  @override
  Set<NodeKind> get anchors => {NodeKind.newExpr};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    if (node is! InstanceCreationExpression) return null;
    final captures = <String, String>{};
    final element = node.constructorName.element;
    if (!filter.matches(
      element,
      ctx,
      captures,
      fallbackName: node.constructorName.type.name.lexeme,
    )) {
      return null;
    }
    if (isConst != null && node.isConst != isConst) return null;
    if (type != null && !type!.matches(node.staticType)) return null;
    if (args != null && !args!.matches(node.argumentList, ctx, captures)) {
      return null;
    }
    final t = node.staticType;
    if (t != null) captures['type'] = t.getDisplayString();
    return MatchResult(node, captures);
  }

  @override
  String describe() =>
      'new ${filter.describe()}'
      '${isConst == null ? '' : ' const=$isConst'}'
      '${type == null ? '' : ' type=${type!.describe()}'}'
      '${args == null ? '' : ' ${args!.describe()}'}';
}
