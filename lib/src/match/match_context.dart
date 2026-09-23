import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';

import '../config/values.dart';

/// Everything a matcher may need about the file being analyzed.
class MatchContext {
  MatchContext({
    required this.unit,
    required this.content,
    required this.path,
    required this.relativePath,
    required this.rootPath,
    required this.packageName,
    required this.values,
  }) : lineInfo = unit.lineInfo;

  MatchContext.fromResult(
    ResolvedUnitResult result, {
    required String relativePath,
    required String rootPath,
    required String? packageName,
    required Map<String, ValueList> values,
  }) : this(
         unit: result.unit,
         content: result.content,
         path: result.path,
         relativePath: relativePath,
         rootPath: rootPath,
         packageName: packageName,
         values: values,
       );

  final CompilationUnit unit;
  final String content;
  final String path;
  final LineInfo lineInfo;

  /// Project-relative posix path of the file.
  final String relativePath;
  final String rootPath;

  /// The analyzed package's name; used by `package: project`.
  final String? packageName;
  final Map<String, ValueList> values;

  /// Source text of [node] without comments, whitespace collapsed, truncated
  /// for messages.
  String sourceOf(AstNode node, {int max = 120}) {
    final buffer = StringBuffer();
    var cursor = node.offset;
    for (var t = node.beginToken; ; t = t.next!) {
      for (Token? c = t.precedingComments; c != null; c = c.next) {
        if (c.offset >= cursor && c.end <= node.end) {
          buffer.write(content.substring(cursor, c.offset));
          cursor = c.end;
        }
      }
      if (t == node.endToken || t.next == null) break;
    }
    buffer.write(content.substring(cursor, node.end));
    var text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > max) text = '${text.substring(0, max - 1)}…';
    return text;
  }
}
