import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config/values.dart';

/// Everything a matcher may need about the file being analyzed.
class MatchContext {
  MatchContext({
    required this.result,
    required this.relativePath,
    required this.rootPath,
    required this.packageName,
    required this.values,
  });

  final ResolvedUnitResult result;

  /// Project-relative posix path of the file.
  final String relativePath;
  final String rootPath;

  /// The analyzed package's name; used by `package: project`.
  final String? packageName;
  final Map<String, ValueList> values;

  CompilationUnit get unit => result.unit;
  LineInfo get lineInfo => result.lineInfo;
  String get content => result.content;
  String get path => result.path;

  /// Source text of [node], whitespace collapsed, truncated for messages.
  String sourceOf(AstNode node, {int max = 120}) {
    var text = content.substring(node.offset, node.end);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > max) text = '${text.substring(0, max - 1)}…';
    return text;
  }
}
