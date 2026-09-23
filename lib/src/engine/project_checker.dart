import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;

import '../config/config.dart';
import '../config/errors.dart';
import '../report/run_result.dart';
import '../report/violation.dart';
import 'engine.dart';

/// Resolves every selected file in the project and runs the [Engine] on it.
/// Shared by the CLI and by tests.
class ProjectChecker {
  ProjectChecker(this.config);

  final AgentLintsConfig config;

  Future<RunResult> run({
    Set<String> onlyFiles = const {},
    Severity? failOn,
    List<ConfigError> warnings = const [],
    bool showSuppressed = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final engine = Engine(config);
    final violations = <Violation>[];
    var filesChecked = 0;
    final collection = AnalysisContextCollection(
      includedPaths: [config.rootPath],
    );
    final only = onlyFiles.map(p.normalize).toSet();
    for (final context in collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        if (only.isNotEmpty && !only.contains(p.normalize(path))) continue;
        if (!config.includesFile(path)) continue;
        final result = await context.currentSession.getResolvedUnit(path);
        if (result is! ResolvedUnitResult) continue;
        filesChecked++;
        violations.addAll(engine.analyzeUnit(result));
      }
    }
    violations.sort((a, b) {
      final c = a.relativePath.compareTo(b.relativePath);
      return c != 0 ? c : a.offset.compareTo(b.offset);
    });
    return RunResult(
      violations: violations,
      filesChecked: filesChecked,
      duration: stopwatch.elapsed,
      failOn: failOn ?? config.failOn,
      configPath: config.configPath,
      configWarnings: warnings,
      suppressed: engine.suppressed,
      showSuppressed: showSuppressed,
    );
  }
}
