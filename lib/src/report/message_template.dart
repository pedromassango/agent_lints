/// A message with `{{placeholders}}`.
class MessageTemplate {
  MessageTemplate(this.source)
    : placeholders = _pattern
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet()
          .toList();

  static final _pattern = RegExp(r'\{\{\s*([A-Za-z_][\w.]*)\s*\}\}');

  final String source;
  final List<String> placeholders;

  /// Placeholders every rule can use.
  static const common = {
    'rule',
    'severity',
    'file',
    'line',
    'col',
    'found',
    'name',
    'short_name',
    'package',
    'library',
    'type',
    'kind',
    'receiver',
    'uri',
    'resolved_path',
    'denied',
    'arg',
    'value',
    'allowed',
    'closest',
    'closest.name',
    'closest.value',
    'enclosing_class',
    'enclosing_function',
    'ancestor',
    'use_instead',
    'docs',
    'description',
    'ignore',
  };

  /// Names of placeholders that are neither common nor declared under
  /// `vars:` / `values:` / `args.`.
  List<String> unknownPlaceholders({
    required Set<String> vars,
    required Set<String> values,
  }) {
    return placeholders.where((p) {
      if (common.contains(p)) return false;
      if (p.startsWith('args.')) return false;
      if (p.startsWith('vars.')) return !vars.contains(p.substring(5));
      if (p.startsWith('values.')) return !values.contains(p.substring(7));
      return true;
    }).toList();
  }

  String render(Map<String, String> data) {
    return source.replaceAllMapped(_pattern, (m) => data[m.group(1)!] ?? '');
  }

  /// First sentence, single line. Used for IDE / human output.
  String renderShort(Map<String, String> data) {
    final full = render(data).replaceAll(RegExp(r'\s+'), ' ').trim();
    final m = RegExp(r'^(.*?[.!?])(\s|$)').firstMatch(full);
    return m?.group(1) ?? full;
  }
}
