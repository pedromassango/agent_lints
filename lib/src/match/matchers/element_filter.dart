import 'package:analyzer/dart/element/element.dart';
import 'package:yaml/yaml.dart';

import '../../config/yaml_reader.dart';
import '../../resolve/names.dart';
import '../match_context.dart';
import '../patterns.dart';

/// Shared `name` / `package` / `library` filter for `call`, `new` and `ref`.
class ElementFilter {
  ElementFilter({this.name, this.package, this.library});

  final StringPattern? name;
  final StringPattern? package;
  final StringPattern? library;

  static const keys = ['name', 'package', 'library'];

  static ElementFilter fromReader(YamlReader r) {
    final map = r.map;
    return ElementFilter(
      name: StringPattern.fromNode(map.nodes['name'], r, 'name'),
      package: StringPattern.fromNode(map.nodes['package'], r, 'package'),
      library: StringPattern.fromNode(map.nodes['library'], r, 'library'),
    );
  }

  bool get isEmpty => name == null && package == null && library == null;

  /// Tests [element]; [fallbackName] is used when the element is unresolved.
  /// On success, fills name captures into [captures].
  bool matches(
    Element? element,
    MatchContext ctx,
    Map<String, String> captures, {
    String? fallbackName,
  }) {
    final resolved =
        ResolvedName.of(element) ??
        (fallbackName == null ? null : ResolvedName.unresolved(fallbackName));
    if (resolved == null) return false;
    final namePat = name;
    if (namePat != null && !resolved.candidates.any(namePat.matches)) {
      return false;
    }
    final pkgPat = package;
    if (pkgPat != null) {
      final pkg = resolved.package;
      if (pkg == null) return false;
      final isProject = ctx.packageName != null && pkg == ctx.packageName;
      final ok =
          pkgPat.matches(pkg) || (isProject && pkgPat.matches('project'));
      if (!ok) return false;
    }
    final libPat = library;
    if (libPat != null) {
      final uri = resolved.libraryUri;
      if (uri == null || !libPat.matches(uri)) return false;
    }
    captures['name'] = resolved.qualified;
    captures['short_name'] = resolved.short;
    if (resolved.package != null) captures['package'] = resolved.package!;
    if (resolved.libraryUri != null) captures['library'] = resolved.libraryUri!;
    return true;
  }

  String describe() {
    final parts = <String>[];
    if (name != null) parts.add('name=${name!.describe()}');
    if (package != null) parts.add('package=${package!.describe()}');
    if (library != null) parts.add('library=${library!.describe()}');
    return parts.isEmpty ? 'any' : parts.join(' ');
  }
}

/// Reads a node body that may be a bare string (shorthand for `name:`).
YamlMap bodyAsMap(YamlNode body, String shorthandKey) {
  if (body is YamlMap) return body;
  return YamlMap.wrap({shorthandKey: body.value});
}
