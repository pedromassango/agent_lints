/// A named list of allowed values declared under `values:` in the config.
class ValueList {
  ValueList(this.name, this.entries);

  final String name;
  final List<ValueEntry> entries;

  Iterable<Object> get values => entries.map((e) => e.value);

  /// Renders `4, 8 (AppSpacing.sm), 16` for messages.
  String render() => entries.map((e) => e.render()).join(', ');

  /// Nearest entries to [target], closest first.
  List<ValueEntry> closest(num target, {int count = 2}) {
    final numeric = entries.where((e) => e.value is num).toList()
      ..sort((a, b) {
        final da = ((a.value as num) - target).abs();
        final db = ((b.value as num) - target).abs();
        return da.compareTo(db);
      });
    return numeric.take(count).toList();
  }
}

class ValueEntry {
  ValueEntry(this.value, {this.name});

  /// A `num` or a `String`.
  final Object value;

  /// Optional symbolic name, e.g. `AppSpacing.sm`.
  final String? name;

  String render() => name == null ? _fmt(value) : '${_fmt(value)} ($name)';

  static String _fmt(Object v) {
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
