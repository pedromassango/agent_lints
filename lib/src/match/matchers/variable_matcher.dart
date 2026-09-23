import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../resolve/types.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';

/// `variable:` — top-level variables, fields and locals.
class VariableMatcher extends Matcher {
  VariableMatcher({
    this.name,
    this.scope,
    this.type,
    this.isConst,
    this.isFinal,
    this.isLate,
    this.isStatic,
    this.annotation,
    this.initializer,
  });

  final StringPattern? name;

  /// `top_level`, `field`, `local`.
  final StringPattern? scope;
  final TypePattern? type;
  final bool? isConst;
  final bool? isFinal;
  final bool? isLate;
  final bool? isStatic;
  final StringPattern? annotation;
  final Matcher? initializer;

  static const keys = [
    'name',
    'scope',
    'type',
    'const',
    'final',
    'late',
    'static',
    'annotation',
    'initializer',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.variable};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    if (node is! VariableDeclaration) return null;
    final list = node.parent;
    if (list is! VariableDeclarationList) return null;
    final owner = list.parent;
    final String declaredScope;
    final bool static;
    final NodeList<Annotation> metadata;
    switch (owner) {
      case TopLevelVariableDeclaration():
        declaredScope = 'top_level';
        static = false;
        metadata = owner.metadata;
      case FieldDeclaration():
        declaredScope = 'field';
        static = owner.isStatic;
        metadata = owner.metadata;
      default:
        declaredScope = 'local';
        static = false;
        metadata = list.metadata;
    }
    final declaredName = node.name.lexeme;
    if (name != null && !name!.matches(declaredName)) return null;
    if (scope != null && !scope!.matches(declaredScope)) return null;
    if (isConst != null && node.isConst != isConst) return null;
    if (isFinal != null && node.isFinal != isFinal) return null;
    if (isLate != null && node.isLate != isLate) return null;
    if (isStatic != null && static != isStatic) return null;
    if (annotation != null &&
        !metadata.any((a) => annotation!.matches(a.name.name))) {
      return null;
    }
    final element = node.declaredFragment?.element;
    if (type != null) {
      final t = element is VariableElement ? element.type : null;
      if (!type!.matches(t)) return null;
    }
    final captures = <String, String>{
      'name': declaredName,
      'short_name': declaredName,
      'kind': declaredScope,
    };
    if (element is VariableElement) {
      captures['type'] = element.type.getDisplayString();
    }
    if (initializer != null) {
      final init = node.initializer;
      if (init == null) return null;
      final r = initializer!.match(init, ctx);
      if (r == null) return null;
      // The variable's own captures win over the initializer's.
      for (final e in r.captures.entries) {
        captures.putIfAbsent(e.key, () => e.value);
      }
    }
    return MatchResult(node, captures);
  }

  @override
  String describe() =>
      'variable'
      '${name == null ? '' : ' name=${name!.describe()}'}'
      '${scope == null ? '' : ' scope=${scope!.describe()}'}'
      '${type == null ? '' : ' type=${type!.describe()}'}';
}
