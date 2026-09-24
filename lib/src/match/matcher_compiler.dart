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
import 'matchers/imports_rule_matcher.dart';
import 'matchers/literal_matcher.dart';
import 'matchers/logic_matchers.dart';
import 'matchers/new_matcher.dart';
import 'matchers/ref_matcher.dart';
import 'matchers/variable_matcher.dart';
import 'patterns.dart';

/// Describes one node key: the keys its body accepts, the key a bare scalar
/// stands for, and how to build the matcher.
class NodeSpec {
  const NodeSpec({
    required this.key,
    required this.description,
    required this.bodyKeys,
    required this.build,
    this.shorthandKey = 'name',
    this.acceptsArgs = false,
  });

  final String key;
  final String description;

  /// Attribute keys that may appear in the node's map or as siblings.
  final List<String> bodyKeys;

  /// The attribute a bare value (`new: Container`) sets.
  final String shorthandKey;
  final bool acceptsArgs;
  final Matcher? Function(YamlReader body, MatcherCompiler compiler) build;
}

/// Turns a flat matcher map into a [Matcher].
///
/// A matcher map has exactly one node key (or one combinator), and may carry
/// the node's attributes, `args:` and context keys as siblings:
///
/// ```yaml
/// new: ListView
/// args: { shrinkWrap: absent }
/// parent: { new: Column }
/// ```
class MatcherCompiler {
  MatcherCompiler(this.errors, this.values);

  final ConfigErrors errors;
  final Map<String, ValueList> values;

  static const combinatorKeys = ['any', 'all', 'not'];

  static const contextKeys = [
    'parent',
    'inside',
    'not_inside',
    'contains',
    'not_contains',
    'except',
  ];

  static final Map<String, NodeSpec> specs = {for (final s in _specs) s.key: s};

  static Set<String> get nodeKeys => specs.keys.toSet();

  /// Every key a matcher map may contain, for did-you-mean hints.
  static Set<String> get allKeys => {
    ...nodeKeys,
    ...combinatorKeys,
    ...contextKeys,
    'args',
    for (final s in _specs) ...s.bodyKeys,
  };

  /// Compiles the matcher described by [reader]'s map. [reservedKeys] are
  /// sibling keys that belong to the caller (rule fields) and are ignored.
  /// [allowNot] is false at a rule's root.
  Matcher? compile(
    YamlReader reader, {
    Set<String> reservedKeys = const {},
    bool allowNot = true,
  }) {
    final map = reader.map;
    final present = reader.keys
        .where((k) => !reservedKeys.contains(k))
        .toList();
    final nodeKeysHere = present.where(nodeKeys.contains).toList();
    final combos = present.where(combinatorKeys.contains).toList();
    if (nodeKeysHere.length + combos.length != 1) {
      final found = [...nodeKeysHere, ...combos];
      reader.error(
        found.isEmpty
            ? 'a rule needs exactly one node key'
            : 'a rule can have only one node key, found: ${found.join(', ')}',
        hint:
            'node keys: ${nodeKeys.join(', ')}; combinators: ${combinatorKeys.join(', ')}',
      );
      return null;
    }
    Matcher? core;
    final Set<String> consumed;
    if (combos.isNotEmpty) {
      final key = combos.first;
      consumed = {key};
      if (key == 'not') {
        if (!allowNot) {
          reader.error(
            '"not" cannot be the root of a rule; a rule fires on a node, so '
            'anchor on the node and negate a property, e.g. '
            '`class: { extends: Widget }` with `name: { not: "*Screen" }`',
            key: 'not',
          );
          return null;
        }
        final inner = _sub(map.nodes['not']!, reader.childPath('not'));
        core = inner == null ? null : NotMatcher(inner);
      } else {
        final list = map.nodes[key];
        if (list is! YamlList || list.isEmpty) {
          reader.error('expected a non-empty list of matchers', key: key);
          return null;
        }
        final branches = <Matcher>[];
        for (var i = 0; i < list.nodes.length; i++) {
          final m = _sub(
            list.nodes[i],
            '${reader.childPath(key)}[$i]',
            allowNot: allowNot,
          );
          if (m != null) branches.add(m);
        }
        if (branches.length != list.nodes.length) return null;
        core = key == 'any' ? AnyMatcher(branches) : AllMatcher(branches);
      }
    } else {
      final key = nodeKeysHere.first;
      final spec = specs[key]!;
      final body = _nodeBody(reader, spec, present);
      consumed = {key, ...spec.bodyKeys, if (spec.acceptsArgs) 'args'};
      core = body == null ? null : spec.build(body, this);
    }
    // Anything else must be a context key.
    for (final k in present) {
      if (consumed.contains(k) || contextKeys.contains(k)) continue;
      final suggestion = didYouMean(k, {...allKeys, ...reservedKeys});
      errors.add(
        'unknown key "$k"',
        span: reader.keySpan(k),
        path: reader.childPath(k),
        hint: suggestion != null
            ? 'did you mean "$suggestion"?'
            : 'context keys: ${contextKeys.join(', ')}',
      );
    }
    if (core == null) return null;
    final except = _matcherList(map, reader, 'except');
    if (except.isNotEmpty) {
      core = AllMatcher([core, NotMatcher(AnyMatcher(except))]);
    }
    final inside = [
      ..._insideList(map, reader, 'parent', direct: true),
      ..._insideList(map, reader, 'inside', direct: false),
    ];
    final notInside = _insideList(map, reader, 'not_inside', direct: false);
    final contains = _matcherList(map, reader, 'contains');
    final notContains = _matcherList(map, reader, 'not_contains');
    if (inside.isEmpty &&
        notInside.isEmpty &&
        contains.isEmpty &&
        notContains.isEmpty) {
      return core;
    }
    return ContextMatcher(
      core,
      inside: inside,
      notInside: notInside,
      contains: contains,
      notContains: notContains,
    );
  }

