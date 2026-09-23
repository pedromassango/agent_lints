import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../resolve/types.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';
import 'args_matcher.dart';
import 'element_filter.dart';

/// `call:` — method and function invocations.
class CallMatcher extends Matcher {
  CallMatcher({
    required this.filter,
    this.onType,
    this.onName,
    this.returns,
    this.awaited,
    this.isStatic,
    this.args,
  });

  final ElementFilter filter;

  /// `on: { type: X }` — static type of the receiver.
  final TypePattern? onType;

  /// `on: { name: X }` — receiver is a class / prefix reference named X.
  final StringPattern? onName;
  final TypePattern? returns;
  final bool? awaited;
  final bool? isStatic;
  final ArgsMatcher? args;

  static const keys = [
    ...ElementFilter.keys,
    'on',
    'returns',
    'await',
    'static',
    'args',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.call};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    final Element? element;
    final String fallback;
    final Expression? receiver;
    final ArgumentList argumentList;
    switch (node) {
      case MethodInvocation():
        element = node.methodName.element;
        fallback = node.methodName.name;
        receiver = node.realTarget;
        argumentList = node.argumentList;
      case FunctionExpressionInvocation():
        element = node.element;
        fallback = ctx.sourceOf(node.function, max: 60);
        receiver = null;
        argumentList = node.argumentList;
      default:
        return null;
    }
    final captures = <String, String>{};
    if (!filter.matches(element, ctx, captures, fallbackName: fallback)) {
      return null;
    }
    if (onType != null && !onType!.matches(receiver?.staticType)) return null;
    if (onName != null) {
      final r = receiver;
      final n = r is Identifier ? r.element?.name : null;
      if (n == null || !onName!.matches(n)) return null;
    }
    if (returns != null && !returns!.matches((node as Expression).staticType)) {
      return null;
    }
    if (awaited != null && (node.parent is AwaitExpression) != awaited) {
      return null;
    }
    if (isStatic != null) {
      final s = element is ExecutableElement && element.isStatic;
      if (s != isStatic) return null;
    }
    if (args != null && !args!.matches(argumentList, ctx, captures)) {
      return null;
    }
    ArgsMatcher.captureAll(argumentList, ctx, captures);
    if (receiver != null) {
      captures['receiver'] = ctx.sourceOf(receiver, max: 60);
    }
    final t = (node as Expression).staticType;
    if (t != null) captures['type'] = t.getDisplayString();
    return MatchResult(node, captures);
  }

  @override
  String describe() =>
      'call ${filter.describe()}'
      '${onType == null ? '' : ' on.type=${onType!.describe()}'}'
      '${onName == null ? '' : ' on.name=${onName!.describe()}'}'
      '${args == null ? '' : ' ${args!.describe()}'}';
}
