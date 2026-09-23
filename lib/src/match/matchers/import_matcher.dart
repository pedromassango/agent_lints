import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

import '../../resolve/names.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';

/// `import:` — import and export directives.
class ImportMatcher extends Matcher {
  ImportMatcher({
    this.uri,
    this.package,
    this.relative,
    this.prefix,
    this.show,
    this.kind = 'import',
    this.deferred,
  });

  final StringPattern? uri;
  final StringPattern? package;
  final bool? relative;
  final StringPattern? prefix;
  final StringPattern? show;

  /// `import`, `export` or `any`.
  final String kind;
  final bool? deferred;

  static const keys = [
    'uri',
    'package',
    'relative',
    'prefix',
    'show',
    'kind',
    'deferred',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.import};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    final String uriText;
    final LibraryElement? library;
    final SimpleIdentifier? prefixNode;
    final List<Combinator> combinators;
    final bool isDeferred;
    switch (node) {
      case ImportDirective():
        if (kind == 'export') return null;
        uriText = node.uri.stringValue ?? '';
        library = node.libraryImport?.importedLibrary;
        prefixNode = node.prefix;
        combinators = node.combinators;
        isDeferred = node.deferredKeyword != null;
      case ExportDirective():
        if (kind == 'import') return null;
        uriText = node.uri.stringValue ?? '';
        library = node.libraryExport?.exportedLibrary;
        prefixNode = null;
        combinators = node.combinators;
        isDeferred = false;
      default:
        return null;
    }
    final captures = <String, String>{'uri': uriText};
    if (uri != null && !uri!.matches(uriText)) return null;
    final isRelative = !uriText.contains(':');
    if (relative != null && isRelative != relative) return null;
    final resolvedUri = library?.uri.toString();
    final pkg =
        packageOfUri(resolvedUri) ?? (isRelative ? ctx.packageName : null);
    if (package != null) {
      if (pkg == null) return null;
      final isProject = ctx.packageName != null && pkg == ctx.packageName;
      if (!(package!.matches(pkg) ||
          (isProject && package!.matches('project')))) {
        return null;
      }
    }
    if (prefix != null) {
      final name = prefixNode?.name;
      if (name == null || !prefix!.matches(name)) return null;
    }
    if (show != null) {
      final shown = combinators.whereType<ShowCombinator>().expand(
        (c) => c.shownNames.map((n) => n.name),
      );
      if (!shown.any(show!.matches)) return null;
    }
    if (deferred != null && isDeferred != deferred) return null;
    if (pkg != null) captures['package'] = pkg;
    if (resolvedUri != null) captures['library'] = resolvedUri;
    final fullPath = library?.firstFragment.source.fullName;
    if (fullPath != null && p.isWithin(ctx.rootPath, fullPath)) {
      captures['resolved_path'] = p.posix.joinAll(
        p.split(p.relative(fullPath, from: ctx.rootPath)),
      );
    }
    captures['name'] = uriText;
    return MatchResult(node, captures);
  }

  @override
  String describe() {
    final parts = <String>[kind];
    if (uri != null) parts.add('uri=${uri!.describe()}');
    if (package != null) parts.add('package=${package!.describe()}');
    if (relative != null) parts.add('relative=$relative');
    if (prefix != null) parts.add('prefix=${prefix!.describe()}');
    if (show != null) parts.add('show=${show!.describe()}');
    return parts.join(' ');
  }
}
