import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  test('inline values lists render and drive {{allowed}}', () async {
    final project = await TestProject.create(
      yaml: '''
version: 2
values:
  spacing: [4, { value: 8, name: AppSpacing.sm }]
rules:
  r:
    constructor: EdgeInsets.all
    args: { value: { literal: num, not_in: \$spacing } }
    message: "{{value}} off scale. Allowed: {{allowed}}."
''',
      files: {
        'lib/a.dart':
            "import 'package:flutter/material.dart';\nfinal a = EdgeInsets.all(10);\n",
      },
    );
    try {
      final config = project.loadConfig();
      expect(config.values['spacing']!.render(), '4, 8 (AppSpacing.sm)');
      final v = (await project.check()).violations;
      expect(v.single.message, '10 off scale. Allowed: 4, 8 (AppSpacing.sm).');
    } finally {
      await project.dispose();
    }
  });
}
