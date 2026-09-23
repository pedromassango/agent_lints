import 'package:analyzer/dart/ast/ast.dart';

import '../../resolve/constants.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';

/// `literal:` — int, double, string, bool, null, list and map literals.
class LiteralMatcher extends Matcher {
  LiteralMatcher({
    this.kind,
    this.value,
    this.inList,
    this.notIn,
    this.min,
    this.max,
    this.source,
    this.interpolated,
  });

  final String? kind;
  final Object? value;
  final List<Object?>? inList;
  final List<Object?>? notIn;
  final num? min;
  final num? max;
  final RegExp? source;
  final bool? interpolated;

  static const keys = [
    'kind',
    'value',
    'in',
    'not_in',
    'min',
    'max',
    'source',
    'interpolated',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.literal};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    if (node is! Literal) return null;
    // Import/export/part URIs are not "code" literals.
    if (node.parent is UriBasedDirective || node.parent is PartOfDirective) {
      return null;
    }
    final actualKind = literalKindOf(node);
    if (actualKind == null) return null;
    if (kind != null && !literalKindMatches(kind!, actualKind)) return null;
    if (interpolated != null && (node is StringInterpolation) != interpolated) {
      return null;
    }
    final cv = constantValueOf(node);
    final v = cv?.value;
    if (value != null && (cv == null || !_equal(value, v))) return null;
    if (inList != null && (cv == null || !inList!.any((x) => _equal(x, v)))) {
      return null;
    }
    if (notIn != null && cv != null && notIn!.any((x) => _equal(x, v))) {
      return null;
    }
    if (min != null && (v is! num || v < min!)) return null;
    if (max != null && (v is! num || v > max!)) return null;
    if (source != null && !source!.hasMatch(ctx.sourceOf(node))) return null;
    return MatchResult(node, {
      'kind': actualKind,
      'value': cv?.render() ?? ctx.sourceOf(node),
      if (node.staticType != null) 'type': node.staticType!.getDisplayString(),
    });
  }

  static bool _equal(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    return a == b;
  }

  @override
  String describe() =>
      'literal${kind == null ? '' : ' kind=$kind'}'
      '${source == null ? '' : ' source=/${source!.pattern}/'}';
}
