import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../resolve/types.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import 'element_filter.dart';

/// `ref:` — a non-invoked reference to an element (`Colors.red`, `math.pi`,
/// a tear-off, a bare class name).
class RefMatcher extends Matcher {
  RefMatcher({required this.filter, this.type});

  final ElementFilter filter;
  final TypePattern? type;

  static const keys = [...ElementFilter.keys, 'type'];

  @override
  Set<NodeKind> get anchors => {NodeKind.ref};

  /// Whether [node] is a reference site (and not e.g. a method name).
  static bool isReferenceSite(AstNode node) {
    final parent = node.parent;
    switch (node) {
      case PrefixedIdentifier():
        return true;
      case PropertyAccess():
        return true;
      case SimpleIdentifier():
        if (parent is PrefixedIdentifier) return false;
        if (parent is PropertyAccess && parent.propertyName == node) {
          return false;
        }
        if (parent is MethodInvocation && parent.methodName == node) {
          return false;
        }
        if (parent is ConstructorName ||
            parent is Label ||
            parent is ImportDirective ||
            parent is CommentReference ||
            parent is ConstructorFieldInitializer ||
            parent is Combinator ||
            parent is FieldFormalParameter) {
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    if (!isReferenceSite(node)) return null;
    final Element? element;
    switch (node) {
      case PrefixedIdentifier():
        element = node.identifier.element;
      case PropertyAccess():
        element = node.propertyName.element;
      case SimpleIdentifier():
        element = node.element;
      default:
        return null;
    }
    if (element == null || element is PrefixElement) return null;
    final captures = <String, String>{};
    if (!filter.matches(element, ctx, captures)) return null;
    final expr = node as Expression;
    if (type != null && !type!.matches(expr.staticType)) return null;
    final t = expr.staticType;
    if (t != null) captures['type'] = t.getDisplayString();
    return MatchResult(node, captures);
  }

  @override
  String describe() =>
      'ref ${filter.describe()}'
      '${type == null ? '' : ' type=${type!.describe()}'}';
}
