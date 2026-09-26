---
title: Agent workflow
description: How a coding agent discovers, obeys, writes and verifies rules with agent_lints.
---

# Agent workflow

agent_lints is built so that a coding agent (Claude Code, Cursor, Copilot,
Codex, ...) can close the loop on its own: run, read, fix, and when asked,
write a new rule and prove it. This page is written to be pasted into agent
instructions.

## The check loop

1. After editing Dart files, run:

   ```
   dart run agent_lints --changed
   ```

   (`--changed` = files touched since the last commit; drop it to check
   everything.) The output is piped, so the `agent` format is used.

2. Read each block. `why` explains the rule, `hint` is a replacement
   snippet, `docs` points to more. Edit the code accordingly.

3. Re-run until the exit code is 0. Do not paste the `ignore` comment unless
   the violation is genuinely wrong for this case, and then keep the
   `-- reason`.

4. If a rule seems wrong or too strict, do not weaken it silently: say so, and
   point at `dart run agent_lints explain <rule>`.

## Writing a rule

When asked to add a project convention:

1. `dart run agent_lints explain --kinds` prints the rule language (node
   kinds, argument constraints, context keys, placeholders), generated from
   the installed version.
2. Add a rule to `agent_lints.yaml`, or to the file under `agent_lints/` that
   holds related rules when the project uses `include:`. A rule is one node key (`use` for "never use X",
   `deny_imports` for layering, `class` / `function` / `file` with a `name`
   pattern for naming, `new` / `call` when arguments or context matter) plus
   `message` with what to do instead, and `examples` with at least one `bad`
   and one `good` snippet.
3. `dart run agent_lints validate` reports every YAML problem with position
   and hint. Fix them all.
4. `dart run agent_lints test` proves the rule against its examples.
5. `dart run agent_lints --rule <id>` shows what it finds in the real code.
   Report the count; do not mass-edit the code unless asked.

Template:

```yaml
  <rule_id>:
    severity: warning
    description: <one line>
    files: [lib/**]
    use: <symbol>                 # or new / call / class / deny_imports / file ...
    from: <package>
    use_instead: <what to write instead>
    message: "<what was found>. <why>. Use {{use_instead}}."
    examples:
      bad: ["<complete snippet with imports>"]
      good: ["<complete snippet>"]
```

## Block for AGENTS.md / CLAUDE.md

`dart run agent_lints init --agents-md` appends this (idempotently):

```markdown
## Project lint rules (agent_lints)

Project conventions are enforced by `agent_lints.yaml`. Before finishing a
change run `dart run agent_lints` and fix every reported block; each one names
the rule, why it fired, and what to write instead. To add a convention, add a
rule to `agent_lints.yaml` (`dart run agent_lints explain --kinds` prints the
rule language), then run `dart run agent_lints validate` and
`dart run agent_lints test`. Suppress a hit only with a reason:
`// ignore: agent_lints/<rule> -- why`.
```

`--claude-skill` writes the same guidance as a Claude Code skill in
`.claude/skills/agent-lints/SKILL.md`, so it is loaded when relevant instead of
occupying the system prompt.

## Why the output looks like this

The `agent` format is optimized for language models: stable keys, one fact per
line, the replacement spelled out, nothing to parse. Errors in the YAML are
reported the same way (all at once, with the path and a did-you-mean), so an
agent that writes a bad rule gets told exactly what to fix. `explain --kinds`
is generated from the matcher code, so the documentation an agent reads can
never drift from what the engine accepts.

## Machine-readable alternatives

- `--format json` for tooling, with ranges and offsets.
- `--format sarif` for GitHub code scanning and IDE importers.
- Exit codes: 0 clean, 1 violations, 2 invalid config, 3 analysis failed.
