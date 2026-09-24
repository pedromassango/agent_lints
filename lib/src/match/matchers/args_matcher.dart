import 'package:analyzer/dart/ast/ast.dart';
import 'package:yaml/yaml.dart';

import '../../config/values.dart';
import '../../config/yaml_reader.dart';
import '../../resolve/constants.dart';
import '../../resolve/types.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../patterns.dart';

/// One entry under `args:`.
class ArgConstraint {
  ArgConstraint({
    this.present,
    this.literal,
    this.value,
    this.inList,
    this.notIn,
    this.min,
    this.max,
    this.type,
    this.source,
    this.ref,
    this.expr,
    this.valueListName,
  });

  final bool? present;
  final String? literal;
  final ConstValue? value;
  final List<Object?>? inList;
  final List<Object?>? notIn;
  final num? min;
  final num? max;
  final TypePattern? type;
  final RegExp? source;
  final Matcher? ref;
  final Matcher? expr;

  /// Name of the `$values` list used by `in`/`not_in`, for `{{allowed}}`.
  final String? valueListName;

  static const keys = [
    'present',
    'literal',
    'value',
    'in',
    'not_in',
    'min',
    'max',
    'type',
    'source',
    'ref',
    'expr',
  ];

  bool get hasContentConstraint =>
      literal != null ||
      value != null ||
      inList != null ||
      notIn != null ||
      min != null ||
      max != null ||
      type != null ||
      source != null ||
      ref != null ||
      expr != null;

  /// Tests an argument expression. Fills `value`, `allowed`, `closest`.
  bool matchesExpression(
    Expression e,
    MatchContext ctx,
    Map<String, String> captures,
  ) {
    final lit = literal;
    if (lit != null) {
      final actual = literalKindOf(e);
      if (actual == null || !literalKindMatches(lit, actual)) return false;
    }
    ConstValue? cv;
    if (value != null ||
        inList != null ||
        notIn != null ||
        min != null ||
        max != null) {
      cv = constantValueOf(e);
      if (cv == null) return false;
      final v = cv.value;
      if (value != null && !_equal(value!.value, v)) return false;
      if (inList != null && !inList!.any((x) => _equal(x, v))) return false;
      if (notIn != null && notIn!.any((x) => _equal(x, v))) return false;
      if (min != null && (v is! num || v < min!)) return false;
      if (max != null && (v is! num || v > max!)) return false;
    }
    if (type != null && !type!.matches(e.staticType)) return false;
    if (source != null && !source!.hasMatch(ctx.sourceOf(e))) return false;
    if (ref != null) {
      final r = ref!.match(e, ctx);
      if (r == null) return false;
      captures.addAll(r.captures);
    }
    if (expr != null) {
      final r = expr!.match(e, ctx);
      if (r == null) return false;
      captures.addAll(r.captures);
    }
    cv ??= constantValueOf(e);
    captures['value'] = cv?.render() ?? ctx.sourceOf(e);
    final listName = valueListName;
    if (listName != null) {
      final list = ctx.values[listName];
      if (list != null) {
        captures['allowed'] = list.render();
        final v = cv?.value;
        if (v is num) {
          final closest = list.closest(v);
          if (closest.isNotEmpty) {
            captures['closest'] = closest.map((c) => c.render()).join(', ');
            captures['closest.name'] =
                closest.first.name ?? closest.first.render();
            captures['closest.value'] = ValueEntry(
              closest.first.value,
            ).render();
          }
        }
      }
    }
    return true;
  }

  static bool _equal(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    return a == b;
  }
}

/// The `args:` block of a `call` / `new` matcher.
class ArgsMatcher {
  ArgsMatcher(this.constraints);

  /// Keyed by parameter name, positional index (as string), `*` or `**`.
  final Map<String, ArgConstraint> constraints;

