import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'values.dart';

/// Result of reading a values list from Dart source.
class ClassValuesResult {
  ClassValuesResult({this.entries = const [], this.error, this.warning});

  final List<ValueEntry> entries;
  final String? error;
  final String? warning;
}

/// Reads `static const` fields (or top-level `const` variables) whose
/// initializer is a number or string literal, so a values list can come from
/// the code instead of being copied into YAML.
///
/// ```yaml
/// values:
///   spacing: { from: lib/theme/spacing.dart, class: AppSpacing }
/// ```
ClassValuesResult readClassValues({
  required String rootPath,
  required String from,
  String? className,
}) {
  final file = File(p.normalize(p.join(rootPath, from)));
  if (!file.existsSync()) {
    return ClassValuesResult(error: 'file not found: $from');
  }
  final String content;
  try {
    content = file.readAsStringSync();
  } on FileSystemException catch (e) {
    return ClassValuesResult(error: 'cannot read $from: ${e.message}');
  }
  final unit = parseString(content: content, throwIfDiagnostics: false).unit;
  final entries = <ValueEntry>[];

  void collect(VariableDeclarationList list, String? prefix) {
    if (!list.isConst && !list.isFinal) return;
    for (final v in list.variables) {
      final value = _literalValue(v.initializer);
      if (value == null) continue;
      final name = v.name.lexeme;
      entries.add(
        ValueEntry(value, name: prefix == null ? name : '$prefix.$name'),
      );
    }
  }

  if (className == null) {
    for (final d in unit.declarations) {
      if (d is TopLevelVariableDeclaration) collect(d.variables, null);
    }
  } else {
    ClassDeclaration? found;
    for (final d in unit.declarations) {
      if (d is ClassDeclaration && d.namePart.typeName.lexeme == className) {
        found = d;
        break;
      }
    }
    if (found == null) {
      final classes = unit.declarations
          .whereType<ClassDeclaration>()
          .map((c) => c.namePart.typeName.lexeme)
          .toList();
      return ClassValuesResult(
        error:
            'class $className not found in $from'
            '${classes.isEmpty ? '' : ' (classes: ${classes.join(', ')})'}',
      );
    }
    for (final m in found.body.members) {
      if (m is FieldDeclaration && m.isStatic) collect(m.fields, className);
    }
  }
  if (entries.isEmpty) {
    return ClassValuesResult(
      warning:
          'no static const number or string fields found in '
          '${className == null ? from : '$className ($from)'}',
    );
  }
  return ClassValuesResult(entries: entries);
}

Object? _literalValue(Expression? e) {
  return switch (e) {
    IntegerLiteral() => e.value,
    DoubleLiteral() => e.value,
    SimpleStringLiteral() => e.value,
    ParenthesizedExpression() => _literalValue(e.expression),
    PrefixExpression() when e.operator.lexeme == '-' => switch (_literalValue(
      e.operand,
    )) {
      final num n => -n,
      _ => null,
    },
    _ => null,
  };
}
