import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;

import '../match_context.dart';
import '../matcher.dart';
import '../node_kind.dart';
import '../patterns.dart';

/// `file:` — matches the compilation unit itself, by file name, path or
/// size. Reported at the first line. Used by `naming: { target: file }` and
/// by file-size rules, usually combined with `contains:`.
class FileMatcher extends Matcher {
  FileMatcher({
    this.name,
    this.path,
    this.maxLines,
    this.minLines,
    this.maxCodeLines,
    this.minCodeLines,
  });

  /// Base name without `.dart`.
  final StringPattern? name;

  /// Project-relative posix path.
  final StringPattern? path;

  /// Matches when the file has MORE than this many lines (a violation).
  final int? maxLines;
  final int? minLines;

  /// Same, counting only lines with code: blank and comment-only lines are
  /// excluded.
  final int? maxCodeLines;
  final int? minCodeLines;

  static const keys = [
    'name',
    'path',
    'max_lines',
    'min_lines',
    'max_code_lines',
    'min_code_lines',
  ];

  @override
  Set<NodeKind> get anchors => {NodeKind.file};

  @override
  MatchResult? match(AstNode node, MatchContext ctx) {
    if (node is! CompilationUnit) return null;
    final base = p.posix.basenameWithoutExtension(ctx.relativePath);
    if (name != null && !name!.matches(base)) return null;
    if (path != null && !path!.matches(ctx.relativePath)) return null;
    final lines =
        ctx.lineInfo.lineCount -
        (ctx.content.endsWith('\n') || ctx.content.isEmpty ? 1 : 0);
    final codeLines = countCodeLines(node, ctx);
    if (maxLines != null && lines <= maxLines!) return null;
    if (minLines != null && lines >= minLines!) return null;
    if (maxCodeLines != null && codeLines <= maxCodeLines!) return null;
    if (minCodeLines != null && codeLines >= minCodeLines!) return null;
    return MatchResult(node, {
      'name': base,
      'short_name': base,
      'lines': '$lines',
      'code_lines': '$codeLines',
    });
  }

  /// Lines that hold at least one non-comment token.
  static int countCodeLines(CompilationUnit unit, MatchContext ctx) {
    final seen = <int>{};
    for (Token? t = unit.beginToken; t != null; t = t.next) {
      if (t.type == TokenType.EOF) break;
      if (t.isSynthetic || t.lexeme.isEmpty) continue;
      final start = ctx.lineInfo.getLocation(t.offset).lineNumber;
      final end = ctx.lineInfo.getLocation(t.end).lineNumber;
      for (var l = start; l <= end; l++) {
        seen.add(l);
      }
    }
    return seen.length;
  }

  @override
  String describe() {
    final parts = <String>['file'];
    if (name != null) parts.add('name=${name!.describe()}');
    if (path != null) parts.add('path=${path!.describe()}');
    if (maxLines != null) parts.add('lines>$maxLines');
    if (minLines != null) parts.add('lines<$minLines');
    if (maxCodeLines != null) parts.add('code_lines>$maxCodeLines');
    if (minCodeLines != null) parts.add('code_lines<$minCodeLines');
    return parts.join(' ');
  }
}
