# Contributing

Thanks for your interest in improving AppFlowy Editor. This page covers what you need before opening a PR.

## Development setup

The repo pins **Flutter 3.44.0** via [FVM](https://fvm.app/) ([`.fvm/version`](.fvm/version)).

```bash
fvm install                # one-time, picks up .fvm/version
fvm flutter pub get
```

If you don't use FVM, install Flutter 3.44.0 manually and confirm `flutter --version` reports it.

## Running the gates locally

These mirror what CI enforces ([`.github/workflows/test.yml`](.github/workflows/test.yml)). All four exit non-zero on failure.

```bash
fvm flutter analyze .
fvm dart format --output=none --set-exit-if-changed lib test example/lib example/test
fvm flutter test --coverage
fvm flutter test test/leak/                    # lifecycle / dispose gate
```

The leak gate uses [`leak_tracker_flutter_testing`](https://pub.dev/packages/leak_tracker_flutter_testing). It is scoped — `test/leak/flutter_test_config.dart` calls `LeakTesting.enable()` only for that directory, so the rest of the suite is unaffected. To add a new leak scenario, drop a `testWidgets` into `test/leak/` with:

```dart
experimentalLeakTesting: LeakTesting.settings
    .withTrackedAll()
    .withTracked(experimentalAllNotGCed: true),
```

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), imperative subject ≤72 chars:

```
fix(scope): what changed in one line

Optional body — what it does, why it was needed, any
[ROADMAP.md](ROADMAP.md) reference (e.g. ROADMAP H1.x).
```

Common scopes in this repo: `selection`, `lifecycle`, `markdown`, `toolbar`, `ci`, `docs`, `test`, `perf`, `chore`.

## Pull requests

- One logical change per PR — easier to review, easier to revert.
- Fill out [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md); the test-plan section is not optional.
- If your change touches anything tracked in [ROADMAP.md](ROADMAP.md), reference the ID (`H1.4`, `H3.2`, …) so future readers can trace it.
- Performance-relevant changes should compare before/after numbers — for selection work, use `test/performance/selection_notification_cascade_test.dart` as a baseline.

## Reporting issues

- Bugs: [`.github/ISSUE_TEMPLATE/bug_report.yaml`](.github/ISSUE_TEMPLATE/bug_report.yaml)
- Features: [`.github/ISSUE_TEMPLATE/feature_request.yaml`](.github/ISSUE_TEMPLATE/feature_request.yaml)
