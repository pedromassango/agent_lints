import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

/// A constant value extracted from an expression. Only primitives are
/// represented; anything else is "not a constant" for matching purposes.
class ConstValue {
  ConstValue(this.value);

  /// `num`, `String`, `bool` or null (for the `null` literal).
  final Object? value;

  String render() {
    final v = value;
    if (v == null) return 'null';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

/// Evaluates literals and references to `const` variables.
ConstValue? constantValueOf(Expression? expr) {
  switch (expr) {
    case null:
      return null;
    case IntegerLiteral():
      return ConstValue(expr.value);
    case DoubleLiteral():
      return ConstValue(expr.value);
    case BooleanLiteral():
      return ConstValue(expr.value);
    case NullLiteral():
      return ConstValue(null);
    case StringLiteral():
      final s = expr.stringValue;
      return s == null ? null : ConstValue(s);
    case ParenthesizedExpression():
      return constantValueOf(expr.expression);
    case PrefixExpression():
      if (expr.operator.lexeme == '-') {
        final inner = constantValueOf(expr.operand);
        final v = inner?.value;
        if (v is num) return ConstValue(-v);
      }
      return null;
    case Identifier():
      return _fromElement(expr.element);
    case PropertyAccess():
      return _fromElement(expr.propertyName.element);
    default:
      return null;
  }
}

ConstValue? _fromElement(Element? element) {
  DartObject? object;
  if (element is PropertyAccessorElement) {
    object = element.variable.computeConstantValue();
  } else if (element is VariableElement) {
    object = element.computeConstantValue();
  }
  if (object == null) return null;
  final i = object.toIntValue();
  if (i != null) return ConstValue(i);
  final d = object.toDoubleValue();
  if (d != null) return ConstValue(d);
  final s = object.toStringValue();
  if (s != null) return ConstValue(s);
  final b = object.toBoolValue();
  if (b != null) return ConstValue(b);
  if (object.isNull) return ConstValue(null);
  return null;
}

/// Kind name of a literal expression, or null when [expr] is not a literal.
String? literalKindOf(Expression expr) {
  return switch (expr) {
    IntegerLiteral() => 'int',
    DoubleLiteral() => 'double',
    StringLiteral() => 'string',
    BooleanLiteral() => 'bool',
    NullLiteral() => 'null',
    ListLiteral() => 'list',
    SetOrMapLiteral() => expr.isMap ? 'map' : 'set',
    ParenthesizedExpression() => literalKindOf(expr.expression),
    PrefixExpression() when expr.operator.lexeme == '-' => literalKindOf(
      expr.operand,
    ),
    _ => null,
  };
}

bool literalKindMatches(String wanted, String actual) {
  if (wanted == 'any') return true;
  if (wanted == 'num') return actual == 'int' || actual == 'double';
  return wanted == actual;
}
