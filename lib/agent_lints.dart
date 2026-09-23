/// Agent-first custom lint for Dart and Flutter.
///
/// Rules are defined in `agent_lints.yaml` and evaluated over the resolved
/// analyzer AST. See the README for the rule language.
library;

export 'src/cli/exit_codes.dart';
export 'src/cli/project_files.dart';
export 'src/cli/version.dart';
export 'src/config/config.dart';
export 'src/config/errors.dart';
export 'src/config/loader.dart';
export 'src/engine/engine.dart';
export 'src/match/compiled_rule.dart';
export 'src/report/formatters/agent_formatter.dart';
export 'src/report/formatters/formatter.dart';
export 'src/report/formatters/human_formatter.dart';
export 'src/report/formatters/json_formatter.dart';
export 'src/report/run_result.dart';
export 'src/report/violation.dart';
