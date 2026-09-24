import 'package:yaml/yaml.dart';

import '../config/yaml_reader.dart';

/// A string pattern from YAML: exact text, glob (`*`, `?`), regex (`/.../`),
/// a list (any of), or `{ not: pattern }`.
abstract class StringPattern {
  bool matches(String input);

  /// Human-readable form for `explain`.
  String describe();

  static StringPattern? fromNode(
    YamlNode? node,
    YamlReader reader,
    String key,
  ) {
    if (node == null) return null;
    if (node is YamlScalar) {
      final v = node.value;
      if (v == null) {
        reader.error('expected a pattern', key: key);
        return null;
      }
      return fromString('$v', onError: (m) => reader.error(m, key: key));
    }
    if (node is YamlList) {
      final items = <StringPattern>[];
      for (final item in node.nodes) {
        final pat = fromNode(item, reader, key);
        if (pat != null) items.add(pat);
      }
      return AnyOfPattern(items);
    }
    if (node is YamlMap) {
      final sub = YamlReader(node, reader.childPath(key), reader.errors);
      sub.rejectUnknownKeys(['not', 'style', 'not_style']);
      final style = sub.string('style');
      final notStyle = sub.string('not_style');
      if (style != null || notStyle != null) {
        final name = style ?? notStyle!;
        final regex = styles[name];
        if (regex == null) {
          sub.error(
            'unknown style "$name"',
            key: style != null ? 'style' : 'not_style',
            hint: 'allowed: ${styles.keys.join(', ')}',
          );
          return null;
        }
        final pat = RegexPattern(regex);
        return style != null ? pat : NotPattern(pat);
      }
      final inner = fromNode(node.nodes['not'], sub, 'not');
      if (inner == null) return null;
      return NotPattern(inner);
    }
    reader.error('expected a pattern', key: key);
    return null;
  }

  /// Identifier styles usable as `{ style: snake_case }` / `{ not_style: .. }`.
  static final styles = <String, RegExp>{
    'snake_case': RegExp(r'^_?[a-z][a-z0-9]*(_[a-z0-9]+)*$'),
    'camelCase': RegExp(r'^_?[a-z][a-zA-Z0-9]*$'),
    'PascalCase': RegExp(r'^_?[A-Z][a-zA-Z0-9]*$'),
    'SCREAMING_SNAKE_CASE': RegExp(r'^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$'),
  };

  static StringPattern fromString(
    String text, {
    void Function(String message)? onError,
  }) {
    if (text.length >= 2 && text.startsWith('/') && text.endsWith('/')) {
      try {
        return RegexPattern(RegExp(text.substring(1, text.length - 1)));
      } on FormatException catch (e) {
        onError?.call('invalid regex: ${e.message}');
        return ExactPattern(text);
      }
    }
    if (text.contains('*') || text.contains('?')) return GlobPattern(text);
    return ExactPattern(text);
  }
}

class ExactPattern extends StringPattern {
  ExactPattern(this.text);
  final String text;

  @override
  bool matches(String input) => input == text;

  @override
  String describe() => text;
}

class GlobPattern extends StringPattern {
  GlobPattern(this.glob) : regex = _toRegex(glob);
  final String glob;
  final RegExp regex;

  static RegExp _toRegex(String glob) {
    final sb = StringBuffer('^');
    for (final ch in glob.split('')) {
      switch (ch) {
        case '*':
          sb.write('.*');
        case '?':
          sb.write('.');
        default:
          sb.write(RegExp.escape(ch));
      }
    }
    sb.write(r'$');
    return RegExp(sb.toString());
  }

  @override
  bool matches(String input) => regex.hasMatch(input);

  @override
  String describe() => glob;
}

class RegexPattern extends StringPattern {
  RegexPattern(this.regex);
  final RegExp regex;

  @override
  bool matches(String input) => regex.hasMatch(input);

  @override
  String describe() => '/${regex.pattern}/';
}

class AnyOfPattern extends StringPattern {
  AnyOfPattern(this.patterns);
  final List<StringPattern> patterns;

  @override
  bool matches(String input) => patterns.any((p) => p.matches(input));

  @override
  String describe() => '[${patterns.map((p) => p.describe()).join(', ')}]';
}

class NotPattern extends StringPattern {
  NotPattern(this.inner);
  final StringPattern inner;

  @override
  bool matches(String input) => !inner.matches(input);

  @override
  String describe() => 'not ${inner.describe()}';
}