  static ArgsMatcher? fromNode(
    YamlNode? node,
    YamlReader parent,
    String key,
    Map<String, ValueList> values,
    Matcher? Function(YamlNode node, String path) compileNested,
  ) {
    if (node == null) return null;
    if (node is! YamlMap) {
      parent.error('expected a map of argument constraints', key: key);
      return null;
    }
    final r = YamlReader(node, parent.childPath(key), parent.errors);
    final out = <String, ArgConstraint>{};
    for (final argKey in r.keys) {
      final raw = r.map.nodes[argKey];
      // Shorthands: `present`, `absent`, a list (one of), a scalar (equals).
      if (raw is YamlScalar) {
        final v = raw.value;
        if (v == 'present') {
          out[argKey] = ArgConstraint(present: true);
        } else if (v == 'absent') {
          out[argKey] = ArgConstraint(present: false);
        } else if (v is num || v is String || v is bool) {
          out[argKey] = ArgConstraint(value: ConstValue(v));
        } else {
          r.error(
            'expected present, absent, a value, a list or a map',
            key: argKey,
          );
        }
        continue;
      }
      if (raw is YamlList) {
        out[argKey] = ArgConstraint(
          inList: raw.nodes.map((e) => e.value).toList(),
        );
        continue;
      }
      final c = r.child(argKey);
      if (c == null) continue;
      c.rejectUnknownKeys(ArgConstraint.keys);
      String? listName;
      List<Object?>? readList(String k) {
        final n = c.map.nodes[k];
        if (n == null) return null;
        if (n is YamlScalar &&
            n.value is String &&
            (n.value as String).startsWith(r'$')) {
          final name = (n.value as String).substring(1);
          final list = values[name];
          if (list == null) {
            c.error(
              'unknown values list "\$$name"',
              key: k,
              hint: values.isEmpty
                  ? 'declare it under top-level values:'
                  : 'declared: ${values.keys.join(', ')}',
            );
            return null;
          }
          listName = name;
          return list.values.toList();
        }
        if (n is YamlList) {
          return n.nodes.map((e) => e.value).toList();
        }
        c.error('expected a list or a \$values reference', key: k);
        return null;
      }

      final inList = readList('in');
      final notIn = readList('not_in');
      final valueNode = c.map.nodes['value'];
      final minNode = c.map.nodes['min'];
      final maxNode = c.map.nodes['max'];
      final sourceStr = c.string('source');
      RegExp? source;
      if (sourceStr != null) {
        final pat = StringPattern.fromString(sourceStr);
        source = pat is RegexPattern
            ? pat.regex
            : RegExp(RegExp.escape(sourceStr));
      }
      final literal = c.string('literal');
      const literalKinds = {
        'int',
        'double',
        'num',
        'string',
        'bool',
        'null',
        'list',
        'map',
        'set',
        'any',
      };
      if (literal != null && !literalKinds.contains(literal)) {
        c.error(
          'invalid literal kind "$literal"',
          key: 'literal',
          hint: 'allowed: ${literalKinds.join(', ')}',
        );
      }
      final refNode = c.map.nodes['ref'];
      final exprNode = c.map.nodes['expr'];
      out[argKey] = ArgConstraint(
        present: c.boolean('present'),
        literal: literal,
        value: valueNode == null ? null : ConstValue(valueNode.value),
        inList: inList,
        notIn: notIn,
        min: minNode?.value is num ? minNode!.value as num : null,
        max: maxNode?.value is num ? maxNode!.value as num : null,
        type: TypePattern.fromNode(c.map.nodes['type'], c, 'type'),
        source: source,
        ref: refNode == null
            ? null
            : compileNested(
                YamlMap.wrap({'ref': refNode.value}),
                c.childPath('ref'),
              ),
        expr: exprNode == null
            ? null
            : compileNested(exprNode, c.childPath('expr')),
        valueListName: listName,
      );
    }
    return ArgsMatcher(out);
  }

  /// Records `args.<name>` / `args.<index>` captures for every argument.
  static void captureAll(
    ArgumentList args,
    MatchContext ctx,
    Map<String, String> captures,
  ) {
    for (final e in _enumerate(args)) {
      captures['args.${e.key}'] = ctx.sourceOf(e.expression);
      if (e.index != null) {
        captures['args.${e.index}'] = ctx.sourceOf(e.expression);
      }
    }
  }

  bool matches(
    ArgumentList args,
    MatchContext ctx,
    Map<String, String> captures,
  ) {
    final entries = _enumerate(args);
    captureAll(args, ctx, captures);
    for (final MapEntry(key: key, value: c) in constraints.entries) {
      if (key == '*') {
        final hit = entries.any(
          (e) => c.matchesExpression(e.expression, ctx, captures),
        );
        if (!hit) return false;
        // Re-run to leave captures of the first matching argument.
        for (final e in entries) {
          final local = <String, String>{};
          if (c.matchesExpression(e.expression, ctx, local)) {
            captures['arg'] = e.key;
            captures.addAll(local);
            break;
          }
        }
        continue;
      }
      if (key == '**') {
        for (final e in entries) {
          if (!c.matchesExpression(e.expression, ctx, captures)) return false;
        }
        continue;
      }
      final found = entries
          .where((e) => e.key == key || '${e.index}' == key)
          .toList();
      if (c.present == false) {
        if (found.isNotEmpty) return false;
        continue;
      }
      if (found.isEmpty) return false;
      if (c.hasContentConstraint) {
        final e = found.first;
        if (!c.matchesExpression(e.expression, ctx, captures)) return false;
        captures['arg'] = e.key;
      }
    }
    return true;
  }

  static List<_Arg> _enumerate(ArgumentList args) {
    final out = <_Arg>[];
    var index = 0;
    for (final a in args.arguments) {
      if (a is NamedArgument) {
        out.add(_Arg(a.name.lexeme, a.argumentExpression, null));
      } else if (a is Expression) {
        final name = a.correspondingParameter?.name ?? '$index';
        out.add(_Arg(name, a, index));
        index++;
      }
    }
    return out;
  }

  String describe() => 'args(${constraints.keys.join(', ')})';
}

class _Arg {
  _Arg(this.key, this.expression, this.index);
  final String key;
  final Expression expression;
  final int? index;
}
