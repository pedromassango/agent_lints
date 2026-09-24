import 'package:agent_lints/agent_lints.dart';
import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  const spacingDart = '''
abstract final class AppSpacing {
  static const double sm = 8;
  static const md = 16.0;
  static const lg = -1 * 2; // not a literal: skipped
  static const String unit = 'px';
  static final int computed = 4 * 2; // not a literal: skipped
  final double instanceField = 99; // not static: skipped
}
const double kTop = 4;
''';

  test('values from a class become named entries', () async {
    final project = await TestProject.create(
      yaml: '''
version: 1
values:
  spacing: { from: lib/theme/spacing.dart, class: AppSpacing }
  top: { from: lib/theme/spacing.dart }
rules:
  r:
    match: { new: { name: EdgeInsets.all, args: { value: { literal: num, not_in: \$spacing } } } }
    message: "{{value}} off scale. Allowed: {{allowed}}. Closest: {{closest.name}}."
''',
      files: {
        'lib/theme/spacing.dart': spacingDart,
        'lib/a.dart':
            "import 'package:flutter/material.dart';\nfinal a = EdgeInsets.all(10);\nfinal b = EdgeInsets.all(8);\n",
      },
    );
    try {
      final warnings = <ConfigError>[];
      final config = project.loadConfig(warnings: warnings);
      expect(
        config.values['spacing']!.render(),
        '8 (AppSpacing.sm), 16 (AppSpacing.md), px (AppSpacing.unit)',
      );
      expect(config.values['top']!.render(), '4 (kTop)');
      expect(warnings, isEmpty);
      final v = (await project.check()).violations;
      expect(
        v.single.message,
        '10 off scale. Allowed: 8 (AppSpacing.sm), 16 (AppSpacing.md), px (AppSpacing.unit). Closest: AppSpacing.sm.',
      );
    } finally {
      await project.dispose();
    }
  });

  test('missing file, unknown class and empty class are reported', () async {
    final project = await TestProject.create(
      yaml: '''
version: 1
values:
  a: { from: lib/nope.dart, class: X }
  b: { from: lib/theme/spacing.dart, class: Nope }
  c: { from: lib/theme/empty.dart, class: Empty }
rules: {}
''',
      files: {
        'lib/theme/spacing.dart': spacingDart,
        'lib/theme/empty.dart': 'class Empty { static const list = [1]; }\n',
      },
    );
    try {
      expect(
        () => project.loadConfig(),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.errors.map((x) => x.message).toList(),
            'messages',
            [
              'file not found: lib/nope.dart',
              'class Nope not found in lib/theme/spacing.dart (classes: AppSpacing)',
            ],
          ),
        ),
      );
    } finally {
      await project.dispose();
    }
    final warnProject = await TestProject.create(
      yaml:
          'version: 1\nvalues:\n  c: { from: lib/e.dart, class: Empty }\nrules: {}\n',
      files: {'lib/e.dart': 'class Empty { static const list = [1]; }\n'},
    );
    try {
      final warnings = <ConfigError>[];
      warnProject.loadConfig(warnings: warnings);
      expect(
        warnings.single.message,
        contains('no static const number or string fields found in Empty'),
      );
    } finally {
      await warnProject.dispose();
    }
  });
}
