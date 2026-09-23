import 'package:yaml/yaml.dart';

import '../match/compiled_rule.dart';
import '../match/matcher.dart';
import '../match/matcher_compiler.dart';
import '../match/matchers/call_matcher.dart';
import '../match/matchers/element_filter.dart';
import '../match/matchers/logic_matchers.dart';
import '../match/matchers/new_matcher.dart';
import '../match/matchers/ref_matcher.dart';
import '../match/patterns.dart';
import '../report/message_template.dart';
import 'config.dart';
import 'errors.dart';
import 'values.dart';
import 'yaml_reader.dart';

/// Parses and validates `agent_lints.yaml`. Throws [ConfigException] with
/// every error found; never fails fast.
class ConfigLoader {
  ConfigLoader({this.warnings});

  /// Receives non-fatal problems.
  final void Function(ConfigError warning)? warnings;

  static const topLevelKeys = [
    'version',
    'include',
    'exclude',
    'fail_on',
    'require_ignore_reason',
    'docs',
    'values',
    'rules',
  ];

  static const ruleKindKeys = ['match', 'banned', 'imports', 'naming'];

  static const ruleKeys = [
    ...ruleKindKeys,
    'severity',
    'description',
    'files',
    'exclude',
    'message',
    'use_instead',
    'suggest',
    'docs',
    'vars',
    'fix',
    'examples',
  ];

  static final ruleIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  AgentLintsConfig load({
    required String content,
    required String configPath,
    required String rootPath,
    String? packageName,
  }) {
    final errors = ConfigErrors();
    YamlNode doc;
    try {
      doc = loadYamlNode(content, sourceUrl: Uri.file(configPath));
    } on YamlException catch (e) {
      errors.add('invalid YAML: ${e.message}', span: e.span);
      errors.throwIfAny();
      rethrow;
    }
    if (doc is! YamlMap) {
      errors.add('the config must be a map', span: doc.span);
      errors.throwIfAny();
    }
    final root = YamlReader(doc as YamlMap, '', errors);
    root.rejectUnknownKeys(topLevelKeys);
    final version = root.integer('version');
    if (version == null) {
      root.error('missing required key "version"', hint: 'add `version: 1`');
    } else if (version != 1) {
      root.error(
        'unsupported version $version',
        key: 'version',
        hint: 'only 1',
      );
    }
    final include =
        (root.stringList('include') ?? AgentLintsConfig.defaultInclude)
            .map(compileGlob)
            .toList();
    final exclude = <String>[
      ...(root.stringList('exclude') ?? const <String>[]),
      ...AgentLintsConfig.alwaysExcluded,
    ].map(compileGlob).toList();
    final failOn =
        root.enumValue('fail_on', Severity.byName) ?? Severity.warning;
    final requireReason = root.boolean('require_ignore_reason') ?? false;
    final docs = root.string('docs');
    final values = _values(root);

    final rules = <CompiledRule>[];
    final rulesReader = root.child('rules', required: true);
    if (rulesReader != null) {
      for (final id in rulesReader.keys) {
        final rr = rulesReader.child(id);
        if (rr == null) continue;
        if (!ruleIdPattern.hasMatch(id)) {
          rulesReader.error(
            'invalid rule id "$id"',
            key: id,
            hint:
                'use snake_case: letters, digits and underscores, starting with a letter',
          );
        }
        final rule = _rule(id, rr, values, errors);
        if (rule != null) rules.add(rule);
      }
    }
    for (final w in errors.warnings) {
      warnings?.call(w);
    }
    errors.throwIfAny();
    return AgentLintsConfig(
      rootPath: rootPath,
      configPath: configPath,
      packageName: packageName,
      include: include,
      exclude: exclude,
      failOn: failOn,
      requireIgnoreReason: requireReason,
      docs: docs,
      values: values,
      rules: rules,
    );
  }

  Map<String, ValueList> _values(YamlReader root) {
    final out = <String, ValueList>{};
    final vr = root.child('values');
    if (vr == null) return out;
    for (final name in vr.keys) {
      final node = vr.map.nodes[name];
      if (node is! YamlList) {
        vr.error('expected a list of values', key: name);
        continue;
      }
      final entries = <ValueEntry>[];
      for (final item in node.nodes) {
        final v = item.value;
        if (v is num || v is String) {
          entries.add(ValueEntry(v as Object));
        } else if (item is YamlMap) {
          final ir = YamlReader(item, vr.childPath(name), vr.errors);
          ir.rejectUnknownKeys(['value', 'name']);
          final value = item.nodes['value']?.value;
          if (value is num || value is String) {
            entries.add(ValueEntry(value as Object, name: ir.string('name')));
          } else {
            ir.error('entry needs a numeric or string "value"');
          }
        } else {
          vr.errors.add(
            'expected a number, a string or {value, name}',
            span: item.span,
            path: vr.childPath(name),
          );
        }
      }
      out[name] = ValueList(name, entries);
    }
    return out;
  }

