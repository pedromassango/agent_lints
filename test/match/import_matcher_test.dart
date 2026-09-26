import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('import', () {
    const files = {
      'lib/features/home.dart': '''
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http show get;
import '../data/repo.dart';
export 'package:flutter/widgets.dart';
''',
      'lib/data/repo.dart': 'class Repo {}\n',
      'lib/network/client.dart': "import 'package:http/http.dart';\n",
    };

    test('matches by uri glob with file scoping', () async {
      final v = await lint(
        rule('features_no_material', '''
    files: [lib/features/**]
    import: "package:flutter/material.dart"
    message: "{{uri}} from {{package}}"
'''),
        files,
      );
      expect(v.single.message, 'package:flutter/material.dart from flutter');
      expect(v.single.relativePath, 'lib/features/home.dart');
    });

    test('matches by resolved package, prefix and show', () async {
      final v = await lint(
        rule('http_only_in_network', '''
    exclude: [lib/network/**]
    import: { package: http, prefix: http, show: get }
    message: "{{uri}}"
'''),
        files,
      );
      expect(v.single.relativePath, 'lib/features/home.dart');
    });

    test('relative imports resolve to project paths', () async {
      final v = await lint(
        rule('no_relative_imports', '''
    import: { relative: true }
    message: "{{uri}} -> {{resolved_path}} ({{package}}) {{package_path}}"
'''),
        files,
      );
      expect(
        v.single.message,
        '../data/repo.dart -> lib/data/repo.dart (test_app) package:test_app/data/repo.dart',
      );
    });

    test('kind: export and kind: any', () async {
      final exports = await lint(
        rule(
          'r',
          '    import: { kind: export, package: flutter }\n    message: "{{uri}}"\n',
        ),
        files,
      );
      expect(exports.single.message, 'package:flutter/widgets.dart');
      final any = await lint(
        rule(
          'r',
          '    import: { kind: any, package: flutter }\n    message: x\n',
        ),
        files,
      );
      expect(any, hasLength(2));
    });
  });
}
