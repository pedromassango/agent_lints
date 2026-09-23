import 'package:yaml/yaml.dart';

import '../config/errors.dart';
import '../config/values.dart';
import '../config/yaml_reader.dart';
import '../resolve/types.dart';
import 'matcher.dart';
import 'matchers/args_matcher.dart';
import 'matchers/call_matcher.dart';
import 'matchers/context_matcher.dart';
import 'matchers/declaration_matchers.dart';
import 'matchers/element_filter.dart';
import 'matchers/file_matcher.dart';
import 'matchers/import_matcher.dart';
import 'matchers/literal_matcher.dart';
import 'matchers/logic_matchers.dart';
import 'matchers/new_matcher.dart';
import 'matchers/ref_matcher.dart';
import 'matchers/variable_matcher.dart';
import 'node_kind.dart';
import 'patterns.dart';

typedef NodeMatcherFactory =
    Matcher? Function(
      YamlNode body,
      YamlReader parent,
      String key,
      MatcherCompiler compiler,
    );

/// Turns a `match:` YAML tree into a [Matcher]. Node keys are looked up in
/// [factories]; adding a matcher kind is one entry there.
class MatcherCompiler {
  MatcherCompiler(
    this.errors,
    this.values, {
    Map<String, NodeMatcherFactory>? factories,
  }) : factories = factories ?? standardFactories();

  final ConfigErrors errors;
  final Map<String, ValueList> values;
  final Map<String, NodeMatcherFactory> factories;

  static const combinatorKeys = ['any', 'all', 'not'];

  static Map<String, NodeMatcherFactory> standardFactories() => {
    'new': _compileNew,
    'call': _compileCall,
    'ref': _compileRef,
    'import': _compileImport,
    'function': _compileFunction,
    'class': _compileClass,
    'variable': _compileVariable,
    'literal': _compileLiteral,
    'file': _compileFile,
  };

  Set<String> get nodeKeys => factories.keys.toSet();

  /// Compiles [node] at [path]. [allowNot] is false at a rule's root.
  /// [allowDirect] permits the `direct` key (only inside `inside:`).
  Matcher? compile(
    YamlNode node,
    String path, {
    bool allowNot = true,
    bool allowDirect = false,
    bool? Function()? directSink,
  }) {
    if (node is! YamlMap) {
      errors.add(
        'expected a map with one of: ${[...nodeKeys, ...combinatorKeys].join(', ')}',
        span: node.span,
        path: path,
      );
      return null;
    }
    final r = YamlReader(node, path, errors);
    final present = r.keys.toList();
    final nodeKeysHere = present.where(nodeKeys.contains).toList();
    final combos = present.where(combinatorKeys.contains).toList();
    final contextKeys = present.where(ContextMatcher.keys.contains).toList();
    final known = {
      ...nodeKeys,
      ...combinatorKeys,
      ...ContextMatcher.keys,
      if (allowDirect) 'direct',
    };
    r.rejectUnknownKeys(known);
    if (nodeKeysHere.length + combos.length != 1) {
      r.error(
        nodeKeysHere.isEmpty && combos.isEmpty
            ? 'a matcher needs exactly one node key'
            : 'a matcher can have only one node key, found: '
                  '${[...nodeKeysHere, ...combos].join(', ')}',
        hint: 'node keys: ${nodeKeys.join(', ')}; combinators: any, all, not',
      );
      return null;
    }
    Matcher? core;
    if (combos.isNotEmpty) {
      final key = combos.first;
      if (key == 'not') {
        if (!allowNot) {
          r.error(
            '"not" cannot be the root of a rule; it would match everything else',
            key: 'not',
          );
          return null;
        }
        final inner = compile(node.nodes['not']!, r.childPath('not'));
        core = inner == null ? null : NotMatcher(inner);
      } else {
        final list = node.nodes[key];
        if (list is! YamlList || list.isEmpty) {
          r.error('expected a non-empty list of matchers', key: key);
          return null;
        }
        final branches = <Matcher>[];
        for (var i = 0; i < list.nodes.length; i++) {
          final m = compile(
            list.nodes[i],
            '${r.childPath(key)}[$i]',
            allowNot: allowNot,
          );
          if (m != null) branches.add(m);
        }
        if (branches.length != list.nodes.length) return null;
        core = key == 'any' ? AnyMatcher(branches) : AllMatcher(branches);
      }
    } else {
      final key = nodeKeysHere.first;
      core = factories[key]!(node.nodes[key]!, r, key, this);
    }
    if (core == null) return null;
    if (contextKeys.isEmpty) return core;
    return ContextMatcher(
      core,
      inside: _insideList(node, r, 'inside'),
      notInside: _insideList(node, r, 'not_inside'),
      contains: _matcherList(node, r, 'contains'),
      notContains: _matcherList(node, r, 'not_contains'),
    );
  }