  CompiledRule? _rule(
    String id,
    YamlReader r,
    Map<String, ValueList> values,
    ConfigErrors errors,
  ) {
    r.rejectUnknownKeys(ruleKeys);
    final kinds = r.keys.where(ruleKindKeys.contains).toList();
    if (kinds.length != 1) {
      r.error(
        kinds.isEmpty
            ? 'a rule needs exactly one of: ${ruleKindKeys.join(', ')}'
            : 'a rule can have only one kind, found: ${kinds.join(', ')}',
      );
      return null;
    }
    final kind = kinds.first;
    final severity =
        r.enumValue('severity', Severity.byName) ?? Severity.warning;
    final messageText = r.string('message', required: true);
    final vars = <String, String>{};
    final varsReader = r.child('vars');
    if (varsReader != null) {
      for (final k in varsReader.keys) {
        final v = varsReader.string(k);
        if (v != null) vars[k] = v;
      }
    }
    MessageTemplate? template(String key, String? text) {
      if (text == null) return null;
      final t = MessageTemplate(text);
      final unknown = t.unknownPlaceholders(
        vars: vars.keys.toSet(),
        values: values.keys.toSet(),
      );
      for (final u in unknown) {
        final suggestion = didYouMean(u, MessageTemplate.common);
        r.error(
          'unknown placeholder {{$u}}',
          key: key,
          hint: suggestion != null
              ? 'did you mean {{$suggestion}}?'
              : 'available: ${MessageTemplate.common.join(', ')}, vars.*, values.*, args.*',
        );
      }
      return t;
    }

    final message = template('message', messageText);
    final suggest = template('suggest', r.string('suggest'));
    final files = (r.stringList('files') ?? const []).map(compileGlob).toList();
    final exclude = (r.stringList('exclude') ?? const [])
        .map(compileGlob)
        .toList();

    final compiler = MatcherCompiler(errors, values);
    Matcher? matcher;
    switch (kind) {
      case 'match':
        matcher = compiler.compile(
          r.map.nodes['match']!,
          r.childPath('match'),
          allowNot: false,
        );
      case 'banned':
        matcher = _banned(r, errors);
      default:
        r.error(
          'rule kind "$kind" is not supported yet',
          key: kind,
          hint: 'use match or banned',
        );
    }
    var examplesBad = const <String>[];
    var examplesGood = const <String>[];
    final ex = r.child('examples');
    if (ex != null) {
      ex.rejectUnknownKeys(['bad', 'good']);
      examplesBad = ex.stringList('bad') ?? const [];
      examplesGood = ex.stringList('good') ?? const [];
    }
    if (matcher == null || message == null) return null;
    return CompiledRule(
      id: id,
      kind: kind,
      severity: severity,
      matcher: matcher,
      message: message,
      description: r.string('description'),
      suggest: suggest,
      useInstead: r.string('use_instead'),
      docs: r.string('docs'),
      vars: vars,
      files: files,
      exclude: exclude,
      examplesBad: examplesBad,
      examplesGood: examplesGood,
    );
  }

  /// `banned: X` expands to `any: [new X, call X, ref X]`.
  Matcher? _banned(YamlReader r, ConfigErrors errors) {
    final node = r.map.nodes['banned']!;
    final YamlMap body;
    if (node is YamlMap) {
      body = node;
    } else {
      body = YamlMap.wrap({'name': node.value});
    }
    final br = YamlReader(body, r.childPath('banned'), errors);
    br.rejectUnknownKeys(ElementFilter.keys);
    final filter = ElementFilter.fromReader(br);
    if (filter.name == null) {
      br.error('banned needs a name (string, list or {name, package})');
      return null;
    }
    return AnyMatcher([
      NewMatcher(filter: filter),
      CallMatcher(filter: filter),
      RefMatcher(filter: filter),
    ]);
  }
}

/// Re-exported for callers that only need pattern parsing.
typedef Pattern = StringPattern;
