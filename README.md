# enable-dependabot

[![CI](https://github.com/ym-scripts/enable-dependabot/actions/workflows/ci.yml/badge.svg)](https://github.com/ym-scripts/enable-dependabot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Turn on Dependabot alerts and security updates for every repository you own, in one command.** It works across your personal account and any number of organisations, and skips archived repos.

```bash
npx github:ym-scripts/enable-dependabot --dry-run
```

## Requirements

- [GitHub CLI](https://cli.github.com) (`gh`), signed in with `gh auth login` and the `repo` scope (add `read:org` for organisations)
- Admin rights on each repository you want to change
- bash 3.2+ (the bash that ships with macOS is fine)

## Usage

```bash
# Run from GitHub with npx
npx github:ym-scripts/enable-dependabot --dry-run my-user my-org
npx github:ym-scripts/enable-dependabot my-user my-org

# Or without Node
curl -fsSL https://raw.githubusercontent.com/ym-scripts/enable-dependabot/main/enable-dependabot.sh | bash -s -- --dry-run my-user
```

With no `OWNER`, it uses the account `gh` is signed in as.

Always do a `--dry-run` first to see which repositories would change.

### Options

| Option            | Description                                                                                |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `-n`, `--dry-run` | List what would change. Changes nothing.                                                   |
| `--alerts-only`   | Enable alerts but not automated security-update PRs.                                       |
| `--skip-forks`    | Leave forked repositories alone.                                                           |
| `--limit N`       | Max repositories per owner (default `1000`). You'll get a warning if the limit is reached. |
| `-q`, `--quiet`   | Only print failures and the summary.                                                       |
| `-v`, `--version` | Print the version.                                                                         |
| `-h`, `--help`    | Show help.                                                                                 |

### Output

```text
== my-org ==
OK    my-org/api
WARN  my-org/legacy  alerts on, security updates failed: HTTP 403: Must have admin rights to Repository.
FAIL  my-org/fork  alerts: HTTP 404: Not Found

Done. Succeeded: 1  Failed: 2
```

### Exit codes

| Code | Meaning                                                 |
| ---- | ------------------------------------------------------- |
| `0`  | Every repository succeeded (or the dry run listed them) |
| `1`  | At least one repository or owner failed                 |
| `2`  | Usage error, `gh` missing, or `gh` not signed in        |

## What it changes

For each non-archived repository it calls two GitHub API endpoints. Both are idempotent, so running the script again is safe.

| Setting                     | API                                                                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Dependabot alerts           | [`PUT /repos/{owner}/{repo}/vulnerability-alerts`](https://docs.github.com/rest/repos/repos#enable-vulnerability-alerts)         |
| Dependabot security updates | [`PUT /repos/{owner}/{repo}/automated-security-fixes`](https://docs.github.com/rest/repos/repos#enable-automated-security-fixes) |

It doesn't add a `dependabot.yml` or turn on version updates. To have new organisation repositories get these settings automatically, enable them under **Organisation settings → Code security**.

## Troubleshooting

- **`HTTP 403`**: you aren't an admin on that repo, or your token lacks the `repo` scope. Run `gh auth refresh -s repo,read:org`.
- **Security updates fail but alerts succeed**: the repo may have Dependabot disabled by an organisation policy, or it may be an empty repo.
- **An organisation shows no repos**: run `gh auth refresh -s read:org`, and check that SSO is authorised for your token.

## Development

```bash
bash test/run.sh     # runs the script against a fake gh, no network needed
```

## License

[MIT](LICENSE) © Aghogho Meyoron
