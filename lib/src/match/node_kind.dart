/// The AST node families a rule can anchor on. The YAML key is [key].
enum NodeKind {
  import('import'),
  call('call'),
  newExpr('new'),
  ref('ref'),
  classDecl('class'),
  function('function'),
  variable('variable'),
  literal('literal');

  const NodeKind(this.key);

  final String key;

  static NodeKind? fromKey(String key) {
    for (final k in values) {
      if (k.key == key) return k;
    }
    return null;
  }

  static Set<String> get keys => values.map((k) => k.key).toSet();
}
