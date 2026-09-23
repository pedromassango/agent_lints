---
title: Suppressing violations
description: ignore comments, reasons, and auditing what was silenced.
---

# Suppressing violations

The comment syntax is the analyzer's own, so one comment works for the CLI, for
`dart analyze` and for the IDE.

```dart
// ignore: agent_lints/no_print -- one-off migration script
print(report);

print(report); // ignore: agent_lints/no_print -- trailing form covers this line

// ignore: agent_lints/no_print, agent_lints/no_relative_imports -- several rules
```

```dart
// ignore_for_file: agent_lints/no_print -- this IS the logger
```

Rules:

- A comment on its own line covers the **next** line. A trailing comment covers
  **its own** line. Multi-line nodes are reported at their first line, so the
  comment goes right above that line.
- `agent_lints/all` silences every rule.
- The `agent_lints/` prefix is what the analyzer requires for plugin
  diagnostics. The CLI also accepts the bare rule id (`// ignore: no_print`)
  but the IDE will not, so prefer the prefixed form. Every violation prints
  the exact comment to paste under `ignore`.
- `-- reason` is free text after two dashes. With `require_ignore_reason: true`
  in the config, a comment without a reason is reported as
  `ignore_without_reason` (warning).
- A comment that suppresses nothing is reported as `unused_ignore` (info) by
  the CLI so stale ignores get removed.

## Auditing

```
dart run agent_lints --show-suppressed
```

lists what the comments silenced:

```
suppressed by // ignore comments:
  no_gesture_detector_for_taps  lib/features/cart/cart_tile.dart:8  GestureDetector(onTap: ...)
```

The JSON format adds a `suppressed` array with the full violation objects, and
the summary always carries the count.

## Ignoring files and folders

Prefer the config over comments for whole areas:

```yaml
exclude: [lib/generated/**]          # top level: no rule runs there
rules:
  no_print:
    exclude: [lib/core/log.dart]     # one rule skips one file
```
