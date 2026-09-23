import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../match/matchers/ref_matcher.dart';
import '../match/node_kind.dart';

/// Walks a subtree and reports every node that can anchor a rule, with its
/// [NodeKind]. Shared by the engine and by `contains:` constraints.
class KindVisitor extends RecursiveAstVisitor<void> {
  KindVisitor(this.onNode);

  final void Function(NodeKind kind, AstNode node) onNode;

  @override
  void visitImportDirective(ImportDirective node) {
    onNode(NodeKind.import, node);
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    onNode(NodeKind.import, node);
    super.visitExportDirective(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onNode(NodeKind.call, node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    onNode(NodeKind.call, node);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    onNode(NodeKind.newExpr, node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    onNode(NodeKind.ref, node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    onNode(NodeKind.ref, node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (RefMatcher.isReferenceSite(node)) onNode(NodeKind.ref, node);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    onNode(NodeKind.classDecl, node);
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    onNode(NodeKind.classDecl, node);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    onNode(NodeKind.classDecl, node);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    onNode(NodeKind.classDecl, node);
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    onNode(NodeKind.function, node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    onNode(NodeKind.function, node);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    onNode(NodeKind.function, node);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    onNode(NodeKind.variable, node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitDoubleLiteral(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    onNode(NodeKind.literal, node);
    super.visitStringInterpolation(node);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitBooleanLiteral(node);
  }

  @override
  void visitNullLiteral(NullLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitNullLiteral(node);
  }

  @override
  void visitListLiteral(ListLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitListLiteral(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    onNode(NodeKind.literal, node);
    super.visitSetOrMapLiteral(node);
  }
}
