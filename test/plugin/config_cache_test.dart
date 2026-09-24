import 'dart:io';

import 'package:agent_lints/src/config/config.dart';
import 'package:agent_lints/src/plugin/agent_lints_rule.dart';
import 'package:agent_lints/src/plugin/config_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('agent_lints_cache_');
    void write(String rel, String content) {
      final f = File(p.join(root.path, rel));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(content);
    }

    write('pubspec.yaml', 'name: top\n');
    write('agent_lints.yaml', '''
version: 2
rules:
  top_rule: { severity: error, call: print, message: x }
''');
    write('packages/app/pubspec.yaml', 'name: app\n');
    write('packages/app/agent_lints.yaml', '''
version: 2
rules:
  app_rule: { call: print, message: x }
''');
    write('packages/broken/agent_lints.yaml', 'version: 2\nrules: []\n');
    write('build/agent_lints.yaml', 'version: 2\nrules: {}\n');
  });
  tearDown(() => root.delete(recursive: true));

  test('discover finds configs above and below, skipping build dirs', () {
    final cache = ConfigCache();
    final found = cache.discover(p.join(root.path, 'packages'));
    expect(
      found.map((f) => p.relative(f.configPath, from: root.path)).toSet(),
      {
        'agent_lints.yaml',
        'packages/app/agent_lints.yaml',
        'packages/broken/agent_lints.yaml',
      },
    );
    expect(cache.knownRuleIds, {'top_rule', 'app_rule'});
    expect(
      found.where((f) => f.errors.isNotEmpty).single.configPath,
      endsWith('packages/broken/agent_lints.yaml'),
    );
  });

  test('forFile picks the nearest config and reloads on change', () async {
    final cache = ConfigCache();
    final appFile = p.join(root.path, 'packages/app/lib/a.dart');
    expect(cache.forFile(appFile)!.config!.rules.single.id, 'app_rule');
    expect(
      cache.forFile(p.join(root.path, 'lib/a.dart'))!.config!.rules.single.id,
      'top_rule',
    );
    final same = cache.forFile(appFile);
    expect(identical(same, cache.forFile(appFile)), isTrue, reason: 'cached');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    File(p.join(root.path, 'packages/app/agent_lints.yaml')).writeAsStringSync(
      '''
version: 2
rules:
  renamed: { call: print, message: x }
''',
    );
    expect(cache.forFile(appFile)!.config!.rules.single.id, 'renamed');
  });

  test('rule codes carry the configured severity once discovered', () {
    final rule = AgentLintsRule();
    rule.discoverConfigs(root.path);
    final codes = {for (final c in rule.diagnosticCodes) c.lowerCaseName: c};
    expect(codes.keys, containsAll(['top_rule', 'app_rule', 'unused_ignore']));
    expect(codes['top_rule']!.severity.name, 'ERROR');
    expect(codes['app_rule']!.severity.name, 'WARNING');
    expect(
      rule.codeFor('top_rule', Severity.info).severity.name,
      'ERROR',
      reason: 'codes are created once per rule id',
    );
  });
}