  /// Builds the node's attribute map from its value plus sibling attributes.
  YamlReader? _nodeBody(
    YamlReader reader,
    NodeSpec spec,
    List<String> present,
  ) {
    final node = reader.map.nodes[spec.key]!;
    final merged = <Object?, Object?>{};
    if (node is YamlMap) {
      merged.addAll(node.value);
    } else if (node is YamlList) {
      merged[spec.shorthandKey] = node.value;
    } else if (node.value != null &&
        node.value != 'any' &&
        node.value != true) {
      merged[spec.shorthandKey] = node.value;
    }
    final accepted = {...spec.bodyKeys, if (spec.acceptsArgs) 'args'};
    for (final k in present) {
      if (k == spec.key || !accepted.contains(k)) continue;
      if (merged.containsKey(k)) {
        reader.error(
          '"$k" is given both inside "${spec.key}" and next to it',
          key: k,
        );
      }
      merged[k] = reader.map.nodes[k]!.value;
    }
    final map = _wrap(merged, node);
    final body = YamlReader(map, reader.childPath(spec.key), errors);
    body.rejectUnknownKeys(accepted);
    return body;
  }

  /// Compiles a nested matcher (context entry, combinator branch, `expr`).
  Matcher? _sub(YamlNode node, String path, {bool allowNot = true}) {
    if (node is! YamlMap) {
      errors.add(
        'expected a matcher map, e.g. { constructor: Column }',
        span: node.span,
        path: path,
      );
      return null;
    }
    return compile(YamlReader(node, path, errors), allowNot: allowNot);
  }

  List<InsideSpec> _insideList(
    YamlMap map,
    YamlReader r,
    String key, {
    required bool direct,
  }) {
    final n = map.nodes[key];
    if (n == null) return const [];
    final items = n is YamlList ? n.nodes : [n];
    final out = <InsideSpec>[];
    for (var i = 0; i < items.length; i++) {
      final path = items.length == 1
          ? r.childPath(key)
          : '${r.childPath(key)}[$i]';
      final m = _sub(items[i], path);
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
      final m = _sub(items[i], path);
      if (m != null) out.add(m);
    }
    return out;
  }

  ArgsMatcher? _args(YamlReader body) => ArgsMatcher.fromNode(
    body.map.nodes['args'],
    body,
    'args',
    values,
    (node, path) => _sub(node, path),
  );

  static YamlMap _wrap(Map<Object?, Object?> m, YamlNode original) {
    // Keep spans when nothing was merged, for better error positions.
    if (original is YamlMap && original.length == m.length) return original;
    return YamlMap.wrap(m);
  }

  static TypePattern? _type(YamlReader r, String key) =>
      TypePattern.fromNode(r.map.nodes[key], r, key);

  static StringPattern? _pat(YamlReader r, String key) =>
      StringPattern.fromNode(r.map.nodes[key], r, key);

