import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  const files = {
    'lib/features/home.dart': '''
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import '../data/repo.dart';
''',
    'lib/data/repo.dart': "import 'package:http/http.dart';\nclass Repo {}\n",
    'lib/network/client.dart': "import 'package:http/http.dart';\n",
    'lib/screens/home_view.dart': '''
import 'package:flutter/material.dart';
class HomeView extends StatelessWidget {
  const HomeView({super.key});
  @override
  Widget build(BuildContext context) => const Text('x');
}
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Text('x');
}
''',
  };

  group('deny_imports', () {
    test('uri glob with include and replace_with', () async {
      final v = await lint(
        rule('features_no_material', '''
    deny_imports: ["package:flutter/material.dart"]
    replace_with: package:test_app/ui.dart
    files: [lib/features/**]
    message: "{{uri}} -> {{use_instead}}"
'''),
        files,
      );
      expect(
        v.single.message,
        'package:flutter/material.dart -> package:test_app/ui.dart',
      );
    });

    test('package glob with exclude', () async {
      final v = await lint(
        rule('http_only_in_network', '''
    deny_imports: ["package:http/**"]
    exclude: [lib/network/**]
    message: "{{file}}"
'''),
        files,
      );
      expect(v.map((x) => x.message), [
        'lib/data/repo.dart',
        'lib/features/home.dart',
      ]);
    });

    test('relative and project path globs', () async {
      final rel = await lint(
        rule('r', '    deny_imports: [relative]\n    message: "{{uri}}"\n'),
        files,
      );
      expect(rel.single.message, '../data/repo.dart');
      final path = await lint(
        rule(
          'r',
          '    deny_imports: ["lib/data/**"]\n    message: "{{resolved_path}} ({{denied}})"\n',
        ),
        files,
      );
      expect(path.single.message, 'lib/data/repo.dart (lib/data/**)');
    });

    test('an empty list is an error', () {
      final errors = configErrors(rule('r', '    deny_imports: []\n'));
      expect(
        errors.map((e) => e.message),
        contains('deny_imports needs at least one entry'),
      );
    });
  });

  group('naming with name patterns and styles', () {
    test('class not matching a pattern', () async {
      final v = await lint(
        rule('screens_named_screen', '''
    class: { extends: StatelessWidget }
    name: { not: "*Screen" }
    files: [lib/screens/**]
    message: "{{name}} must end with Screen"
'''),
        files,
      );
      expect(v.single.message, 'HomeView must end with Screen');
    });

    test('not_style on files', () async {
      final v = await lint(
        rule(
          'r',
          '    file: { name: { not_style: snake_case } }\n    message: "{{name}}"\n',
        ),
        {'lib/HomeScreen.dart': '', 'lib/home_screen.dart': ''},
      );
      expect(v.single.message, 'HomeScreen');
    });

    test('unknown style is an error', () {
      final errors = configErrors(
        rule('r', '    file: { name: { style: kebab } }\n'),
      );
      expect(errors.single.message, 'unknown style "kebab"');
    });
  });
}
