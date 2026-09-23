import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../../config/config.dart';
import '../../resolve/names.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';

/// One `deny:` entry of an `imports:` rule.
sealed class ImportDeny {
  static ImportDeny parse(String entry) {
    if (entry == 'relative') return RelativeDeny();
    if (entry.contains(':')) return UriDeny(StringPattern.fromString(entry));
    return PathDeny(compileGlob(entry));
  }

  String describe();
}

/// A `package:` / `dart:` URI glob, tested against the URI as written and the
/// resolved library URI.
class UriDeny extends ImportDeny {
  UriDeny(this.pattern);
  final StringPattern pattern;

  @override
  String describe() => pattern.describe();
}

/// A project path glob such as `lib/data/**`, tested against the resolved
/// target file.
class PathDeny extends ImportDeny {
  PathDeny(this.glob);
  final Glob glob;

  @override
  String describe() => glob.pattern;
}

class RelativeDeny extends ImportDeny {
  @override
  String describe() => 'relative';
}

/// `imports:` — layering rules. Engine-native because it needs resolved
/// target paths.
class ImportsRuleMatcher extends Matcher {
  ImportsRuleMatcher({required this.deny, this.replaceWith});

  final List<ImportDeny> deny;
  final String? replaceWith;

  @override
  Set<NodeKind> get anchors => {NodeKind.import};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    final String uriText;
    final LibraryElement? library;
    switch (node) {
      case ImportDirective():
        uriText = node.uri.stringValue ?? '';
        library = node.libraryImport?.importedLibrary;
      case ExportDirective():
        uriText = node.uri.stringValue ?? '';
        library = node.libraryExport?.exportedLibrary;
      default:
        return null;
    }
    final resolvedUri = library?.uri.toString();
    final fullPath = library?.firstFragment.source.fullName;
    String? resolvedPath;
    if (fullPath != null && p.isWithin(ctx.rootPath, fullPath)) {
      resolvedPath = p.posix.joinAll(
        p.split(p.relative(fullPath, from: ctx.rootPath)),
      );
    }
    final isRelative = !uriText.contains(':');
    ImportDeny? hit;
    for (final d in deny) {
      final matched = switch (d) {
        RelativeDeny() => isRelative,
        UriDeny() =>
          d.pattern.matches(uriText) ||
              (resolvedUri != null && d.pattern.matches(resolvedUri)),
        PathDeny() => resolvedPath != null && d.glob.matches(resolvedPath),
      };
      if (matched) {
        hit = d;
        break;
      }
    }
    if (hit == null) return null;
    final pkg =
        packageOfUri(resolvedUri) ?? (isRelative ? ctx.packageName : null);
    return MatchResult(node, {
      'uri': uriText,
      'name': uriText,
      'package': ?pkg,
      'library': ?resolvedUri,
      'resolved_path': ?resolvedPath,
      'denied': hit.describe(),
      'use_instead': ?replaceWith,
    });
  }

  @override
  String describe() =>
      'imports deny ${deny.map((d) => d.describe()).join(', ')}'
      '${replaceWith == null ? '' : ' replace_with $replaceWith'}';
}
