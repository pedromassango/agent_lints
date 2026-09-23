import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:yaml/yaml.dart';

import '../config/yaml_reader.dart';
import '../match/patterns.dart';
import 'names.dart';

/// A `type:` constraint. Subtype check by default, `exact: true` to disable.
class TypePattern {
  TypePattern({required this.name, this.package, this.exact = false});

  final StringPattern name;
  final StringPattern? package;
  final bool exact;

  static TypePattern? fromNode(YamlNode? node, YamlReader reader, String key) {
    if (node == null) return null;
    if (node is YamlMap) {
      final r = YamlReader(node, reader.childPath(key), reader.errors);
      r.rejectUnknownKeys(['name', 'exact', 'package']);
      final exactNode = node.nodes['exact'];
      final name = StringPattern.fromNode(
        node.nodes['name'] ?? exactNode,
        r,
        node.nodes['name'] != null ? 'name' : 'exact',
      );
      if (name == null) {
        r.error('type needs "name" or "exact"');
        return null;
      }
      return TypePattern(
        name: name,
        package: StringPattern.fromNode(node.nodes['package'], r, 'package'),
        exact: exactNode != null && node.nodes['name'] == null,
      );
    }
    final name = StringPattern.fromNode(node, reader, key);
    return name == null ? null : TypePattern(name: name);
  }

  bool matches(DartType? type) {
    if (type == null) return false;
    if (type is InterfaceType) {
      if (_matchesElement(type.element)) return true;
      if (exact) return false;
      for (final st in type.element.allSupertypes) {
        if (_matchesElement(st.element)) return true;
      }
      return false;
    }
    return package == null && name.matches(type.getDisplayString());
  }

  bool _matchesElement(InterfaceElement element) {
    final n = element.name;
    if (n == null || !name.matches(n)) return false;
    final pkg = package;
    if (pkg == null) return true;
    final elementPackage = packageOfUri(element.library.uri.toString());
    return elementPackage != null && pkg.matches(elementPackage);
  }

  String describe() =>
      '${exact ? 'exactly ' : ''}${name.describe()}'
      '${package == null ? '' : ' from ${package!.describe()}'}';
}
