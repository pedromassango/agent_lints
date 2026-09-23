import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'errors.dart';

/// Typed, span-aware accessors over a [YamlMap]. Every problem is recorded in
/// [errors] with the dotted [path] so agents get precise, fixable messages.
class YamlReader {
  YamlReader(this.map, this.path, this.errors);

  final YamlMap map;
  final String path;
  final ConfigErrors errors;

  SourceSpan get span => map.span;

  Iterable<String> get keys =>
      map.nodes.keys.map((k) => '${(k as YamlNode).value}');

  bool has(String key) => map.containsKey(key);

  YamlNode? node(String key) => map.nodes[key];

  String childPath(String key) => path.isEmpty ? key : '$path.$key';

  SourceSpan spanOf(String key) => map.nodes[key]?.span ?? map.span;

  /// Span of the key itself rather than its value.
  SourceSpan keySpan(String key) {
    for (final k in map.nodes.keys) {
      if (k is YamlNode && '${k.value}' == key) return k.span;
    }
    return spanOf(key);
  }

  void error(String message, {String? key, String? hint}) {
    errors.add(
      message,
      span: key == null ? map.span : spanOf(key),
      path: key == null ? path : childPath(key),
      hint: hint,
    );
  }

  /// Records an error for every key not in [allowed], with a did-you-mean hint.
  void rejectUnknownKeys(Iterable<String> allowed) {
    final allowedSet = allowed.toSet();
    for (final key in keys) {
      if (allowedSet.contains(key)) continue;
      final suggestion = didYouMean(key, allowedSet);
      errors.add(
        'unknown key "$key"',
        span: keySpan(key),
        path: childPath(key),
        hint: suggestion != null
            ? 'did you mean "$suggestion"?'
            : 'allowed keys: ${allowedSet.join(', ')}',
      );
    }
  }

  String? string(String key, {bool required = false}) {
    final n = map.nodes[key];
    if (n == null) {
      if (required) error('missing required key "$key"', key: key);
      return null;
    }
    final v = n.value;
    if (n is YamlScalar && v != null && v is! Map && v is! List) {
      return v.toString();
    }
    error('expected a string', key: key);
    return null;
  }

  /// Accepts a scalar or a list of scalars.
  List<String>? stringList(String key, {bool required = false}) {
    final n = map.nodes[key];
    if (n == null) {
      if (required) error('missing required key "$key"', key: key);
      return null;
    }
    if (n is YamlScalar) return n.value == null ? [] : ['${n.value}'];
    if (n is YamlList) {
      final out = <String>[];
      for (final item in n.nodes) {
        if (item is YamlScalar && item.value != null) {
          out.add('${item.value}');
        } else {
          errors.add(
            'expected a string',
            span: item.span,
            path: childPath(key),
          );
        }
      }
      return out;
    }
    error('expected a string or a list of strings', key: key);
    return null;
  }

  bool? boolean(String key) {
    final n = map.nodes[key];
    if (n == null) return null;
    final v = n.value;
    if (v is bool) return v;
    error('expected true or false', key: key);
    return null;
  }

  int? integer(String key) {
    final n = map.nodes[key];
    if (n == null) return null;
    final v = n.value;
    if (v is int) return v;
    error('expected an integer', key: key);
    return null;
  }

  YamlReader? child(String key, {bool required = false}) {
    final n = map.nodes[key];
    if (n == null) {
      if (required) error('missing required key "$key"', key: key);
      return null;
    }
    if (n is YamlMap) return YamlReader(n, childPath(key), errors);
    error('expected a map', key: key);
    return null;
  }

  /// Reads a value from a fixed set, e.g. severities.
  T? enumValue<T>(String key, Map<String, T> allowed) {
    final s = string(key);
    if (s == null) return null;
    final v = allowed[s];
    if (v == null) {
      error(
        'invalid value "$s"',
        key: key,
        hint: 'allowed: ${allowed.keys.join(', ')}',
      );
    }
    return v;
  }
}

/// Closest match by edit distance, or null when nothing is close enough.
String? didYouMean(String input, Iterable<String> candidates) {
  String? best;
  var bestScore = 3; // strictly less than this to count
  for (final c in candidates) {
    final d = _levenshtein(input.toLowerCase(), c.toLowerCase());
    if (d < bestScore) {
      bestScore = d;
      best = c;
    }
  }
  return best;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}
