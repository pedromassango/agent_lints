import 'package:agent_lints/agent_lints.dart';
import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('ConfigLoader', () {
    test('loads a minimal valid config', () {
      final config = ConfigLoader().load(
        content: rule('no_print', '''
    call: print
    package: dart:core
    message: no print
'''),
        configPath: '/tmp/agent_lints.yaml',
        rootPath: '/tmp',
      );
      expect(config.rules, hasLength(1));
      expect(config.rules.single.id, 'no_print');
      expect(config.rules.single.kind, 'call');
      expect(config.rules.single.severity, Severity.warning);
      expect(config.failOn, Severity.warning);
    });

    test('message defaults to a sentence built from use_instead', () {
      final config = ConfigLoader().load(
        content: rule(
          'no_print',
          '    use: print\n    use_instead: AppLog.d\n',
        ),
        configPath: '/tmp/agent_lints.yaml',
        rootPath: '/tmp',
      );
      expect(
        config.rules.single.message.source,
        '`{{found}}` is not allowed here. Use {{use_instead}}.',
      );
    });

    test('requires version 2 and explains version 1', () {
      final errors = configErrors('rules: {}\n');
      expect(errors.single.message, contains('version'));
      final old = configErrors('version: 1\nrules: {}\n');
      expect(old.single.hint, contains('flat rule form'));
    });

    test('rejects unknown top-level keys with did-you-mean', () {
      final errors = configErrors('version: 2\nrulez: {}\nrules: {}\n');
      expect(errors.single.message, 'unknown key "rulez"');
      expect(errors.single.hint, 'did you mean "rules"?');
      expect(errors.single.format(), startsWith('/tmp/agent_lints.yaml:2:1'));
    });

    test('reports every error, not just the first', () {
      final errors = configErrors(
        rule('bad', '''
    call: print
    packge: dart:core
    severty: error
    message: "hi {{nope}}"
'''),
      );
      final messages = errors.map((e) => e.format()).join('\n');
      expect(
        messages,
        contains(
          'rules.bad.packge: unknown key "packge" (did you mean "package"?)',
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

    test('a rule needs exactly one node key', () {
      final errors = configErrors(rule('r', '    message: x\n'));
      expect(errors.single.message, contains('exactly one node key'));
      expect(errors.single.hint, contains('node keys: use, constructor, call'));
      final two = configErrors(
        rule('r', '    call: print\n    constructor: Text\n'),
      );
      expect(two.single.message, contains('only one node key'));
    });

    test('an attribute given twice is an error', () {
      final errors = configErrors(
        rule(
          'r',
          '    constructor: { name: Text, package: flutter }\n    package: flutter\n',
        ),
      );
      expect(
        errors.single.message,
        contains('given both inside "constructor" and next to it'),
      );
    });

    test('rejects invalid rule ids and severities', () {
      final errors = configErrors('''
version: 2
rules:
  BadName:
    call: print
    severity: fatal
''');
      final messages = errors.map((e) => e.message).toList();
      expect(messages, contains('invalid rule id "BadName"'));
      expect(messages, contains('invalid value "fatal"'));
    });

    test('unknown \$values reference is an error listing declared lists', () {
      final errors = configErrors('''
version: 2
values:
  spacing: [4, 8]
rules:
  r:
    constructor: EdgeInsets.all
    args: { value: { not_in: \$radius } }
''');
      expect(errors.single.message, 'unknown values list "\$radius"');
      expect(errors.single.hint, 'declared: spacing');
    });

    test('vars and values placeholders are accepted', () {
      final errors = configErrors('''
version: 2
values:
  spacing: [4, 8]
rules:
  r:
    call: print
    vars: { logger: AppLog }
    message: "use {{vars.logger}} or {{values.spacing}} {{args.0}}"
''');
      expect(errors, isEmpty);
    });

    test('not cannot be the root of a rule', () {
      final errors = configErrors(rule('r', '    not: { call: print }\n'));
      expect(errors.single.message, contains('"not" cannot be the root'));
      expect(errors.single.message, contains('name: { not: "*Screen" }'));
    });

    test('invalid YAML is reported with a position', () {
      final errors = configErrors('version: 2\nrules:\n  a: [\n');
      expect(errors.single.message, startsWith('invalid YAML'));
      expect(errors.single.span, isNotNull);
    });
  });
}
