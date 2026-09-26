import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../match/compiled_rule.dart';
import '../match/matcher_compiler.dart';
import '../report/message_template.dart';
import 'config.dart';
import 'errors.dart';
import 'include_resolver.dart';
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
    'files',
    'exclude',
    'fail_on',
    'require_ignore_reason',
    'docs',
    'values',
    'rules',
  ];

  /// Keys that describe the rule rather than what it matches.
  static const ruleFieldKeys = [
    'severity',
    'description',
    'files',
    'exclude',
    'message',
    'use_instead',
    'hint',
    'docs',
    'vars',
    'examples',
  ];

  static final ruleIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Reads a file on disk; overridable for tests and the plugin.
  String Function(String path) readFile = (path) =>
      File(path).readAsStringSync();

  /// Loads the config at [configPath] (whose text is [content]) and every
  /// file it `include:`s, merging them the way `analysis_options.yaml` does:
  /// included files first, in order, the including file last, later
  /// definitions winning.
  AgentLintsConfig load({
    required String content,
    required String configPath,
    required String rootPath,
    String? packageName,
  }) {
    final errors = ConfigErrors();
    final docs = <_Document>[];
    _read(
      path: p.normalize(p.absolute(configPath)),
      content: content,
      rootPath: rootPath,
      chain: const [],
      isMain: true,
      errors: errors,
      out: docs,
    );
    final sourcePaths = docs.map((d) => d.path).toList();

    // Merge: later documents override earlier ones. Documents that failed to
    // parse are simply absent; their errors are reported with the rest.
    List<String>? files;
    final exclude = <String>[];
    Severity? failOn;
    bool? requireReason;
    String? docsPointer;
    final values = <String, ValueList>{};
    final ruleReaders = <String, ({YamlReader reader, String path})>{};
    for (final d in docs) {
      final root = d.root;
      final f = root.stringList('files');
      if (f != null) files = f;
      exclude.addAll(root.stringList('exclude') ?? const []);
      failOn = root.enumValue('fail_on', Severity.byName) ?? failOn;
      requireReason = root.boolean('require_ignore_reason') ?? requireReason;
      docsPointer = root.string('docs') ?? docsPointer;
      values.addAll(_values(root));
      final rulesReader = root.child('rules', required: d.isMain);
      if (rulesReader == null) continue;
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
        ruleReaders[id] = (reader: rr, path: d.path);
      }
    }
    final rules = <CompiledRule>[];
    for (final e in ruleReaders.entries) {
      final rule = _rule(e.key, e.value.reader, values, errors);
      if (rule != null) rules.add(rule.copyWith(sourcePath: e.value.path));
    }
    for (final w in errors.warnings) {
      warnings?.call(w);
    }
    errors.throwIfAny(sourcePaths: sourcePaths);
    return AgentLintsConfig(
      rootPath: rootPath,
      configPath: configPath,
      packageName: packageName,
      files: (files ?? AgentLintsConfig.defaultFiles).map(compileGlob).toList(),
      exclude: [
        ...exclude,
        ...AgentLintsConfig.alwaysExcluded,
      ].map(compileGlob).toList(),
      failOn: failOn ?? Severity.warning,
      requireIgnoreReason: requireReason ?? false,
      docs: docsPointer,
      values: values,
      rules: rules,
      sourcePaths: sourcePaths,
    );
  }

  /// Parses one file, resolves its `include:` entries depth-first (so they
  /// land before it in [out]), then appends the file itself.
  void _read({
    required String path,
    required String content,
    required String rootPath,
    required List<String> chain,
    required bool isMain,
    required ConfigErrors errors,
    required List<_Document> out,
  }) {
    YamlNode doc;
    try {
      doc = loadYamlNode(content, sourceUrl: Uri.file(path));
    } on YamlException catch (e) {
      errors.add('invalid YAML: ${e.message}', span: e.span);
      return;
    }
    if (doc is! YamlMap) {
      errors.add('the config must be a map', span: doc.span);
      return;
    }
    final root = YamlReader(doc, '', errors);
    root.rejectUnknownKeys(topLevelKeys);
    final version = root.integer('version');
    if (version == null) {
      if (isMain) {
        root.error('missing required key "version"', hint: 'add `version: 2`');
      }
    } else if (version != 2) {
      root.error(
        'unsupported version $version',
        key: 'version',
        hint: version == 1
            ? 'version 1 (the nested match: form) was replaced by the flat '
                  'rule form in agent_lints 0.2; see doc/rule-language.md'
            : 'only 2',
      );
    }
    final includes = root.stringList('include') ?? const [];
    final nextChain = [...chain, path];
    for (final entry in includes) {
      if (entry.endsWith('.dart') || entry.endsWith('/**') || entry == 'lib') {
        root.error(
          '"include" lists other agent_lints files; use "files:" for the '
          'code to lint',
          key: 'include',
        );
        continue;
      }
      final resolved = resolveInclude(
        entry,
        fromDir: p.dirname(path),
        rootPath: rootPath,
      );
      if (resolved.error != null) {
        root.error(resolved.error!, key: 'include');
        continue;
      }
      if (resolved.warning != null) {
        errors.warn(
          resolved.warning!,
          span: root.spanOf('include'),
          path: 'include',
        );
      }
      for (final included in resolved.paths) {
        if (nextChain.contains(included)) {
          root.error(
            'include cycle: ${[...nextChain, included].map((c) => p.relative(c, from: rootPath)).join(' -> ')}',
            key: 'include',
          );
          continue;
        }
        final String text;
        try {
          text = readFile(included);
        } on FileSystemException catch (e) {
          root.error(
            'cannot read ${p.relative(included, from: rootPath)}: ${e.message}',
            key: 'include',
          );
          continue;
        }
        _read(
          path: included,
          content: text,
          rootPath: rootPath,
          chain: nextChain,
          isMain: false,
          errors: errors,
          out: out,
        );
      }
    }
    out.add(_Document(root: root, path: path, isMain: isMain));
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
    final severity =
        r.enumValue('severity', Severity.byName) ?? Severity.warning;
    final useInstead = r.string('use_instead');
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

    final messageText =
        r.string('message') ??
        (useInstead == null
            ? '`{{found}}` is not allowed here.'
            : '`{{found}}` is not allowed here. Use {{use_instead}}.');
    final message = template('message', messageText);
    final hint = template('hint', r.string('hint'));
    final files = (r.stringList('files') ?? const []).map(compileGlob).toList();
    final exclude = (r.stringList('exclude') ?? const [])
        .map(compileGlob)
        .toList();

    final compiler = MatcherCompiler(errors, values);
    final matcher = compiler.compile(
      r,
      reservedKeys: ruleFieldKeys.toSet(),
      allowNot: false,
    );
    final nodeKey = r.keys.firstWhere(
      (k) =>
          MatcherCompiler.nodeKeys.contains(k) ||
          MatcherCompiler.combinatorKeys.contains(k),
      orElse: () => 'match',
    );
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
      kind: nodeKey,
      severity: severity,
      matcher: matcher,
      message: message,
      description: r.string('description'),
      hint: hint,
      useInstead: useInstead,
      docs: r.string('docs'),
      vars: vars,
      files: files,
      exclude: exclude,
      examplesBad: examplesBad,
      examplesGood: examplesGood,
    );
  }
}

class _Document {
  _Document({required this.root, required this.path, required this.isMain});
  final YamlReader root;
  final String path;
  final bool isMain;
}