  static final List<NodeSpec> _specs = [
    NodeSpec(
      key: 'use',
      description: 'any use of a symbol: constructor, call or reference',
      bodyKeys: ElementFilter.keys,
      build: (r, c) {
        final filter = ElementFilter.fromReader(r);
        if (filter.isEmpty) {
          r.error('use needs a name (string, list or { name, package })');
          return null;
        }
        return AnyMatcher([
          NewMatcher(filter: filter),
          CallMatcher(filter: filter),
          RefMatcher(filter: filter),
        ]);
      },
    ),
    NodeSpec(
      key: 'constructor',
      description: 'constructor calls',
      bodyKeys: NewMatcher.keys.where((k) => k != 'args').toList(),
      acceptsArgs: true,
      build: (r, c) => NewMatcher(
        filter: ElementFilter.fromReader(r),
        isConst: r.boolean('const'),
        type: _type(r, 'type'),
        args: c._args(r),
      ),
    ),
    NodeSpec(
      key: 'call',
      description: 'method and function calls',
      bodyKeys: CallMatcher.keys.where((k) => k != 'args').toList(),
      acceptsArgs: true,
      build: (r, c) {
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
          returns: _type(r, 'returns'),
          awaited: r.boolean('await'),
          isStatic: r.boolean('static'),
          args: c._args(r),
        );
      },
    ),
    NodeSpec(
      key: 'ref',
      description: 'references that are not calls (Colors.red, tear-offs)',
      bodyKeys: RefMatcher.keys,
      build: (r, c) => RefMatcher(
        filter: ElementFilter.fromReader(r),
        type: _type(r, 'type'),
      ),
    ),
    NodeSpec(
      key: 'import',
      description: 'import / export directives',
      bodyKeys: ImportMatcher.keys,
      shorthandKey: 'uri',
      build: (r, c) {
        final kind = r.string('kind') ?? 'import';
        if (!const {'import', 'export', 'any'}.contains(kind)) {
          r.error(
            'invalid kind "$kind"',
            key: 'kind',
            hint: 'allowed: import, export, any',
          );
        }
        if (r.has('from') && r.has('package')) {
          r.error(
            '"from" and "package" mean the same thing; keep one',
            key: 'package',
          );
        }
        return ImportMatcher(
          uri: _pat(r, 'uri'),
          package: _pat(r, r.has('from') ? 'from' : 'package'),
          relative: r.boolean('relative'),
          prefix: _pat(r, 'prefix'),
          show: _pat(r, 'show'),
          kind: kind,
          deferred: r.boolean('deferred'),
        );
      },
    ),
    NodeSpec(
      key: 'deny_imports',
      description:
          'imports of the listed uri globs, project paths or `relative`',
      bodyKeys: const ['deny', 'replace_with'],
      shorthandKey: 'deny',
      build: (r, c) {
        final deny = r.stringList('deny', required: true) ?? const [];
        if (deny.isEmpty) {
          r.error('deny_imports needs at least one entry', key: 'deny');
          return null;
        }
        return ImportsRuleMatcher(
          deny: deny.map(ImportDeny.parse).toList(),
          replaceWith: r.string('replace_with'),
        );
      },
    ),
    NodeSpec(
      key: 'class',
      description: 'class / mixin / enum / extension declarations',
      bodyKeys: ClassMatcher.keys,
      build: (r, c) => ClassMatcher(
        name: _pat(r, 'name'),
        kind: _pat(r, 'kind'),
        extendsType: _type(r, 'extends'),
        implementsType: _type(r, 'implements'),
        mixesIn: _type(r, 'mixes_in'),
        isAbstract: r.boolean('abstract'),
        annotation: _pat(r, 'annotation'),
        has: c._matcherList(r.map, r, 'has'),
        lacks: c._matcherList(r.map, r, 'lacks'),
      ),
    ),
    NodeSpec(
      key: 'function',
      description: 'function / method / constructor declarations',
      bodyKeys: FunctionMatcher.keys,
      build: (r, c) => FunctionMatcher(
        name: _pat(r, 'name'),
        kind: _pat(r, 'kind'),
        returns: _type(r, 'returns'),
        isAsync: r.boolean('async'),
        isStatic: r.boolean('static'),
        isConst: r.boolean('const'),
        hasOverride: r.boolean('override'),
        annotation: _pat(r, 'annotation'),
      ),
    ),
    NodeSpec(
      key: 'variable',
      description: 'top-level variables, fields, locals',
      bodyKeys: VariableMatcher.keys,
      build: (r, c) {
        final init = r.map.nodes['initializer'];
        return VariableMatcher(
          name: _pat(r, 'name'),
          scope: _pat(r, 'scope'),
          type: _type(r, 'type'),
          isConst: r.boolean('const'),
          isFinal: r.boolean('final'),
          isLate: r.boolean('late'),
          isStatic: r.boolean('static'),
          annotation: _pat(r, 'annotation'),
          initializer: init == null
              ? null
              : c._sub(init, r.childPath('initializer')),
        );
      },
    ),
    NodeSpec(
      key: 'literal',
      description: 'int / double / string / bool / null / list / map literals',
      bodyKeys: LiteralMatcher.keys,
      shorthandKey: 'kind',
      build: (r, c) {
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
      },
    ),
    NodeSpec(
      key: 'file',
      description: 'the file itself, reported at line 1',
      bodyKeys: FileMatcher.keys,
      build: (r, c) => FileMatcher(
        name: _pat(r, 'name'),
        path: _pat(r, 'path'),
        maxLines: r.integer('max_lines'),
        minLines: r.integer('min_lines'),
        maxCodeLines: r.integer('max_code_lines'),
        minCodeLines: r.integer('min_code_lines'),
      ),
    ),
  ];
}
