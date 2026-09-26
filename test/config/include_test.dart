import 'dart:io';

import 'package:agent_lints/agent_lints.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('include', () {
    test(
      'merges files in order; later wins; the main file wins last',
      () async {
        final project = await TestProject.create(
          yaml: '''
version: 2
include: [agent_lints/*.yaml]
rules:
  from_main: { use: print, from: dart:core, message: main }
  shared: { use: print, from: dart:core, severity: off }
''',
          files: {
            'agent_lints/a.yaml': '''
fail_on: error
values:
  spacing: [4, 8]
rules:
  shared: { use: print, from: dart:core, message: a, severity: error }
  only_a: { use: print, from: dart:core, message: a }
''',
            'agent_lints/b.yaml': '''
rules:
  only_a: { use: print, from: dart:core, message: b }
  uses_values:
    constructor: EdgeInsets.all
    args: { value: { not_in: \$spacing } }
    message: "{{allowed}}"
''',
          },
        );
        try {
          final config = project.loadConfig();
          final byId = {for (final r in config.rules) r.id: r};
          expect(
            byId.keys,
            containsAll(['from_main', 'shared', 'only_a', 'uses_values']),
          );
          expect(
            byId['only_a']!.message.source,
            'b',
            reason: 'b.yaml comes after a.yaml',
          );
          expect(byId['only_a']!.sourcePath, endsWith('agent_lints/b.yaml'));
          expect(
            byId['shared']!.severity,
            Severity.off,
            reason: 'main file wins',
          );
          expect(
            config.failOn,
            Severity.error,
            reason: 'set by an included file',
          );
          expect(config.values['spacing']!.render(), '4, 8');
          expect(config.sourcePaths.map((s) => p.basename(s)), [
            'a.yaml',
            'b.yaml',
            'agent_lints.yaml',
          ]);
        } finally {
          await project.dispose();
        }
      },
    );

    test('files, exclude and version rules', () async {
      final project = await TestProject.create(
        yaml:
            'version: 2\ninclude: [agent_lints/scope.yaml]\nexclude: [lib/z/**]\nrules: {}\n',
        files: {
          'agent_lints/scope.yaml':
              'version: 2\nfiles: [lib/features/**]\nexclude: [lib/legacy/**]\nrules:\n  r: { use: print, from: dart:core }\n',
        },
      );
      try {
        final config = project.loadConfig();
        expect(config.files.map((g) => g.pattern), ['lib/features/**']);
        expect(config.exclude.map((g) => g.pattern).take(2), [
          'lib/legacy/**',
          'lib/z/**',
        ]);
      } finally {
        await project.dispose();
      }
    });

    test('errors name the included file; empty globs warn', () async {
      final project = await TestProject.create(
        yaml:
            'version: 2\ninclude: [agent_lints/bad.yaml, agent_lints/none/*.yaml]\nrules: {}\n',
        files: {
          'agent_lints/bad.yaml':
              'version: 1\nrules:\n  r: { use: print, nope: 1 }\n',
        },
      );
      try {
        final warnings = <ConfigError>[];
        try {
          project.loadConfig(warnings: warnings);
          fail('expected errors');
        } on ConfigException catch (e) {
          final messages = e.errors.map((x) => x.format()).toList();
          expect(
            messages.any(
              (m) => m.contains(
                'agent_lints/bad.yaml:1:10 version: unsupported version 1',
              ),
            ),
            isTrue,
            reason: messages.join('\n'),
          );
          expect(
            messages.any(
              (m) => m.contains(
                'agent_lints/bad.yaml:3:20 rules.r.nope: unknown key "nope"',
              ),
            ),
            isTrue,
            reason: messages.join('\n'),
          );
          expect(e.sourcePaths, isNotEmpty);
        }
      } finally {
        await project.dispose();
      }
    });

    test('missing file, cycle and code globs are errors', () async {
      final project = await TestProject.create(
        yaml:
            'version: 2\ninclude: [agent_lints/missing.yaml, agent_lints/loop.yaml, lib/**]\nrules: {}\n',
        files: {
          'agent_lints/loop.yaml':
              'include: [../agent_lints.yaml]\nrules: {}\n',
        },
      );
      try {
        expect(
          () => project.loadConfig(),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.errors.map((x) => x.message).join('\n'),
              'messages',
              allOf(
                contains('included file not found: agent_lints/missing.yaml'),
                contains(
                  'include cycle: agent_lints.yaml -> agent_lints/loop.yaml -> agent_lints.yaml',
                ),
                contains(
                  '"include" lists other agent_lints files; use "files:" for the code to lint',
                ),
              ),
            ),
          ),
        );
      } finally {
        await project.dispose();
      }
    });

    test('package: URIs resolve through package_config.json', () async {
      final project = await TestProject.create(
        yaml: 'version: 2\ninclude: [package:http/lints.yaml]\nrules: {}\n',
        files: {
          'packages/http/lib/lints.yaml':
              'rules:\n  from_pkg: { use: print, from: dart:core }\n',
        },
      );
      try {
        final config = project.loadConfig();
        expect(config.rules.single.id, 'from_pkg');
        expect(
          config.rules.single.sourcePath,
          endsWith(p.join('packages', 'http', 'lib', 'lints.yaml')),
        );
      } finally {
        await project.dispose();
      }
    });

    test('rules from included files run end to end', () async {
      final v = await lint(
        'version: 2\ninclude: agent_lints/ui.yaml\nrules: {}\n',
        {
          'agent_lints/ui.yaml':
              'rules:\n  no_print: { use: print, from: dart:core, message: "from ui.yaml" }\n',
          'lib/a.dart': 'void f() { print(1); }\n',
        },
      );
      expect(v.single.message, 'from ui.yaml');
      expect(
        File(v.single.path).existsSync(),
        isFalse,
        reason: 'temp project removed',
      );
    });
  });
}