  List<InsideSpec> _insideList(YamlMap map, YamlReader r, String key) {
    final n = map.nodes[key];
    if (n == null) return const [];
    final items = n is YamlList ? n.nodes : [n];
    final out = <InsideSpec>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final path = items.length == 1
          ? r.childPath(key)
          : '${r.childPath(key)}[$i]';
      var direct = false;
      if (item is YamlMap && item.containsKey('direct')) {
        final d = item.nodes['direct']!.value;
        if (d is bool) {
          direct = d;
        } else {
          errors.add(
            'expected true or false',
            span: item.nodes['direct']!.span,
            path: '$path.direct',
          );
        }
      }
      final m = compile(item, path, allowDirect: true);
      if (m != null) out.add(InsideSpec(m, direct: direct));
    }
    return out;
  }

  List<Matcher> _matcherList(YamlMap map, YamlReader r, String key) {
    final n = map.nodes[key];
    if (n == null) return const [];
    final items = n is YamlList ? n.nodes : [n];
    final out = <Matcher>[];
    for (var i = 0; i < items.length; i++) {
      final path = items.length == 1
          ? r.childPath(key)
          : '${r.childPath(key)}[$i]';
      final m = compile(items[i], path);
      if (m != null) out.add(m);
    }
    return out;
  }

  ArgsMatcher? _args(YamlReader r, String path) => ArgsMatcher.fromNode(
    r.map.nodes['args'],
    r,
    'args',
    values,
    (node, p) => compile(node, p),
  );

  static Matcher? _compileNew(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(NewMatcher.keys);
    return NewMatcher(
      filter: ElementFilter.fromReader(r),
      isConst: r.boolean('const'),
      type: TypePattern.fromNode(r.map.nodes['type'], r, 'type'),
      args: c._args(r, r.path),
    );
  }

  static Matcher? _compileCall(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(CallMatcher.keys);
    TypePattern? onType;
    StringPattern? onName;
    final on = r.map.nodes['on'];
    if (on is YamlMap) {
      final onReader = YamlReader(on, r.childPath('on'), c.errors);
      onReader.rejectUnknownKeys(['type', 'name']);
      onType = TypePattern.fromNode(on.nodes['type'], onReader, 'type');
      onName = StringPattern.fromNode(on.nodes['name'], onReader, 'name');
    } else if (on != null) {
      onType = TypePattern.fromNode(on, r, 'on');
    }
    return CallMatcher(
      filter: ElementFilter.fromReader(r),
      onType: onType,
      onName: onName,
      returns: TypePattern.fromNode(r.map.nodes['returns'], r, 'returns'),
      awaited: r.boolean('await'),
      isStatic: r.boolean('static'),
      args: c._args(r, r.path),
    );
  }

  static Matcher? _compileRef(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(RefMatcher.keys);
    return RefMatcher(
      filter: ElementFilter.fromReader(r),
      type: TypePattern.fromNode(r.map.nodes['type'], r, 'type'),
    );
  }

  static Matcher? _compileImport(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'uri'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(ImportMatcher.keys);
    final kind = r.string('kind') ?? 'import';
    if (!const {'import', 'export', 'any'}.contains(kind)) {
      r.error(
        'invalid kind "$kind"',
        key: 'kind',
        hint: 'allowed: import, export, any',
      );
    }
    return ImportMatcher(
      uri: StringPattern.fromNode(r.map.nodes['uri'], r, 'uri'),
      package: StringPattern.fromNode(r.map.nodes['package'], r, 'package'),
      relative: r.boolean('relative'),
      prefix: StringPattern.fromNode(r.map.nodes['prefix'], r, 'prefix'),
      show: StringPattern.fromNode(r.map.nodes['show'], r, 'show'),
      kind: kind,
      deferred: r.boolean('deferred'),
    );
  }

  static Matcher? _compileFunction(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(FunctionMatcher.keys);
    return FunctionMatcher(
      name: StringPattern.fromNode(r.map.nodes['name'], r, 'name'),
      kind: StringPattern.fromNode(r.map.nodes['kind'], r, 'kind'),
      returns: TypePattern.fromNode(r.map.nodes['returns'], r, 'returns'),
      isAsync: r.boolean('async'),
      isStatic: r.boolean('static'),
      isConst: r.boolean('const'),
      hasOverride: r.boolean('override'),
      annotation: StringPattern.fromNode(
        r.map.nodes['annotation'],
        r,
        'annotation',
      ),
    );
  }

  static Matcher? _compileClass(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(ClassMatcher.keys);
    return ClassMatcher(
      name: StringPattern.fromNode(r.map.nodes['name'], r, 'name'),
      kind: StringPattern.fromNode(r.map.nodes['kind'], r, 'kind'),
      extendsType: TypePattern.fromNode(r.map.nodes['extends'], r, 'extends'),
      implementsType: TypePattern.fromNode(
        r.map.nodes['implements'],
        r,
        'implements',
      ),
      mixesIn: TypePattern.fromNode(r.map.nodes['mixes_in'], r, 'mixes_in'),
      isAbstract: r.boolean('abstract'),
      annotation: StringPattern.fromNode(
        r.map.nodes['annotation'],
        r,
        'annotation',
      ),
      has: c._matcherList(r.map, r, 'has'),
      lacks: c._matcherList(r.map, r, 'lacks'),
    );
  }

  static Matcher? _compileVariable(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(VariableMatcher.keys);
    final init = r.map.nodes['initializer'];
    return VariableMatcher(
      name: StringPattern.fromNode(r.map.nodes['name'], r, 'name'),
      scope: StringPattern.fromNode(r.map.nodes['scope'], r, 'scope'),
      type: TypePattern.fromNode(r.map.nodes['type'], r, 'type'),
      isConst: r.boolean('const'),
      isFinal: r.boolean('final'),
      isLate: r.boolean('late'),
      isStatic: r.boolean('static'),
      annotation: StringPattern.fromNode(
        r.map.nodes['annotation'],
        r,
        'annotation',
      ),
      initializer: init == null
          ? null
          : c.compile(init, r.childPath('initializer')),
    );
  }

  static Matcher? _compileLiteral(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'kind'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(LiteralMatcher.keys);
    final kind = r.string('kind');
    const kinds = {
      'int',
      'double',
      'num',
      'string',
      'bool',
      'null',
      'list',
      'map',
      'set',
      'any',
    };
    if (kind != null && !kinds.contains(kind)) {
      r.error(
        'invalid literal kind "$kind"',
        key: 'kind',
        hint: 'allowed: ${kinds.join(', ')}',
      );
    }
    List<Object?>? list(String k) {
      final n = r.map.nodes[k];
      if (n == null) return null;
      if (n is YamlScalar &&
          n.value is String &&
          (n.value as String).startsWith(r'$')) {
        final name = (n.value as String).substring(1);
        final vl = c.values[name];
        if (vl == null) {
          r.error('unknown values list "\$$name"', key: k);
          return null;
        }
        return vl.values.toList();
      }
      if (n is YamlList) return n.nodes.map((e) => e.value).toList();
      r.error('expected a list or a \$values reference', key: k);
      return null;
    }

    final sourceStr = r.string('source');
    RegExp? source;
    if (sourceStr != null) {
      final pat = StringPattern.fromString(sourceStr);
      source = pat is RegexPattern
          ? pat.regex
          : RegExp(RegExp.escape(sourceStr));
    }
    final minNode = r.map.nodes['min'];
    final maxNode = r.map.nodes['max'];
    return LiteralMatcher(
      kind: kind,
      value: r.map.nodes['value']?.value,
      inList: list('in'),
      notIn: list('not_in'),
      min: minNode?.value is num ? minNode!.value as num : null,
      max: maxNode?.value is num ? maxNode!.value as num : null,
      source: source,
      interpolated: r.boolean('interpolated'),
    );
  }

  static Matcher? _compileFile(
    YamlNode body,
    YamlReader parent,
    String key,
    MatcherCompiler c,
  ) {
    final r = YamlReader(
      bodyAsMap(body, 'name'),
      parent.childPath(key),
      c.errors,
    );
    r.rejectUnknownKeys(FileMatcher.keys);
    return FileMatcher(
      name: StringPattern.fromNode(r.map.nodes['name'], r, 'name'),
      path: StringPattern.fromNode(r.map.nodes['path'], r, 'path'),
    );
  }
}

/// Exposes node kinds for `explain --kinds`.
Set<NodeKind> allNodeKinds() => NodeKind.values.toSet();
