# Changelog

All notable changes to this project are documented here. This project follows [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-10-27

### Added

- Enable Dependabot alerts and security updates on every non-archived repository of one or more users or organisations.
- `--dry-run`, `--alerts-only`, `--skip-forks`, `--limit`, `--quiet`, `--version`.
- Defaults to the authenticated user when no owner is given.
- Shows GitHub's error message for each failed repository.
- Runs from GitHub with `npx github:ym-scripts/enable-dependabot` or `curl | bash`.
