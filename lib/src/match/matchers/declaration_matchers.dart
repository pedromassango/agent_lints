import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../resolve/names.dart';
import '../../resolve/types.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';

/// `function:` — function, method, constructor, getter and setter declarations.
class FunctionMatcher extends Matcher {
  FunctionMatcher({
    this.name,
    this.kind,
    this.returns,
    this.isAsync,
    this.isStatic,
    this.isConst,
    this.hasOverride,
    this.annotation,
  });

  final StringPattern? name;

  /// `method`, `function`, `constructor`, `getter`, `setter`, `local`.
  final StringPattern? kind;
  final TypePattern? returns;
  final bool? isAsync;
  final bool? isStatic;
  final bool? isConst;
  final bool? hasOverride;
  final StringPattern? annotation;

  static const keys = [
    'name',
    'kind',
    'returns',
    'async',
    'static',
    'const',
    'override',
    'annotation',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.function};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    final String declaredName;
    final String declaredKind;
    final FunctionBody body;
    final bool static;
    final bool constant;
    final NodeList<Annotation> metadata;
    final Element? element;
    switch (node) {
      case MethodDeclaration():
        declaredName = node.name.lexeme;
        declaredKind = node.isGetter
            ? 'getter'
            : node.isSetter
            ? 'setter'
            : 'method';
        body = node.body;
        static = node.isStatic;
        constant = false;
        metadata = node.metadata;
        element = node.declaredFragment?.element;
      case FunctionDeclaration():
        declaredName = node.name.lexeme;
        declaredKind = node.isGetter
            ? 'getter'
            : node.isSetter
            ? 'setter'
            : node.parent is FunctionDeclarationStatement
            ? 'local'
            : 'function';
        body = node.functionExpression.body;
        static = false;
        constant = false;
        metadata = node.metadata;
        element = node.declaredFragment?.element;
      case ConstructorDeclaration():
        declaredName = node.name?.lexeme ?? 'new';
        declaredKind = 'constructor';
        body = node.body;
        static = false;
        constant = node.constKeyword != null;
        metadata = node.metadata;
        element = node.declaredFragment?.element;
      default:
        return null;
    }
    if (name != null && !name!.matches(declaredName)) return null;
    if (kind != null && !kind!.matches(declaredKind)) return null;
    if (isAsync != null && body.isAsynchronous != isAsync) {
      return null;
    }
    if (isStatic != null && static != isStatic) return null;
    if (isConst != null && constant != isConst) return null;
    if (hasOverride != null) {
      final has = metadata.any((a) => a.name.name == 'override');
      if (has != hasOverride) return null;
    }
    if (annotation != null &&
        !metadata.any((a) => annotation!.matches(a.name.name))) {
      return null;
    }
    if (returns != null) {
      final DartType? type = switch (element) {
        ExecutableElement() => element.returnType,
        _ => null,
      };
      if (!returns!.matches(type)) return null;
    }
    final resolved = ResolvedName.of(element);
    return MatchResult(node, {
      'name': resolved?.qualified ?? declaredName,
      'short_name': declaredName,
      'kind': declaredKind,
    });
  }

  @override
  String describe() =>
      'function'
      '${name == null ? '' : ' name=${name!.describe()}'}'
      '${kind == null ? '' : ' kind=${kind!.describe()}'}';
}

/// `class:` — class, mixin, enum and extension declarations.
class ClassMatcher extends Matcher {
  ClassMatcher({
    this.name,
    this.kind,
    this.extendsType,
    this.implementsType,
    this.mixesIn,
    this.isAbstract,
    this.annotation,
    this.has = const [],
    this.lacks = const [],
  });

  final StringPattern? name;

  /// `class`, `mixin`, `enum`, `extension`.
  final StringPattern? kind;
  final TypePattern? extendsType;
  final TypePattern? implementsType;
  final TypePattern? mixesIn;
  final bool? isAbstract;
  final StringPattern? annotation;
  final List<Matcher> has;
  final List<Matcher> lacks;

  static const keys = [
    'name',
    'kind',
    'extends',
    'implements',
    'mixes_in',
    'abstract',
    'annotation',
    'has',
    'lacks',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.classDecl};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    final String declaredName;
    final String declaredKind;
    final InterfaceElement? element;
    final bool abstract;
    final NodeList<Annotation> metadata;
    final NodeList<ClassMember> members;
    switch (node) {
      case ClassDeclaration():
        declaredName = node.namePart.typeName.lexeme;
        declaredKind = 'class';
        element = node.declaredFragment?.element;
        abstract = node.abstractKeyword != null;
        metadata = node.metadata;
        members = node.body.members;
      case MixinDeclaration():
        declaredName = node.name.lexeme;
        declaredKind = 'mixin';
        element = node.declaredFragment?.element;
        abstract = false;
        metadata = node.metadata;
        members = node.body.members;
      case EnumDeclaration():
        declaredName = node.namePart.typeName.lexeme;
        declaredKind = 'enum';
        element = node.declaredFragment?.element;
        abstract = false;
        metadata = node.metadata;
        members = node.body.members;
      case ExtensionDeclaration():
        declaredName = node.name?.lexeme ?? '';
        declaredKind = 'extension';
        element = null;
        abstract = false;
        metadata = node.metadata;
        members = node.body.members;
      default:
        return null;
    }
    if (name != null && !name!.matches(declaredName)) return null;
    if (kind != null && !kind!.matches(declaredKind)) return null;
    if (isAbstract != null && abstract != isAbstract) return null;
    if (annotation != null &&
        !metadata.any((a) => annotation!.matches(a.name.name))) {
      return null;
    }
    if (extendsType != null) {
      InterfaceType? sup = element?.supertype;
      var ok = false;
      while (sup != null) {
        if (extendsType!.matches(sup)) {
          ok = true;
          break;
        }
        sup = sup.element.supertype;
      }
      if (!ok) return null;
    }
    if (implementsType != null) {
      final all = element?.allSupertypes ?? const <InterfaceType>[];
      if (!all.any(implementsType!.matches)) return null;
    }
    if (mixesIn != null) {
      final mixins = element?.mixins ?? const <InterfaceType>[];
      if (!mixins.any(mixesIn!.matches)) return null;
    }
    for (final m in has) {
      if (!members.any((member) => m.match(member, ctx) != null)) return null;
    }
    for (final m in lacks) {
      if (members.any((member) => m.match(member, ctx) != null)) return null;
    }
    return MatchResult(node, {
      'name': declaredName,
      'short_name': declaredName,
      'kind': declaredKind,
    });
  }

  @override
  String describe() =>
      'class'
      '${name == null ? '' : ' name=${name!.describe()}'}'
      '${extendsType == null ? '' : ' extends=${extendsType!.describe()}'}';
}
