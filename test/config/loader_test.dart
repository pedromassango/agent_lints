import 'package:agent_lints/agent_lints.dart';
import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('ConfigLoader', () {
    test('loads a minimal valid config', () {
      final config = ConfigLoader().load(
        content: rule('no_print', '''
    match: { call: { name: print, package: dart:core } }
    message: no print
'''),
        configPath: '/tmp/agent_lints.yaml',
        rootPath: '/tmp',
      );
      expect(config.rules, hasLength(1));
      expect(config.rules.single.id, 'no_print');
      expect(config.rules.single.severity, Severity.warning);
      expect(config.failOn, Severity.warning);
    });

    test('requires version', () {
      final errors = configErrors('rules: {}\n');
      expect(errors.single.message, contains('version'));
      expect(errors.single.hint, contains('version: 1'));
    });

    test('rejects unknown top-level keys with did-you-mean', () {
      final errors = configErrors('version: 1\nrulez: {}\nrules: {}\n');
      expect(errors.single.message, 'unknown key "rulez"');
      expect(errors.single.hint, 'did you mean "rules"?');
      expect(errors.single.format(), startsWith('/tmp/agent_lints.yaml:2:1'));
    });

    test('reports every error, not just the first', () {
      final errors = configErrors(
        rule('bad', '''
    match: { call: { nmae: print } }
    severty: error
    message: "hi {{nope}}"
'''),
      );
      final messages = errors.map((e) => e.format()).join('\n');
      expect(
        messages,
        contains(
          'rules.bad.match.call.nmae: unknown key "nmae" (did you mean "name"?)',
        ),
      );
      expect(
        messages,
        contains(
          'rules.bad.severty: unknown key "severty" (did you mean "severity"?)',
        ),
      );
      expect(
        messages,
        contains('rules.bad.message: unknown placeholder {{nope}}'),
      );
      expect(errors, hasLength(3));
    });

    test('a rule needs exactly one kind', () {
      final errors = configErrors(rule('r', '    message: x\n'));
      expect(
        errors.single.message,
        contains('exactly one of: match, banned, imports, naming'),
      );
      final two = configErrors(
        rule('r', '''
    match: { call: print }
    banned: print
    message: x
'''),
      );
      expect(two.single.message, contains('only one kind'));
    });

    test('a matcher needs exactly one node key', () {
      final errors = configErrors(
        rule('r', '''
    match: { inside: { call: build } }
    message: x
'''),
      );
      expect(errors.single.message, contains('exactly one node key'));
      expect(errors.single.hint, contains('node keys: new, call, ref, import'));
    });

    test('rejects invalid rule ids and severities', () {
      final errors = configErrors('''
version: 1
rules:
  BadName:
    match: { call: print }
    severity: fatal
    message: x
''');
      final messages = errors.map((e) => e.message).toList();
      expect(messages, contains('invalid rule id "BadName"'));
      expect(messages, contains('invalid value "fatal"'));
    });

    test('unknown \$values reference is an error listing declared lists', () {
      final errors = configErrors('''
version: 1
values:
  spacing: [4, 8]
rules:
  r:
    match: { new: { name: EdgeInsets.all, args: { value: { not_in: \$radius } } } }
    message: x
''');
      expect(errors.single.message, 'unknown values list "\$radius"');
      expect(errors.single.hint, 'declared: spacing');
    });

    test('vars and values placeholders are accepted', () {
      final errors = configErrors('''
version: 1
values:
  spacing: [4, 8]
rules:
  r:
    match: { call: print }
    vars: { logger: AppLog }
    message: "use {{vars.logger}} or {{values.spacing}} {{args.0}}"
''');
      expect(errors, isEmpty);
    });

    test('not cannot be the root of a rule', () {
      final errors = configErrors(
        rule('r', '''
    match: { not: { call: print } }
    message: x
'''),
      );
      expect(errors.single.message, contains('"not" cannot be the root'));
    });

    test('invalid YAML is reported with a position', () {
      final errors = configErrors('version: 1\nrules:\n  a: [\n');
      expect(errors.single.message, startsWith('invalid YAML'));
      expect(errors.single.span, isNotNull);
    });
  });
}
