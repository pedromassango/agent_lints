---
title: Releasing
description: How a new agent_lints version reaches pub.dev.
---

# Releasing

A release is a GitHub Release. Creating one publishes the package to pub.dev
through the `publish` workflow, which uses pub.dev's automated publishing
(GitHub OIDC, no stored secrets).

## Steps

1. Bump `version:` in `pubspec.yaml` and `packageVersion` in
   `lib/src/cli/version.dart`, add an entry to `CHANGELOG.md`, commit and
   push to `main`. CI must be green.
2. On GitHub, open **Releases**, click **Create a new release**, and create a
   new tag named `v<version>` (for example `v0.1.3`) on `main`. Use the
   changelog entry as the release notes and publish the release.
3. The `publish` workflow runs `dart pub publish` under the `pub.dev`
   environment. pub.dev accepts the upload only when the tag matches
   `v{{version}}` from the pubspec and the workflow ran in
   `pedromassango/agent_lints`.

The new version is listed on pub.dev within a few minutes; the package page
shows the README of the latest version.

## Manual trigger

The same workflow has a **Run workflow** button under **Actions, publish**.
Use it to retry a failed publish or to publish a tag that was pushed without
a GitHub Release. In the **Use workflow from** dropdown pick the tag
(`v0.1.3`), not `main`: pub.dev only accepts uploads whose workflow ran on a
ref matching `v{{version}}`.

## One-time setup

- pub.dev: package **Admin** tab, **Automated publishing**, enable
  **Publishing from GitHub Actions** with repository
  `pedromassango/agent_lints`, tag pattern `v{{version}}`, and require the
  GitHub Actions environment `pub.dev`.
- GitHub: **Settings, Environments**, create `pub.dev` (optionally with a
  required reviewer, which turns every release into an approval step).

## Manual fallback

`dart pub publish` from a clean checkout still works with a local
authorization (`dart pub login`).
