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

  group('imports kind', () {
    test('deny by uri glob with from / except and replace_with', () async {
      final v = await lint(
        rule('features_no_material', '''
    imports:
      from: [lib/features/**]
      deny: ["package:flutter/material.dart"]
      replace_with: package:test_app/ui.dart
    message: "{{uri}} -> {{use_instead}}"
'''),
        files,
      );
      expect(
        v.single.message,
        'package:flutter/material.dart -> package:test_app/ui.dart',
      );
      expect(v.single.useInstead, 'package:test_app/ui.dart');
    });

    test('deny by package glob and except', () async {
      final v = await lint(
        rule('http_only_in_network', '''
    imports: { deny: ["package:http/**"], except: [lib/network/**] }
    message: "{{file}}"
'''),
        files,
      );
      expect(v.map((x) => x.message), [
        'lib/data/repo.dart',
        'lib/features/home.dart',
      ]);
    });

    test('deny relative and project path globs', () async {
      final rel = await lint(
        rule('r', '''
    imports: { deny: [relative] }
    message: "{{uri}}"
'''),
        files,
      );
      expect(rel.single.message, '../data/repo.dart');
      final path = await lint(
        rule('r', '''
    imports: { deny: ["lib/data/**"] }
    message: "{{resolved_path}} ({{denied}})"
'''),
        files,
      );
      expect(path.single.message, 'lib/data/repo.dart (lib/data/**)');
    });

    test('deny is required', () {
      final errors = configErrors(
        rule('r', '    imports: { from: [lib/**] }\n    message: x\n'),
      );
      expect(
        errors.map((e) => e.message),
        contains('missing required key "deny"'),
      );
    });
  });

  group('naming kind', () {
    test('class target with where and pattern', () async {
      final v = await lint(
        rule('screens_named_screen', '''
    files: [lib/screens/**]
    naming: { target: class, where: { extends: StatelessWidget }, pattern: "*Screen" }
    message: "{{name}} must end with Screen"
'''),
        files,
      );
      expect(v.single.message, 'HomeView must end with Screen');
    });

    test('style: snake_case on files', () async {
      final v = await lint(
        rule('r', '''
    naming: { target: file, style: snake_case }
    message: "{{name}}"
'''),
        {'lib/HomeScreen.dart': '', 'lib/home_screen.dart': ''},
      );
      expect(v.single.message, 'HomeScreen');
    });

    test('validation: target and style values', () {
      final errors = configErrors(
        rule('r', '''
    naming: { target: widget, style: kebab }
    message: x
'''),
      );
      expect(
        errors.map((e) => e.message),
        containsAll(['invalid target "widget"', 'invalid style "kebab"']),
      );
    });
  });
}
