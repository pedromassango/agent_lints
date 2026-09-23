import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';

/// `file:` — matches the compilation unit itself, by file name or path.
/// Reported at the first line. Used by `naming: { target: file }`.
class FileMatcher extends Matcher {
  FileMatcher({this.name, this.path});

  /// Base name without `.dart`.
  final StringPattern? name;

  /// Project-relative posix path.
  final StringPattern? path;

  static const keys = ['name', 'path'];

  @override
  Set<NodeKind> get anchors => {NodeKind.file};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    if (node is! CompilationUnit) return null;
    final base = p.posix.basenameWithoutExtension(ctx.relativePath);
    if (name != null && !name!.matches(base)) return null;
    if (path != null && !path!.matches(ctx.relativePath)) return null;
    return MatchResult(node, {'name': base, 'short_name': base});
  }

  @override
  String describe() =>
      'file'
      '${name == null ? '' : ' name=${name!.describe()}'}'
      '${path == null ? '' : ' path=${path!.describe()}'}';
}
